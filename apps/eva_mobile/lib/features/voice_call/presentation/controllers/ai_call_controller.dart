import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/call_config.dart';
import '../../data/datasources/voice_call_ws_client.dart';
import '../../data/services/ai_audio_playback_service.dart';
import '../../data/services/single_audio_capture_service.dart';
import '../../data/services/stateless_synthesis_service.dart';
import '../../domain/entities/call_state.dart';
import '../../../memory/domain/repositories/memory_repository.dart';
import '../../../diary/data/datasources/local_diary_datasource.dart';
import 'ai_call_state.dart';

class AiCallController extends StateNotifier<AiCallViewState> {
  final SingleAudioCaptureService _audioCaptureService;
  final AiAudioPlaybackService _audioPlaybackService;
  final VoiceCallWsClient _wsClient;
  final MemoryRepository? _memoryRepository;
  final LocalDiaryDataSource? _diaryDataSource;
  final StatelessSynthesisService? _synthesisService;
  final VoidCallback? _onArtifactsCommitted;

  AiCallController({
    required SingleAudioCaptureService audioCaptureService,
    required AiAudioPlaybackService audioPlaybackService,
    required VoiceCallWsClient wsClient,
    MemoryRepository? memoryRepository,
    LocalDiaryDataSource? diaryDataSource,
    StatelessSynthesisService? synthesisService,
    VoidCallback? onArtifactsCommitted,
  })  : _audioCaptureService = audioCaptureService,
        _audioPlaybackService = audioPlaybackService,
        _wsClient = wsClient,
        _memoryRepository = memoryRepository,
        _diaryDataSource = diaryDataSource,
        _synthesisService = synthesisService,
        _onArtifactsCommitted = onArtifactsCommitted,
        super(const AiCallViewState());

  StreamSubscription? _audioChunkSubscription;
  StreamSubscription? _soundLevelSubscription;
  StreamSubscription? _aiAudioSoundSubscription;
  StreamSubscription? _playbackSubscription;
  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _wsAudioSubscription;
  StreamSubscription? _errorSubscription;
  Timer? _durationTimer;
  Timer? _thinkingWatchdogTimer;
  Timer? _finalizeWatchdogTimer;
  bool _isDisposed = false;

  Future<void> startCall({String? customCallId, String? voiceMode}) async {
    final callId = customCallId ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('🚀 [AI CALL CONTROLLER] Starting call: $callId');

    // Load active voice character mode from SharedPreferences if not specified
    String effectiveVoiceMode = voiceMode ?? 'mode_2';
    if (voiceMode == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        effectiveVoiceMode = prefs.getString('settings_voice_mode') ?? 'mode_2';
      } catch (_) {}
    }

    state = state.copyWith(
      callId: callId,
      voiceMode: effectiveVoiceMode,
      callState: CallState.idle,
      userTurnId: 1,
      assistantTurnId: 0,
      activeSttSessionId: 0,
      currentTranscript: '',
      aiTranscript: '',
      callDurationSeconds: 0,
      clearError: true,
      clearCrisis: true,
    );

    _initSubscriptions();

    _finalizeWatchdogTimer?.cancel();

    // 1. Initialize pure PCM 16kHz audio capture service
    await _audioCaptureService.initialize();

    // 2. Connect WebSocket
    await _wsClient.connect(callId);
    _wsClient.sendStartCall(voiceMode: effectiveVoiceMode);

    // 3. Start Duration Timer
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isDisposed && state.callState != CallState.ended) {
        state = state.copyWith(callDurationSeconds: state.callDurationSeconds + 1);
      }
    });

    // 4. Initial transition to LISTENING
    await enterListening();
  }

  void _initSubscriptions() {
    _cancelSubscriptions();

    // Binary PCM 16kHz 16-bit mono stream -> Backend WebSocket (listening & unmuted only)
    _audioChunkSubscription = _audioCaptureService.audioStream.listen((chunk) {
      if (state.callState == CallState.listening && !state.isMuted) {
        _wsClient.sendAudioChunk(chunk);
      }
    });

    // Mic RMS Sound Level for live voice visualizer
    _soundLevelSubscription = _audioCaptureService.soundLevelStream.listen((level) {
      if (!_isDisposed && mounted && state.callState == CallState.listening && !state.isMuted) {
        state = state.copyWith(soundLevel: level);
      }
    });

    // Native capture error stream
    _errorSubscription = _audioCaptureService.errorStream.listen((err) {
      debugPrint('⚠️ [AUDIO CAPTURE ERROR]: $err');
      if (!_isDisposed && mounted && err == 'microphone_permission_denied') {
        state = state.copyWith(
          errorMessage: 'Izin mikrofon diperlukan untuk panggilan suara.',
        );
      }
    });

    // Playback Completed (Queue completely empty)
    _playbackSubscription = _audioPlaybackService.onPlaybackCompleted.listen((turnId) {
      handlePlaybackFinished(turnId);
    });

    // AI Audio Playback Sound Level (real-time envelope intonation)
    _aiAudioSoundSubscription = _audioPlaybackService.soundLevelStream.listen((level) {
      if (!_isDisposed && mounted && state.callState == CallState.aiSpeaking) {
        state = state.copyWith(soundLevel: level);
      }
    });

    // WebSocket Incoming Audio Chunks
    _wsAudioSubscription = _wsClient.audioStream.listen((audioBytes) {
      if (state.callState != CallState.aiSpeaking) {
        enterAiSpeaking(state.assistantTurnId);
      }
      _audioPlaybackService.enqueueChunk(
        bytes: audioBytes,
        assistantTurnId: state.assistantTurnId,
        sequence: 0,
      );
    });

    // WebSocket Incoming Events
    _wsEventSubscription = _wsClient.eventStream.listen((event) {
      handleSocketEvent(event);
    });
  }

  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == null) return;

    debugPrint('📩 [AI CALL CONTROLLER <- WS] $type');

    if (type == 'call_connected') {
      final contextSupported = event['context_supported'] as bool? ?? false;
      if (contextSupported && _memoryRepository != null) {
        _sendSelectiveLtmContext();
      }
    } else if (type == 'context_ack_v1') {
      debugPrint('📥 [LTM CONTEXT ACK] Accepted: ${event['accepted_count']}, Rejected: ${event['rejected_count']}');
    } else if (type == 'emotion_result') {
      final status = (event['status'] as String?)?.toLowerCase();
      if (status == 'unavailable' || status == 'stale') {
        debugPrint('🎙️ [EMOTION RESULT WS] Status=$status (no fabricated score applied)');
        return;
      }
      final primaryEmotion = event['primary_emotion'] as String?;
      final confidence = (event['confidence'] as num?)?.toDouble();
      if (primaryEmotion == null || confidence == null) {
        return;
      }
      final breakdown = (event['emotions_breakdown'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];
      debugPrint('🎙️ [EMOTION RESULT WS] Primary: $primaryEmotion ($confidence)');
      state = state.copyWith(
        detectedEmotion: primaryEmotion,
        detectedEmotionConfidence: confidence,
        activeEmotionsBreakdown: breakdown,
      );
    } else if (type == 'session_artifacts_v1') {
      final requestId = event['request_id'] as String? ?? 'fin_${DateTime.now().millisecondsSinceEpoch}';
      final sessionSummary = event['session_summary'] as String? ?? '';
      final journalDelta = event['journal_delta'] as Map<String, dynamic>? ?? {};
      final candidates = (event['memory_candidates'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];
      final dassAssessment = event['dass_assessment'] as Map<String, dynamic>?;

      _handleSessionArtifactsReceived(
        requestId: requestId,
        sessionSummary: sessionSummary,
        journalDelta: journalDelta,
        candidates: candidates,
        dassAssessment: dassAssessment,
      );
    } else if (type == 'session_finalized_v1') {
      _finalizeWatchdogTimer?.cancel();
      state = state.copyWith(isFinalizing: false, callState: CallState.ended);
      _wsClient.disconnect();
    } else if (type == 'call_started') {
      final confirmedMode = event['voice_mode'] as String?;
      if (confirmedMode != null && confirmedMode.isNotEmpty) {
        state = state.copyWith(voiceMode: confirmedMode);
      }
    } else if (type == 'stt.partial') {
      if (state.callState == CallState.listening && !state.isMuted) {
        final text = (event['text'] as String? ?? '').trim();
        final eventTurnId = (event['user_turn_id'] as num?)?.toInt();
        if (eventTurnId == null || eventTurnId == state.userTurnId) {
          state = state.copyWith(
            latestPartial: text,
            isUserSpeaking: text.isNotEmpty || state.currentTranscript.isNotEmpty,
          );
        }
      }
    } else if (type == 'stt.final_segment') {
      if (state.callState == CallState.listening) {
        final text = (event['text'] as String? ?? '').trim();
        final eventTurnId = (event['user_turn_id'] as num?)?.toInt();
        if (text.isNotEmpty && (eventTurnId == null || eventTurnId == state.userTurnId)) {
          final merged = state.currentTranscript.isEmpty
              ? text
              : (state.currentTranscript.endsWith(text)
                  ? state.currentTranscript
                  : '${state.currentTranscript} $text');
          state = state.copyWith(
            currentTranscript: merged,
            latestPartial: '',
            isUserSpeaking: true,
          );
        }
      }
    } else if (type == 'stt.status') {
      final status = (event['status'] as String? ?? '').trim();
      final sttSessionId = (event['stt_session_id'] as num?)?.toInt();
      if (sttSessionId != null && sttSessionId > 0) {
        state = state.copyWith(activeSttSessionId: sttSessionId);
      }
      if (status == 'incognito_blocked') {
        state = state.copyWith(
          errorMessage: 'Mode incognito menonaktifkan transkripsi suara cloud.',
        );
      } else if (status.startsWith('error_')) {
        debugPrint('⚠️ [BACKEND STT STATUS]: $status');
      }
    } else if (type == 'turn.keep_open') {
      // Recover to listening if waiting in thinking (e.g. from empty force commit)
      if (state.callState == CallState.thinking) {
        enterListening();
      }
    } else if (type == 'turn.committed') {
      final finalTranscript = event['final_transcript'] as String? ?? '';
      final updatedAcc = state.accumulatedTranscript.isEmpty
          ? 'User: $finalTranscript'
          : '${state.accumulatedTranscript}\nUser: $finalTranscript';
      state = state.copyWith(
        currentTranscript: finalTranscript,
        accumulatedTranscript: updatedAcc,
      );
      if (finalTranscript.isNotEmpty) {
        _synthesisService?.recordTurn(
          sessionId: state.callId,
          turnId: state.userTurnId,
          role: 'user',
          transcript: finalTranscript,
        );
      }
      enterThinking();
    } else if (type == 'ai.thinking' || type == 'ai_thinking') {
      final turnId = (event['assistant_turn_id'] as num?)?.toInt();
      if (turnId != null) {
        state = state.copyWith(assistantTurnId: turnId);
      }
      enterThinking();
    } else if (type == 'ai.transcript_chunk' || type == 'ai_transcript_chunk') {
      final text = event['text'] as String? ?? '';
      // Set full transcript if incoming chunk contains complete response, or append if chunked
      state = state.copyWith(
        aiTranscript: text.length >= state.aiTranscript.length ? text : (state.aiTranscript + text),
      );
    } else if (type == 'ai.audio_chunk' || type == 'ai_audio_chunk') {
      final turnId = (event['assistant_turn_id'] as num?)?.toInt() ?? state.assistantTurnId;
      final seq = (event['sequence'] as num?)?.toInt() ?? 0;
      final b64 = event['audio_base64'] as String?;
      final envelope = (event['envelope'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? <double>[];

      if (b64 != null && b64.isNotEmpty) {
        try {
          final audioBytes = base64Decode(b64);
          if (state.callState != CallState.aiSpeaking) {
            enterAiSpeaking(turnId);
          }
          _audioPlaybackService.enqueueChunk(
            bytes: audioBytes,
            assistantTurnId: turnId,
            sequence: seq,
            envelope: envelope,
          );
        } catch (e) {
          debugPrint('⚠️ [AI AUDIO DECODE ERROR]: $e');
        }
      }
    } else if (type == 'ai.speech_finished' || type == 'ai_speech_finished') {
      final turnId = (event['assistant_turn_id'] as num?)?.toInt() ?? state.assistantTurnId;
      if (state.aiTranscript.isNotEmpty) {
        _synthesisService?.recordTurn(
          sessionId: state.callId,
          turnId: turnId,
          role: 'assistant',
          transcript: state.aiTranscript,
        );
      }
      if (state.callState == CallState.thinking) {
        // Backend finished generation but no audio was enqueued/played (TTS fallback/text-only)
        _thinkingWatchdogTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 1500), () async {
          if (!_isDisposed && state.callState == CallState.thinking) {
            state = state.copyWith(userTurnId: state.userTurnId + 1);
            await enterListening();
          }
        });
      } else {
        _audioPlaybackService.markStreamFinished(turnId);
      }
    } else if (type == 'assistant.interrupted_ack' || type == 'interrupted_ack') {
      debugPrint('⚡ [AI CALL CONTROLLER] Interrupted ACK confirmed by server');
    } else if (type == 'call.sync_state') {
      final activeUserTurn = (event['active_user_turn_id'] as num?)?.toInt();
      final activeAssistantTurn = (event['active_assistant_turn_id'] as num?)?.toInt();
      final serverState = event['state'] as String?;
      if (activeUserTurn != null) {
        state = state.copyWith(userTurnId: activeUserTurn);
      }
      if (activeAssistantTurn != null) {
        state = state.copyWith(assistantTurnId: activeAssistantTurn);
      }
      if (serverState == 'listening' && state.callState == CallState.thinking) {
        enterListening();
      }
    } else if (type == 'ai.crisis_escalation' || type == 'crisis_alert' || type == 'emergency_triggered') {
      final hotline = event['hotline'] as String? ?? 'Hotline Dinkes (WhatsApp 0813-8007-3120) / Kemenkes 119 ext 8';
      final hotlineUrl = event['hotline_url'] as String? ??
          'https://api.whatsapp.com/send/?phone=6281380073120&text=halo%20kak%2C%20saya%20ingin%20bercerita%20mengenai...&type=phone_number&app_absent=0';
      state = state.copyWith(
        crisisHotline: hotline,
        crisisHotlineUrl: hotlineUrl,
        isCrisisSession: true,
      );
    } else if (type == 'voice_session_summary') {
      final transcriptList = event['transcript'] as List<dynamic>?;
      if (transcriptList != null && transcriptList.isNotEmpty) {
        final buffer = StringBuffer();
        for (final item in transcriptList) {
          if (item is Map && item['content'] != null) {
            final role = (item['role'] == 'user') ? 'User' : 'EVA';
            buffer.writeln('$role: ${item['content']}');
          }
        }
        final summaryText = buffer.toString().trim();
        if (summaryText.isNotEmpty) {
          state = state.copyWith(
            accumulatedTranscript: summaryText,
          );
        }
      }
    } else if (type == 'error') {
      state = state.copyWith(errorMessage: event['message'] as String? ?? 'Terjadi kesalahan sistem');
      if (state.callState == CallState.thinking || state.callState == CallState.aiSpeaking) {
        enterListening();
      }
    }
  }

  /// Invariant: LISTENING -> PCM capture ON, AI audio OFF
  Future<void> enterListening() async {
    _thinkingWatchdogTimer?.cancel();

    // Guard: Audio must be completely stopped before mic opens
    await _audioPlaybackService.stop();

    final nextSessionId = state.activeSttSessionId + 1;

    final updatedAcc = state.aiTranscript.isNotEmpty
        ? (state.accumulatedTranscript.isEmpty
            ? 'EVA: ${state.aiTranscript}'
            : '${state.accumulatedTranscript}\nEVA: ${state.aiTranscript}')
        : state.accumulatedTranscript;

    state = state.copyWith(
      callState: CallState.listening,
      activeSttSessionId: nextSessionId,
      isUserSpeaking: false,
      currentTranscript: '',
      latestPartial: '',
      aiTranscript: '',
      accumulatedTranscript: updatedAcc,
    );

    if (state.conversationMode == ConversationMode.hybridAuto && !state.isMuted) {
      await _audioCaptureService.startCapture();
    }
  }

  /// Invariant: THINKING -> PCM capture OFF, AI audio OFF
  Future<void> enterThinking() async {
    _thinkingWatchdogTimer?.cancel();
    state = state.copyWith(
      callState: CallState.thinking,
      isUserSpeaking: false,
      soundLevel: 0.05,
    );
    await _audioCaptureService.stopCapture();

    // Watchdog Timer: Guard against stuck thinking if backend stalls or drops connection
    _thinkingWatchdogTimer = Timer(const Duration(seconds: 15), () async {
      if (!_isDisposed && state.callState == CallState.thinking) {
        debugPrint('⚠️ [THINKING WATCHDOG TIMEOUT]: No AI response within 15s. Recovering to listening.');
        state = state.copyWith(
          errorMessage: 'Respons Eva membutuhkan waktu lebih lama. Silakan coba bicara lagi.',
        );
        await enterListening();
      }
    });
  }

  /// Invariant: AI_SPEAKING -> PCM capture OFF, AI audio ON
  Future<void> enterAiSpeaking(int assistantTurnId) async {
    _thinkingWatchdogTimer?.cancel();
    state = state.copyWith(
      callState: CallState.aiSpeaking,
      assistantTurnId: assistantTurnId,
      isUserSpeaking: false,
      soundLevel: 0.05,
    );
    _audioPlaybackService.prepareNewAssistantTurn(assistantTurnId);
    await _audioCaptureService.stopCapture();
  }

  /// Normal Automatic Flow: AI playback finished -> guard delay -> auto LISTENING
  Future<void> handlePlaybackFinished(int finishedTurnId) async {
    if (state.callState != CallState.aiSpeaking) return;

    debugPrint('🔊 [PLAYBACK FINISHED]: Guard delay before auto-listening...');
    _wsClient.sendPlaybackFinished(
      callId: state.callId,
      assistantTurnId: finishedTurnId,
    );

    // Guard delay between AI speaker end and mic start
    await Future.delayed(const Duration(milliseconds: CallConfig.playbackToListeningGuardMs));

    if (!_isDisposed && state.callState == CallState.aiSpeaking) {
      // Ensure userTurnId advances to at least finishedTurnId + 1 without duplicate double increment
      if (state.userTurnId <= finishedTurnId) {
        state = state.copyWith(userTurnId: finishedTurnId + 1);
      }
      await enterListening();
    }
  }

  /// Manual Barge-In: Interrupt ongoing AI response or pending generation
  Future<void> bargeIn() async {
    // Idempotent guard: if already interrupting or listening, ignore duplicate taps
    if (state.callState == CallState.interrupting || state.callState == CallState.listening) {
      debugPrint('⚡ [BARGE-IN IGNORED]: Already in state ${state.callState}');
      return;
    }

    debugPrint('⚡ [MANUAL BARGE-IN TRIGGERED] State: ${state.callState}');

    _thinkingWatchdogTimer?.cancel();
    state = state.copyWith(callState: CallState.interrupting);

    // 1. Instantly stop audio player locally and flush queue
    await _audioPlaybackService.stop();

    // 2. Notify backend to cancel active task
    _wsClient.sendInterrupt(
      callId: state.callId,
      assistantTurnId: state.assistantTurnId,
      reason: 'user_barge_in',
    );

    // 3. Short barge-in guard delay
    await Future.delayed(const Duration(milliseconds: CallConfig.bargeInGuardMs));

    if (!_isDisposed) {
      // 4. Create new user turn and start listening immediately
      state = state.copyWith(userTurnId: state.userTurnId + 1);
      await enterListening();
    }
  }

  /// Manual force-commit button in LISTENING state ("Selesai Bicara")
  Future<void> forceCommit() async {
    if (state.callState != CallState.listening) return;

    debugPrint('👆 [FORCE COMMIT] Turn: ${state.userTurnId}');
    _wsClient.sendForceCommit(
      callId: state.callId,
      userTurnId: state.userTurnId,
    );
    await enterThinking();
  }

  /// Toggle microphone mute
  void toggleMute() {
    final newMute = !state.isMuted;
    state = state.copyWith(isMuted: newMute, soundLevel: newMute ? 0.0 : state.soundLevel);
    _audioCaptureService.setMuted(newMute);
    if (state.callId.isNotEmpty) {
      _wsClient.sendAudioBoundary(
        callId: state.callId,
        reason: newMute ? 'mute' : 'unmute',
      );
    }

    if (newMute) {
      _audioCaptureService.stopCapture();
    } else if (state.callState == CallState.listening &&
        state.conversationMode == ConversationMode.hybridAuto) {
      _audioCaptureService.startCapture();
    }
  }

  /// Toggle speakerphone (Loudspeaker vs Earpiece)
  void toggleSpeaker() {
    final newSpeaker = !state.isSpeakerOn;
    state = state.copyWith(isSpeakerOn: newSpeaker);
    _audioPlaybackService.setSpeakerphoneOn(newSpeaker);
  }

  /// Switch conversation mode (Hybrid Auto vs Push to Talk fallback)
  void setConversationMode(ConversationMode mode) {
    state = state.copyWith(conversationMode: mode);
    if (mode == ConversationMode.pushToTalk && state.callState == CallState.listening) {
      _audioCaptureService.stopCapture();
    } else if (mode == ConversationMode.hybridAuto &&
        state.callState == CallState.listening &&
        !state.isMuted) {
      _audioCaptureService.startCapture();
    }
  }

  /// Push-to-talk press down: start capture
  Future<void> pushToTalkPress() async {
    if (state.conversationMode != ConversationMode.pushToTalk) return;
    if (state.callState == CallState.aiSpeaking || state.callState == CallState.thinking) {
      await bargeIn();
    } else if (state.callState == CallState.listening && !state.isMuted) {
      await _audioCaptureService.startCapture();
    }
  }

  /// Push-to-talk release: stop listening & force commit
  Future<void> pushToTalkRelease() async {
    if (state.conversationMode != ConversationMode.pushToTalk) return;
    await forceCommit();
  }

  Future<void> _sendSelectiveLtmContext() async {
    try {
      final repo = _memoryRepository;
      if (repo == null) return;
      final items = await repo.selectRelevantContext(
        accountKey: 'current_user_local',
        maxItems: 5,
      );
      if (items.isEmpty) return;

      final payloadItems = items.map((e) => {
        'id': e.id,
        'category': e.category.value,
        'text': e.factText,
        'status': e.status.value,
      }).toList();

      _wsClient.sendClientContext(
        clientSessionId: state.callId,
        contextRequestId: 'req_${DateTime.now().millisecondsSinceEpoch}',
        items: payloadItems,
      );
    } catch (e) {
      debugPrint('⚠️ [LTM CONTEXT INJECTION ERROR]: $e');
    }
  }

  Future<void> _commitLocalFallbackArtifacts() async {
    try {
      final diarySource = _diaryDataSource;
      if (diarySource == null) return;

      final parts = <String>[];
      if (state.accumulatedTranscript.isNotEmpty) {
        parts.add(state.accumulatedTranscript);
      }
      if (state.currentTranscript.isNotEmpty && !state.accumulatedTranscript.contains(state.currentTranscript)) {
        parts.add(state.currentTranscript);
      }
      if (state.aiTranscript.isNotEmpty && !state.accumulatedTranscript.contains(state.aiTranscript)) {
        parts.add(state.aiTranscript);
      }
      final fullTranscript = parts.join('\n').trim();

      // Only save if call has actual dialogue
      if (fullTranscript.isEmpty) {
        debugPrint('ℹ️ [LOCAL FALLBACK COMMIT SKIPPED] No dialogue turns recorded in session.');
        return;
      }

      final summary = fullTranscript.length > 250
          ? '${fullTranscript.substring(0, 250)}...'
          : fullTranscript;

      final events = <String>[];
      final userLines = fullTranscript
          .split('\n')
          .where((l) => l.trim().toLowerCase().startsWith('user:'))
          .map((l) => l.trim().substring(5).trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (userLines.isNotEmpty) {
        final topic = userLines.first.length > 50 ? '${userLines.first.substring(0, 50)}...' : userLines.first;
        events.add('Diskusi: "$topic"');
      } else if (state.currentTranscript.isNotEmpty) {
        events.add('Topik: "${state.currentTranscript}"');
      }
      events.add('Sesi Konseling AI Suara');

      final title = userLines.isNotEmpty
          ? 'Refleksi: ${userLines.first.length > 30 ? "${userLines.first.substring(0, 30)}..." : userLines.first}'
          : 'Refleksi Sesi Panggilan Suara';

      final journalDelta = {
        'title': title,
        'summary': summary,
        'content': fullTranscript.isNotEmpty ? fullTranscript : summary,
        'mood_tag': 'Netral & Tenang 😌',
        'mood_emoji': '😌',
        'emotional_level': 3,
        'ai_insight': 'Sesi percakapan tersimpan secara aman di perangkat lokal Anda.',
        'emotional_reflection': 'Meluangkan waktu untuk mengekspresikan diri adalah langkah awal yang baik.',
        'important_events': events,
      };

      await diarySource.saveSessionArtifacts(
        sessionId: state.callId,
        sessionSummary: summary,
        journalDelta: journalDelta,
      );
      _onArtifactsCommitted?.call();
    } catch (e) {
      debugPrint('⚠️ [LOCAL FALLBACK COMMIT ERROR]: $e');
    }
  }

  Future<void> _handleSessionArtifactsReceived({
    required String requestId,
    required String sessionSummary,
    required Map<String, dynamic> journalDelta,
    required List<Map<String, dynamic>> candidates,
    Map<String, dynamic>? dassAssessment,
  }) async {
    _finalizeWatchdogTimer?.cancel();
    try {
      if (_synthesisService != null) {
        await _synthesisService.commitArtifactsLocally(
          sessionId: state.callId,
          sessionSummary: sessionSummary,
          journalDelta: journalDelta,
          dassAssessment: dassAssessment,
        );
      } else {
        final diarySource = _diaryDataSource;
        if (diarySource != null && (sessionSummary.isNotEmpty || journalDelta.isNotEmpty)) {
          await diarySource.saveSessionArtifacts(
            sessionId: state.callId,
            sessionSummary: sessionSummary,
            journalDelta: journalDelta,
          );
        }
      }
      _onArtifactsCommitted?.call();
      _wsClient.sendSessionArtifactsAck(requestId: requestId, status: 'committed_locally');
    } catch (e) {
      debugPrint('⚠️ [SESSION ARTIFACTS COMMIT ERROR]: $e');
    } finally {
      state = state.copyWith(
        pendingMemoryCandidates: candidates,
        isFinalizing: false,
        callState: CallState.ended,
      );
      _wsClient.disconnect();
    }
  }

  /// End Call & Disconnect (with post-session artifact finalization)
  Future<void> endCall() async {
    if (state.isFinalizing || state.callState == CallState.ended) return;

    // 0. Cancel mic audio chunk sender immediately to stop streaming to VPS
    _audioChunkSubscription?.cancel();
    _audioChunkSubscription = null;

    _durationTimer?.cancel();
    _thinkingWatchdogTimer?.cancel();
    _finalizeWatchdogTimer?.cancel();

    // 1. Immediately transition to ended state
    state = state.copyWith(
      callState: CallState.ended,
      isFinalizing: true,
      soundLevel: 0.05,
      isUserSpeaking: false,
    );

    await _audioCaptureService.stopCapture();
    await _audioPlaybackService.stop();

    // 2. Immediately commit local fallback artifacts to ensure 0% data loss
    await _commitLocalFallbackArtifacts();

    if (_synthesisService != null && state.accumulatedTranscript.trim().isNotEmpty) {
      await _synthesisService.markSessionPending(
        sessionId: state.callId,
        initialSummary: state.accumulatedTranscript,
      );
    }

    if (_wsClient.isConnected) {
      _wsClient.sendSessionFinalize(
        clientSessionId: state.callId,
        requestId: 'fin_${DateTime.now().millisecondsSinceEpoch}',
        durationSeconds: state.callDurationSeconds,
        requestMemoryCandidates: true,
      );

      // 2. Allow up to 15 seconds for DeepSeek LLM artifact generation
      _finalizeWatchdogTimer = Timer(const Duration(seconds: 15), () async {
        if (!_isDisposed && state.isFinalizing) {
          debugPrint('⏱️ [FINALIZE TIMEOUT] Triggering background stateless synthesis fallback...');
          _wsClient.sendEndCall(state.callDurationSeconds);
          _wsClient.disconnect();
          state = state.copyWith(isFinalizing: false, callState: CallState.ended);
          final ok = await _synthesisService?.synthesizeSessionOnDemand(sessionId: state.callId) ?? false;
          if (ok) {
            _onArtifactsCommitted?.call();
          }
        }
      });
    } else {
      state = state.copyWith(isFinalizing: false, callState: CallState.ended);
      _synthesisService?.synthesizeSessionOnDemand(sessionId: state.callId).then((ok) {
        if (ok) _onArtifactsCommitted?.call();
      });
    }
  }

  void _cancelSubscriptions() {
    _audioChunkSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _aiAudioSoundSubscription?.cancel();
    _playbackSubscription?.cancel();
    _wsAudioSubscription?.cancel();
    _wsEventSubscription?.cancel();
    _errorSubscription?.cancel();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelSubscriptions();
    _durationTimer?.cancel();
    _thinkingWatchdogTimer?.cancel();
    _finalizeWatchdogTimer?.cancel();
    if (state.isFinalizing) {
      _commitLocalFallbackArtifacts();
    }
    _audioCaptureService.dispose();
    _audioPlaybackService.stop();
    _wsClient.disconnect();
    super.dispose();
  }
}

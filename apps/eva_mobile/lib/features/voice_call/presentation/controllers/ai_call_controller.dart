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
  final bool _isMockBillingMode;
  final Future<void> Function(int balance)? _onCoinBalanceSynced;
  final Future<bool> Function(int coins)? _onMockSpendCoins;
  final int Function()? _readCurrentCoinBalance;

  AiCallController({
    required SingleAudioCaptureService audioCaptureService,
    required AiAudioPlaybackService audioPlaybackService,
    required VoiceCallWsClient wsClient,
    MemoryRepository? memoryRepository,
    LocalDiaryDataSource? diaryDataSource,
    StatelessSynthesisService? synthesisService,
    VoidCallback? onArtifactsCommitted,
    bool isMockBillingMode = false,
    Future<void> Function(int balance)? onCoinBalanceSynced,
    Future<bool> Function(int coins)? onMockSpendCoins,
    int Function()? readCurrentCoinBalance,
  })  : _audioCaptureService = audioCaptureService,
        _audioPlaybackService = audioPlaybackService,
        _wsClient = wsClient,
        _memoryRepository = memoryRepository,
        _diaryDataSource = diaryDataSource,
        _synthesisService = synthesisService,
        _onArtifactsCommitted = onArtifactsCommitted,
        _isMockBillingMode = isMockBillingMode,
        _onCoinBalanceSynced = onCoinBalanceSynced,
        _onMockSpendCoins = onMockSpendCoins,
        _readCurrentCoinBalance = readCurrentCoinBalance,
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
  Timer? _billingGraceTimer;
  bool _isDisposed = false;
  bool _isMockCycleRenewing = false;
  bool _billingEndedConfirmed = false;
  Future<void> _audioPipelineQueue = Future<void>.value();

  void _enqueueAudioPipelineTask(Future<void> Function() task) {
    _audioPipelineQueue = _audioPipelineQueue.then((_) async {
      if (_isDisposed || !mounted) return;
      await task();
    }).catchError((Object err, StackTrace st) {
      debugPrint('⚠️ [AUDIO PIPELINE QUEUE ERROR]: $err');
    });
  }

  bool get isCallEnded => state.callState == CallState.ended;

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

    _billingGraceTimer?.cancel();
    _isMockCycleRenewing = false;
    _billingEndedConfirmed = false;

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
      currentBilledMinute: 0,
      coinsPerMinute: CallConfig.aiCallCoinsPerMinute,
      isLowBalanceWarning: false,
      clearRemainingSeconds: true,
      clearBillingEnd: true,
      clearError: true,
      clearCrisis: true,
    );

    if (_isMockBillingMode) {
      final spent = await (_onMockSpendCoins?.call(CallConfig.aiCallCoinsPerMinute) ??
          Future.value(true));
      if (_isDisposed || !mounted) return;
      if (!spent) {
        state = state.copyWith(
          callState: CallState.ended,
          isBillingEnded: true,
          billingEndReason: 'call.billing_insufficient',
          errorMessage: 'Saldo koin tidak mencukupi untuk memulai telepon AI.',
        );
        return;
      }
      state = state.copyWith(
        currentBilledMinute: 1,
        remainingSecondsInCycle: CallConfig.aiCallIntervalSeconds,
      );
    }

    _initSubscriptions();

    _finalizeWatchdogTimer?.cancel();

    // 1. Initialize pure PCM 16kHz audio capture service
    await _audioCaptureService.initialize();

    // 2. Connect WebSocket
    await _wsClient.connect(callId);
    _wsClient.sendStartCall(voiceMode: effectiveVoiceMode);

    // 3. Start Duration & Billing Countdown Timer
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_onDurationTick());
    });

    // 4. Initial transition to LISTENING
    await enterListening();
  }

  Future<void> _onDurationTick() async {
    if (_isDisposed || !mounted || state.callState == CallState.ended) return;

    final nextDuration = state.callDurationSeconds + 1;
    final currentRem = state.remainingSecondsInCycle;
    final int? nextRem =
        (currentRem != null && currentRem > 0) ? currentRem - 1 : currentRem;

    if (_isMockBillingMode && !state.isBillingEnded && nextRem != null) {
      if (nextRem == CallConfig.aiCallWarningSeconds) {
        final currentBalance = _readCurrentCoinBalance?.call() ?? 0;
        final willExpire = currentBalance < state.coinsPerMinute;
        state = state.copyWith(
          callDurationSeconds: nextDuration,
          remainingSecondsInCycle: nextRem,
          isLowBalanceWarning: willExpire,
        );
        return;
      }
      if (nextRem <= 0) {
        state = state.copyWith(
          callDurationSeconds: nextDuration,
          remainingSecondsInCycle: 0,
        );
        await _handleMockCycleRenewal();
        return;
      }
    }

    state = state.copyWith(
      callDurationSeconds: nextDuration,
      remainingSecondsInCycle: nextRem,
    );
  }

  Future<void> _handleMockCycleRenewal() async {
    if (_isMockCycleRenewing || _isDisposed || !mounted || state.isBillingEnded) {
      return;
    }
    _isMockCycleRenewing = true;
    try {
      final ok = await (_onMockSpendCoins?.call(state.coinsPerMinute) ??
          Future.value(true));
      if (_isDisposed || !mounted || state.callState == CallState.ended) return;
      if (ok) {
        state = state.copyWith(
          currentBilledMinute: state.currentBilledMinute + 1,
          remainingSecondsInCycle: CallConfig.aiCallIntervalSeconds,
          isLowBalanceWarning: false,
        );
      } else {
        await _handleBillingExhausted(
          graceSeconds: CallConfig.aiCallGraceSeconds,
          isCrisis: state.isCrisisSession,
          reason: 'insufficient_coins',
          triggerLocalFinalize: true,
        );
      }
    } finally {
      _isMockCycleRenewing = false;
    }
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
      if (state.callState == CallState.ended || state.isFinalizing) {
        return;
      }
      final turnId = state.assistantTurnId;
      _enqueueAudioPipelineTask(() async {
        if (state.callState == CallState.ended || state.isFinalizing) return;
        if (state.callState != CallState.aiSpeaking) {
          await enterAiSpeaking(turnId);
        }
        if (_isDisposed || !mounted || state.callState == CallState.ended || state.isFinalizing) {
          return;
        }
        _audioPlaybackService.enqueueChunk(
          bytes: audioBytes,
          assistantTurnId: turnId,
          sequence: 0,
        );
      });
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
      final billing = event['billing'] is Map
          ? Map<String, dynamic>.from(event['billing'] as Map)
          : null;
      final remainingBalance = (billing?['remaining_balance'] as num?)?.toInt();
      if (remainingBalance != null) {
        unawaited(_onCoinBalanceSynced?.call(remainingBalance) ?? Future.value());
      }
      state = state.copyWith(
        voiceMode: (confirmedMode != null && confirmedMode.isNotEmpty)
            ? confirmedMode
            : state.voiceMode,
        coinsPerMinute:
            (billing?['coins_per_minute'] as num?)?.toInt() ?? state.coinsPerMinute,
        currentBilledMinute:
            (billing?['current_minute'] as num?)?.toInt() ??
                (state.currentBilledMinute > 0 ? state.currentBilledMinute : 1),
        remainingSecondsInCycle:
            (billing?['seconds_until_next_charge'] as num?)?.toInt() ??
                (billing?['interval_seconds'] as num?)?.toInt() ??
                state.remainingSecondsInCycle ??
                CallConfig.aiCallIntervalSeconds,
        isLowBalanceWarning: false,
      );
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
    } else if (type == 'call.billing_warning') {
      final willExpire = event['will_expire_if_zero'] as bool? ?? false;
      final secRem = (event['seconds_remaining'] as num?)?.toInt();
      final coinBal = (event['coin_balance'] as num?)?.toInt();
      if (coinBal != null) {
        unawaited(_onCoinBalanceSynced?.call(coinBal) ?? Future.value());
      }
      state = state.copyWith(
        isLowBalanceWarning: willExpire,
        remainingSecondsInCycle: secRem ?? state.remainingSecondsInCycle,
      );
    } else if (type == 'call.billing_charged') {
      final currentMinute = (event['current_minute'] as num?)?.toInt();
      final secNext = (event['seconds_until_next_charge'] as num?)?.toInt() ??
          CallConfig.aiCallIntervalSeconds;
      final remainingBalance = (event['remaining_balance'] as num?)?.toInt();
      if (remainingBalance != null) {
        unawaited(_onCoinBalanceSynced?.call(remainingBalance) ?? Future.value());
      }
      state = state.copyWith(
        currentBilledMinute: currentMinute ?? (state.currentBilledMinute + 1),
        remainingSecondsInCycle: secNext,
        isLowBalanceWarning: false,
      );
    } else if (type == 'call.billing_exhausted') {
      final graceS = (event['grace_seconds'] as num?)?.toInt() ??
          CallConfig.aiCallGraceSeconds;
      final isCrisis = (event['is_crisis'] as bool?) ?? state.isCrisisSession;
      final coinBal = (event['coin_balance'] as num?)?.toInt();
      if (coinBal != null) {
        unawaited(_onCoinBalanceSynced?.call(coinBal) ?? Future.value());
      }
      unawaited(
        _handleBillingExhausted(
          graceSeconds: graceS,
          isCrisis: isCrisis,
          reason: event['reason'] as String? ?? 'insufficient_coins',
          triggerLocalFinalize: false,
        ),
      );
    } else if (type == 'call.ended_by_billing') {
      _billingGraceTimer?.cancel();
      _billingEndedConfirmed = true;
      state = state.copyWith(
        isBillingEnded: true,
        isLowBalanceWarning: false,
        remainingSecondsInCycle: 0,
        billingEndReason: event['reason'] as String? ?? state.billingEndReason ?? 'insufficient_coins',
      );
      if (state.callState == CallState.aiSpeaking) {
        _billingGraceTimer = Timer(const Duration(seconds: 8), () async {
          if (!_isDisposed && mounted && state.callState != CallState.ended) {
            await endCall();
          }
        });
      } else {
        unawaited(endCall());
      }
    } else if (type == 'call.billing_insufficient' || type == 'call.auth_error') {
      final coinBal = (event['coin_balance'] as num?)?.toInt();
      if (coinBal != null) {
        unawaited(_onCoinBalanceSynced?.call(coinBal) ?? Future.value());
      }
      _durationTimer?.cancel();
      _thinkingWatchdogTimer?.cancel();
      _billingGraceTimer?.cancel();
      unawaited(_audioCaptureService.stopCapture());
      unawaited(_audioPlaybackService.stop());
      _wsClient.disconnect();
      state = state.copyWith(
        callState: CallState.ended,
        isBillingEnded: true,
        billingEndReason: type,
        errorMessage: event['message'] as String? ??
            'Tidak dapat memulai panggilan telepon AI.',
      );
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
      if (state.callState == CallState.ended || state.isFinalizing) return;
      final turnId = (event['assistant_turn_id'] as num?)?.toInt();
      if (turnId != null) {
        state = state.copyWith(assistantTurnId: turnId);
      }
      enterThinking();
    } else if (type == 'ai.transcript_chunk' || type == 'ai_transcript_chunk') {
      if (state.callState == CallState.ended || state.isFinalizing) return;
      final text = (event['text'] as String? ?? '').trim();
      if (text.isNotEmpty) {
        final prev = state.aiTranscript.trim();
        state = state.copyWith(
          aiTranscript: prev.isEmpty ? text : '$prev $text',
        );
      }
    } else if (type == 'ai.audio_chunk' || type == 'ai_audio_chunk') {
      if (state.callState == CallState.ended || state.isFinalizing) return;
      final turnId = (event['assistant_turn_id'] as num?)?.toInt() ?? state.assistantTurnId;
      final seq = (event['sequence'] as num?)?.toInt() ?? 0;
      final b64 = event['audio_base64'] as String?;
      final envelope = (event['envelope'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? <double>[];

      if (b64 != null && b64.isNotEmpty) {
        try {
          final audioBytes = base64Decode(b64);
          _enqueueAudioPipelineTask(() async {
            if (state.callState == CallState.ended ||
                state.isFinalizing ||
                state.callState == CallState.interrupting) {
              return;
            }
            if (state.callState != CallState.aiSpeaking) {
              await enterAiSpeaking(turnId);
            }
            if (_isDisposed ||
                !mounted ||
                state.callState == CallState.ended ||
                state.isFinalizing ||
                state.callState == CallState.interrupting) {
              return;
            }
            _audioPlaybackService.enqueueChunk(
              bytes: audioBytes,
              assistantTurnId: turnId,
              sequence: seq,
              envelope: envelope,
            );
          });
        } catch (e) {
          debugPrint('⚠️ [AI AUDIO DECODE ERROR]: $e');
        }
      }
    } else if (type == 'ai.speech_finished' || type == 'ai_speech_finished') {
      if (state.callState == CallState.ended || state.isFinalizing) return;
      final turnId = (event['assistant_turn_id'] as num?)?.toInt() ?? state.assistantTurnId;
      if (state.aiTranscript.isNotEmpty) {
        _synthesisService?.recordTurn(
          sessionId: state.callId,
          turnId: turnId,
          role: 'assistant',
          transcript: state.aiTranscript,
        );
      }
      _enqueueAudioPipelineTask(() async {
        if (_isDisposed || !mounted || state.callState == CallState.ended || state.isFinalizing) {
          return;
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
      });
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
      String? summaryText;
      if (transcriptList != null && transcriptList.isNotEmpty) {
        final buffer = StringBuffer();
        for (final item in transcriptList) {
          if (item is Map && item['content'] != null) {
            final role = (item['role'] == 'user') ? 'User' : 'EVA';
            buffer.writeln('$role: ${item['content']}');
          }
        }
        final trimmed = buffer.toString().trim();
        if (trimmed.isNotEmpty) {
          summaryText = trimmed;
        }
      }
      final emotionAnalysis = event['emotion_analysis'] is Map
          ? Map<String, dynamic>.from(event['emotion_analysis'] as Map)
          : null;
      final dominantEmotion = emotionAnalysis?['dominant_emotion']?.toString();
      final breakdown = (emotionAnalysis?['emotions_breakdown'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      state = state.copyWith(
        accumulatedTranscript: summaryText ?? state.accumulatedTranscript,
        // Reset aiTranscript after syncing full backend history to prevent duplicate EVA lines in enterListening
        aiTranscript: summaryText != null ? '' : state.aiTranscript,
        detectedEmotion: (dominantEmotion != null && dominantEmotion.isNotEmpty)
            ? dominantEmotion
            : state.detectedEmotion,
        activeEmotionsBreakdown: (breakdown != null && breakdown.isNotEmpty)
            ? breakdown
            : state.activeEmotionsBreakdown,
      );
    } else if (type == 'pong') {
      return;
    } else if (type == 'disconnected') {
      if (state.callState == CallState.ended || state.isFinalizing || state.isBillingEnded) {
        return;
      }
      _durationTimer?.cancel();
      _thinkingWatchdogTimer?.cancel();
      unawaited(_audioCaptureService.stopCapture());
      unawaited(_audioPlaybackService.stop());
      state = state.copyWith(
        callState: CallState.error,
        isUserSpeaking: false,
        errorMessage: 'Koneksi panggilan terputus. Silakan periksa jaringan Anda.',
      );
    } else if (type == 'error') {
      state = state.copyWith(errorMessage: event['message'] as String? ?? 'Terjadi kesalahan sistem');
      if (state.callState == CallState.thinking || state.callState == CallState.aiSpeaking) {
        enterListening();
      }
    }
  }

  /// Invariant: LISTENING -> PCM capture ON, AI audio OFF
  Future<void> enterListening() async {
    if (state.isBillingEnded) return;
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
    await _audioCaptureService.stopCapture();
    await _audioPlaybackService.prepareNewAssistantTurn(assistantTurnId);
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
      if (state.isBillingEnded) {
        if (_isMockBillingMode || _billingEndedConfirmed) {
          _billingGraceTimer?.cancel();
          await endCall();
        }
        return;
      }
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
    if (state.isBillingEnded || state.callState != CallState.listening) return;

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
      if (!_isDisposed && mounted) {
        state = state.copyWith(
          pendingMemoryCandidates: candidates,
          isFinalizing: false,
          callState: CallState.ended,
        );
      }
      _wsClient.disconnect();
    }
  }

  Future<void> _handleBillingExhausted({
    required int graceSeconds,
    required bool isCrisis,
    required String reason,
    required bool triggerLocalFinalize,
  }) async {
    if (_isDisposed || !mounted) return;
    await _audioCaptureService.stopCapture();

    state = state.copyWith(
      isBillingEnded: true,
      isLowBalanceWarning: false,
      remainingSecondsInCycle: 0,
      billingEndReason: reason,
    );

    if (!triggerLocalFinalize) return;

    final isAiBusy = state.callState == CallState.aiSpeaking ||
        state.callState == CallState.thinking;
    if (!isAiBusy) {
      await endCall();
      return;
    }

    _billingGraceTimer?.cancel();
    final timeoutSeconds = isCrisis ? 20 : graceSeconds;
    _billingGraceTimer = Timer(Duration(seconds: timeoutSeconds), () async {
      if (!_isDisposed && mounted && state.callState != CallState.ended) {
        await endCall();
      }
    });
  }

  /// Immediately silence AI & mic audio when user exits VoiceCallScreen without cancelling background synthesis
  void stopAudioForScreenExit() {
    _wsAudioSubscription?.cancel();
    _wsAudioSubscription = null;
    _audioChunkSubscription?.cancel();
    _audioChunkSubscription = null;
    _aiAudioSoundSubscription?.cancel();
    _aiAudioSoundSubscription = null;
    _playbackSubscription?.cancel();
    _playbackSubscription = null;
    unawaited(_audioPlaybackService.stop());
    unawaited(_audioCaptureService.stopCapture());
    if (_wsClient.isConnected &&
        (state.callState == CallState.aiSpeaking ||
            state.callState == CallState.thinking)) {
      _wsClient.sendInterrupt(
        callId: state.callId,
        assistantTurnId: state.assistantTurnId,
        reason: 'screen_exit',
      );
    }
  }

  /// End Call & Disconnect (with post-session artifact finalization)
  Future<void> endCall() async {
    if (state.isFinalizing || state.callState == CallState.ended) return;

    final prevState = state.callState;

    // 0. Stop mic and incoming AI audio immediately while keeping event stream open for finalization
    _audioChunkSubscription?.cancel();
    _audioChunkSubscription = null;
    _wsAudioSubscription?.cancel();
    _wsAudioSubscription = null;
    _aiAudioSoundSubscription?.cancel();
    _aiAudioSoundSubscription = null;
    _playbackSubscription?.cancel();
    _playbackSubscription = null;

    _durationTimer?.cancel();
    _thinkingWatchdogTimer?.cancel();
    _finalizeWatchdogTimer?.cancel();
    _billingGraceTimer?.cancel();

    if (_wsClient.isConnected &&
        (prevState == CallState.aiSpeaking || prevState == CallState.thinking)) {
      _wsClient.sendInterrupt(
        callId: state.callId,
        assistantTurnId: state.assistantTurnId,
        reason: 'call_ended',
      );
    }

    // 1. Immediately transition to ended state
    state = state.copyWith(
      callState: CallState.ended,
      isFinalizing: true,
      soundLevel: 0.05,
      isUserSpeaking: false,
    );

    await _audioCaptureService.stopCapture();
    await _audioPlaybackService.stop();
    if (_isDisposed || !mounted) return;

    // Flush any uncommitted turns into conversation_turns before synthesis
    if (_synthesisService != null) {
      if (state.currentTranscript.trim().isNotEmpty) {
        await _synthesisService.recordTurn(
          sessionId: state.callId,
          turnId: state.userTurnId,
          role: 'user',
          transcript: state.currentTranscript.trim(),
        );
      }
      if (_isDisposed || !mounted) return;
      if (state.aiTranscript.trim().isNotEmpty) {
        await _synthesisService.recordTurn(
          sessionId: state.callId,
          turnId: state.assistantTurnId > 0 ? state.assistantTurnId : state.userTurnId,
          role: 'assistant',
          transcript: state.aiTranscript.trim(),
        );
      }
      if (_isDisposed || !mounted) return;
      if (state.accumulatedTranscript.trim().isNotEmpty ||
          state.currentTranscript.trim().isNotEmpty ||
          state.aiTranscript.trim().isNotEmpty) {
        await _synthesisService.markSessionPending(
          sessionId: state.callId,
          initialSummary: '',
        );
      }
    } else {
      await _commitLocalFallbackArtifacts();
    }
    if (_isDisposed || !mounted) return;

    if (_wsClient.isConnected) {
      _wsClient.sendSessionFinalize(
        clientSessionId: state.callId,
        requestId: 'fin_${DateTime.now().millisecondsSinceEpoch}',
        durationSeconds: state.callDurationSeconds,
        requestMemoryCandidates: true,
      );

      // Allow up to 15 seconds for DeepSeek LLM artifact generation
      _finalizeWatchdogTimer = Timer(const Duration(seconds: 15), () async {
        if (!_isDisposed && state.isFinalizing) {
          debugPrint('⏱️ [FINALIZE TIMEOUT] Triggering background stateless synthesis fallback...');
          final callIdSnapshot = state.callId;
          _wsClient.sendEndCall(state.callDurationSeconds);
          _wsClient.disconnect();
          if (mounted) {
            state = state.copyWith(isFinalizing: false, callState: CallState.ended);
          }
          final ok = await _synthesisService?.synthesizeSessionOnDemand(sessionId: callIdSnapshot) ?? false;
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
    _billingGraceTimer?.cancel();
    if (_synthesisService == null && mounted && state.isFinalizing) {
      _commitLocalFallbackArtifacts();
    }
    _audioCaptureService.dispose();
    _audioPlaybackService.stop();
    _wsClient.disconnect();
    super.dispose();
  }
}

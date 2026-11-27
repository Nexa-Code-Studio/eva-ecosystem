import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/voice_call/data/datasources/voice_call_ws_client.dart';
import 'package:eva_mobile/features/voice_call/data/services/ai_audio_playback_service.dart';
import 'package:eva_mobile/features/voice_call/data/services/speech_recognition_service.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/call_state.dart';
import 'package:eva_mobile/features/voice_call/presentation/controllers/ai_call_controller.dart';

class FakeSpeechRecognitionService extends Fake implements SpeechRecognitionService {
  @override
  bool isInitialized = false;
  @override
  bool isListening = false;
  int activeSessionId = 0;
  @override
  bool isMuted = false;
  @override
  String get resolvedLocaleId => 'id_ID';

  final StreamController<SttPartialResult> partialController =
      StreamController<SttPartialResult>.broadcast();
  final StreamController<SttFinalResult> finalSegmentController =
      StreamController<SttFinalResult>.broadcast();
  final StreamController<SttStatusEvent> statusController =
      StreamController<SttStatusEvent>.broadcast();
  final StreamController<double> soundLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> errorController =
      StreamController<String>.broadcast();

  @override
  Stream<SttPartialResult> get partialStream => partialController.stream;
  @override
  Stream<SttFinalResult> get finalSegmentStream => finalSegmentController.stream;
  @override
  Stream<SttStatusEvent> get statusStream => statusController.stream;
  @override
  Stream<double> get soundLevelStream => soundLevelController.stream;
  @override
  Stream<String> get errorStream => errorController.stream;

  @override
  Future<bool> initialize() async {
    isInitialized = true;
    return true;
  }

  @override
  Future<void> startListening({required int sttSessionId}) async {
    isListening = true;
    activeSessionId = sttSessionId;
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
  }

  @override
  void setMuted(bool muted) {
    isMuted = muted;
    if (isMuted) isListening = false;
  }

  @override
  void dispose() {
    partialController.close();
    finalSegmentController.close();
    statusController.close();
    soundLevelController.close();
    errorController.close();
  }
}

class FakeAiAudioPlaybackService extends Fake implements AiAudioPlaybackService {
  @override
  bool isPlaying = false;
  int currentTurn = 0;
  final StreamController<int> playbackCompletedController =
      StreamController<int>.broadcast();
  final StreamController<double> soundLevelController =
      StreamController<double>.broadcast();

  @override
  Stream<int> get onPlaybackCompleted => playbackCompletedController.stream;

  @override
  Stream<double> get soundLevelStream => soundLevelController.stream;

  @override
  void prepareNewAssistantTurn(int assistantTurnId) {
    currentTurn = assistantTurnId;
  }

  List<double> lastEnqueuedEnvelope = [];
  Uint8List? lastEnqueuedBytes;

  @override
  void enqueueChunk({
    required Uint8List bytes,
    required int assistantTurnId,
    required int sequence,
    List<double> envelope = const [],
  }) {
    lastEnqueuedBytes = bytes;
    lastEnqueuedEnvelope = envelope;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
  }

  @override
  void markStreamFinished(int assistantTurnId) {}

  @override
  void dispose() {
    playbackCompletedController.close();
    soundLevelController.close();
  }
}

class FakeVoiceCallWsClient extends Fake implements VoiceCallWsClient {
  @override
  bool isConnected = false;
  final List<Map<String, dynamic>> sentEvents = [];
  final StreamController<Map<String, dynamic>> eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> audioController =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Map<String, dynamic>> get eventStream => eventController.stream;
  @override
  Stream<Uint8List> get audioStream => audioController.stream;

  @override
  Future<void> connect(String sessionId) async {
    isConnected = true;
  }

  @override
  void sendStartCall({String? voiceMode}) {
    final payload = <String, dynamic>{'type': 'start_call'};
    if (voiceMode != null) {
      payload['voice_mode'] = voiceMode;
    }
    sentEvents.add(payload);
  }

  @override
  void sendAudioBoundary({required String callId, required String reason}) {
    sentEvents.add({
      'type': 'audio.boundary',
      'call_id': callId,
      'reason': reason,
    });
  }

  @override
  void sendPartial({
    required String callId,
    required int userTurnId,
    required int sttSessionId,
    required int sequence,
    required String text,
  }) {
    sentEvents.add({
      'type': 'stt.partial',
      'call_id': callId,
      'user_turn_id': userTurnId,
      'stt_session_id': sttSessionId,
      'sequence': sequence,
      'text': text,
    });
  }

  @override
  void sendFinalSegment({
    required String callId,
    required int userTurnId,
    required int sttSessionId,
    required int sequence,
    required String text,
  }) {
    sentEvents.add({
      'type': 'stt.final_segment',
      'call_id': callId,
      'user_turn_id': userTurnId,
      'stt_session_id': sttSessionId,
      'sequence': sequence,
      'text': text,
    });
  }

  @override
  void sendStatus({
    required String callId,
    required int userTurnId,
    required int sttSessionId,
    required String status,
  }) {
    sentEvents.add({
      'type': 'stt.status',
      'status': status,
      'call_id': callId,
      'user_turn_id': userTurnId,
      'stt_session_id': sttSessionId,
    });
  }

  @override
  void sendInterrupt({
    required String callId,
    required int assistantTurnId,
    String reason = 'user_barge_in',
  }) {
    sentEvents.add({
      'type': 'assistant.interrupt',
      'call_id': callId,
      'assistant_turn_id': assistantTurnId,
      'reason': reason,
    });
  }

  @override
  void sendPlaybackFinished({
    required String callId,
    required int assistantTurnId,
  }) {
    sentEvents.add({
      'type': 'playback.finished',
      'call_id': callId,
      'assistant_turn_id': assistantTurnId,
    });
  }

  @override
  void sendForceCommit({
    required String callId,
    required int userTurnId,
  }) {
    sentEvents.add({
      'type': 'user.force_commit',
      'call_id': callId,
      'user_turn_id': userTurnId,
    });
  }

  @override
  void sendEndCall(int durationSeconds) {
    sentEvents.add({
      'type': 'end_call',
      'duration_seconds': durationSeconds,
    });
  }

  @override
  void sendSessionFinalize({
    required String clientSessionId,
    required String requestId,
    required int durationSeconds,
    bool requestMemoryCandidates = true,
  }) {
    sentEvents.add({
      'type': 'session_finalize_v1',
      'client_session_id': clientSessionId,
      'request_id': requestId,
      'duration_seconds': durationSeconds,
      'request_memory_candidates': requestMemoryCandidates,
    });
  }

  @override
  void sendSessionArtifactsAck({
    required String requestId,
    String status = 'committed_locally',
  }) {
    sentEvents.add({
      'type': 'session_artifacts_ack_v1',
      'request_id': requestId,
      'status': status,
    });
  }

  @override
  void disconnect() {
    isConnected = false;
  }

  @override
  void dispose() {
    eventController.close();
    audioController.close();
  }
}

void main() {
  late FakeSpeechRecognitionService fakeSpeech;
  late FakeAiAudioPlaybackService fakeAudio;
  late FakeVoiceCallWsClient fakeWs;
  late AiCallController controller;

  setUp(() {
    fakeSpeech = FakeSpeechRecognitionService();
    fakeAudio = FakeAiAudioPlaybackService();
    fakeWs = FakeVoiceCallWsClient();
    controller = AiCallController(
      speechService: fakeSpeech,
      audioPlaybackService: fakeAudio,
      wsClient: fakeWs,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('startCall initializes services and enters listening', () async {
    await controller.startCall(customCallId: 'test_call_101');

    expect(controller.state.callId, 'test_call_101');
    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 1);
    expect(fakeSpeech.isListening, isTrue);
    expect(fakeWs.isConnected, isTrue);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'start_call'), isTrue);
  });

  test('startCall passes custom voiceMode and updates state', () async {
    await controller.startCall(customCallId: 'test_call_mode_7', voiceMode: 'mode_7');

    expect(controller.state.voiceMode, 'mode_7');
    final startCallEvent = fakeWs.sentEvents.firstWhere((e) => e['type'] == 'start_call');
    expect(startCallEvent['voice_mode'], 'mode_7');
  });

  test('call_started event confirms and updates state.voiceMode', () async {
    await controller.startCall();
    controller.handleSocketEvent({
      'type': 'call_started',
      'session_id': controller.state.callId,
      'voice_mode': 'mode_4',
    });

    expect(controller.state.voiceMode, 'mode_4');
  });

  test('stale STT callback from old session is discarded', () async {
    await controller.startCall();
    final currentSessionId = controller.state.activeSttSessionId;

    // Send callback with wrong/old session ID
    fakeSpeech.partialController.add(SttPartialResult(
      text: 'stale callback words',
      sttSessionId: currentSessionId - 1,
      sequence: 1,
    ));

    await pumpEventQueue();

    expect(controller.state.latestPartial, '');
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'stt.partial'), isFalse);

    // Send callback with correct session ID
    fakeSpeech.partialController.add(SttPartialResult(
      text: 'valid speech words',
      sttSessionId: currentSessionId,
      sequence: 1,
    ));

    await pumpEventQueue();

    expect(controller.state.latestPartial, 'valid speech words');
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'stt.partial'), isTrue);
  });

  test('turn.committed transitions to thinking and stops STT', () async {
    await controller.startCall();

    controller.handleSocketEvent({
      'type': 'turn.committed',
      'final_transcript': 'halo eva apa kabar',
    });

    expect(controller.state.callState, CallState.thinking);
    expect(controller.state.currentTranscript, 'halo eva apa kabar');
    expect(fakeSpeech.isListening, isFalse);
  });

  test('emotion_result WebSocket event updates state.detectedEmotion and activeEmotionsBreakdown', () async {
    await controller.startCall();

    controller.handleSocketEvent({
      'type': 'emotion_result',
      'call_id': 'test_call_101',
      'user_turn_id': 1,
      'primary_emotion': 'happy',
      'confidence': 0.88,
      'intensity': 0.79,
      'emotions_breakdown': [
        {'name': 'happy', 'percent': 0.88, 'label': 'Bahagia & Senang', 'emoji': '😃'},
        {'name': 'neutral', 'percent': 0.12, 'label': 'Netral & Tenang', 'emoji': '😌'},
      ],
    });

    expect(controller.state.detectedEmotion, 'happy');
    expect(controller.state.detectedEmotionConfidence, 0.88);
    expect(controller.state.activeEmotionsBreakdown.length, 2);
    expect(controller.state.activeEmotionsBreakdown[0]['name'], 'happy');
  });

  test('AI speaking state stops STT and plays audio', () async {
    await controller.startCall();

    await controller.enterAiSpeaking(1);

    expect(controller.state.callState, CallState.aiSpeaking);
    expect(controller.state.assistantTurnId, 1);
    expect(fakeSpeech.isListening, isFalse);
  });

  test('manual bargeIn stops audio and enters listening after guard', () async {
    await controller.startCall();
    await controller.enterAiSpeaking(1);

    await controller.bargeIn();

    // Guard delay completes, should be listening with incremented userTurnId
    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 2);
    expect(fakeAudio.isPlaying, isFalse);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'assistant.interrupt'), isTrue);
    expect(fakeSpeech.isListening, isTrue);
  });

  test('double tap barge-in is idempotent', () async {
    await controller.startCall();
    await controller.enterAiSpeaking(1);

    // First tap
    final future1 = controller.bargeIn();
    // Second tap immediately while in interrupting
    final future2 = controller.bargeIn();

    await Future.wait([future1, future2]);

    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 2); // Only incremented once!
  });

  test('barge-in during thinking cancels pending generation and returns to listening', () async {
    await controller.startCall();
    await controller.enterThinking();
    expect(controller.state.callState, CallState.thinking);

    await controller.bargeIn();

    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 2);
    expect(fakeSpeech.isListening, isTrue);
  });

  test('handlePlaybackFinished automatically enters listening after guard delay', () async {
    await controller.startCall();
    await controller.enterAiSpeaking(1);

    await controller.handlePlaybackFinished(1);

    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 2);
    expect(fakeSpeech.isListening, isTrue);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'playback.finished'), isTrue);
  });

  test('forceCommit sends user.force_commit and enters thinking', () async {
    await controller.startCall();

    await controller.forceCommit();

    expect(controller.state.callState, CallState.thinking);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'user.force_commit'), isTrue);
    expect(fakeSpeech.isListening, isFalse);
  });

  test('toggleMute toggles mute and pauses STT', () async {
    await controller.startCall();
    expect(controller.state.isMuted, isFalse);

    await controller.toggleMute();
    expect(controller.state.isMuted, isTrue);
    expect(fakeSpeech.isListening, isFalse);

    await controller.toggleMute();
    expect(controller.state.isMuted, isFalse);
    expect(fakeSpeech.isListening, isTrue);
  });

  test('push-to-talk mode press and release flow', () async {
    await controller.startCall();

    controller.setConversationMode(ConversationMode.pushToTalk);
    expect(controller.state.conversationMode, ConversationMode.pushToTalk);
    expect(fakeSpeech.isListening, isFalse);

    // Press down
    await controller.pushToTalkPress();
    expect(fakeSpeech.isListening, isTrue);

    // Release
    await controller.pushToTalkRelease();
    expect(controller.state.callState, CallState.thinking);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'user.force_commit'), isTrue);
  });

  test('ai.audio_chunk event enters aiSpeaking and delegates envelope', () async {
    await controller.startCall();

    fakeWs.eventController.add({
      'type': 'ai.audio_chunk',
      'assistant_turn_id': 1,
      'sequence': 1,
      'audio_base64': base64Encode([1, 2, 3, 4]),
      'envelope': [0.1, 0.4, 0.8, 0.2],
    });
    await pumpEventQueue();

    expect(controller.state.callState, CallState.aiSpeaking);
    expect(fakeAudio.lastEnqueuedEnvelope, [0.1, 0.4, 0.8, 0.2]);
  });

  test('soundLevelStream updates state.soundLevel when aiSpeaking', () async {
    await controller.startCall();
    await controller.enterAiSpeaking(1);

    fakeAudio.soundLevelController.add(0.78);
    await pumpEventQueue();

    expect(controller.state.soundLevel, 0.78);
  });

  test('ai.crisis_escalation event flags isCrisisSession and records hotline info', () async {
    await controller.startCall();
    expect(controller.state.isCrisisSession, isFalse);

    fakeWs.eventController.add({
      'type': 'ai.crisis_escalation',
      'risk_level': 'critical',
      'hotline': 'Hotline Dinkes (WhatsApp 0813-8007-3120)',
      'hotline_url': 'https://api.whatsapp.com/send/?phone=6281380073120',
    });
    await pumpEventQueue();

    expect(controller.state.isCrisisSession, isTrue);
    expect(controller.state.crisisHotline, 'Hotline Dinkes (WhatsApp 0813-8007-3120)');
    expect(controller.state.crisisHotlineUrl, 'https://api.whatsapp.com/send/?phone=6281380073120');
  });

  test('startCall resets isCrisisSession to false', () async {
    await controller.startCall();
    fakeWs.eventController.add({
      'type': 'ai.crisis_escalation',
      'risk_level': 'critical',
    });
    await pumpEventQueue();
    expect(controller.state.isCrisisSession, isTrue);

    await controller.startCall();
    expect(controller.state.isCrisisSession, isFalse);
    expect(controller.state.crisisHotline, isNull);
  });

  test('turn.keep_open while in thinking recovers state to listening', () async {
    await controller.startCall();
    await controller.forceCommit();
    expect(controller.state.callState, CallState.thinking);

    fakeWs.eventController.add({
      'type': 'turn.keep_open',
      'restart_stt': true,
      'reason': 'empty_force_commit',
    });
    await pumpEventQueue();

    expect(controller.state.callState, CallState.listening);
    expect(fakeSpeech.isListening, isTrue);
  });

  test('error event while in thinking recovers state to listening', () async {
    await controller.startCall();
    await controller.enterThinking();
    expect(controller.state.callState, CallState.thinking);

    fakeWs.eventController.add({
      'type': 'error',
      'message': 'AI service timeout',
    });
    await pumpEventQueue();

    expect(controller.state.callState, CallState.listening);
    expect(controller.state.errorMessage, 'AI service timeout');
    expect(fakeSpeech.isListening, isTrue);
  });

  test('call.sync_state with listening recovers thinking state', () async {
    await controller.startCall();
    await controller.enterThinking();
    expect(controller.state.callState, CallState.thinking);

    fakeWs.eventController.add({
      'type': 'call.sync_state',
      'state': 'listening',
      'active_user_turn_id': 1,
    });
    await pumpEventQueue();

    expect(controller.state.callState, CallState.listening);
  });

  test('ai.speech_finished without audio recovers state to listening', () async {
    await controller.startCall();
    await controller.enterThinking();
    expect(controller.state.callState, CallState.thinking);

    fakeWs.eventController.add({
      'type': 'ai.speech_finished',
      'assistant_turn_id': 1,
    });
    await pumpEventQueue();

    // Fast-forward delayed reading timer
    await Future.delayed(const Duration(milliseconds: 1600));

    expect(controller.state.callState, CallState.listening);
    expect(controller.state.userTurnId, 2);
  });

  test('endCall sends session_finalize_v1 and enters finalizing state', () async {
    await controller.startCall();
    expect(fakeWs.isConnected, true);

    await controller.endCall();
    expect(controller.state.isFinalizing, true);

    final finalizeEvent = fakeWs.sentEvents.firstWhere(
      (e) => e['type'] == 'session_finalize_v1',
      orElse: () => {},
    );
    expect(finalizeEvent.isNotEmpty, true);
    expect(finalizeEvent['client_session_id'], controller.state.callId);

    // Simulate server acknowledging with session_finalized_v1
    fakeWs.eventController.add({
      'type': 'session_finalized_v1',
      'request_id': finalizeEvent['request_id'],
      'status': 'closed',
    });
    await pumpEventQueue();

    expect(controller.state.isFinalizing, false);
    expect(controller.state.callState, CallState.ended);
  });

  test('emotion_result with unavailable status does not apply fabricated neutral score', () async {
    await controller.startCall();
    final initialEmotion = controller.state.detectedEmotion;
    final initialConfidence = controller.state.detectedEmotionConfidence;

    fakeWs.eventController.add({
      'type': 'emotion_result',
      'status': 'unavailable',
      'source': 'unavailable',
      'primary_emotion': null,
      'confidence': null,
    });
    await pumpEventQueue();

    expect(controller.state.detectedEmotion, initialEmotion);
    expect(controller.state.detectedEmotionConfidence, initialConfidence);
  });

  test('toggleMute sends optional audio.boundary event to backend segmenter', () async {
    await controller.startCall();
    await controller.toggleMute();
    expect(controller.state.isMuted, true);

    final boundaryEvt = fakeWs.sentEvents.firstWhere(
      (e) => e['type'] == 'audio.boundary',
      orElse: () => {},
    );
    expect(boundaryEvt['reason'], 'mute');

    await controller.toggleMute();
    expect(controller.state.isMuted, false);
    final unmuteEvt = fakeWs.sentEvents.lastWhere(
      (e) => e['type'] == 'audio.boundary',
      orElse: () => {},
    );
    expect(unmuteEvt['reason'], 'unmute');
  });

  test('enterThinking and enterAiSpeaking emit audio.boundary hints cleanly', () async {
    await controller.startCall();
    await controller.enterThinking();
    expect(
      fakeWs.sentEvents.any((e) => e['type'] == 'audio.boundary' && e['reason'] == 'turn_thinking'),
      isTrue,
    );

    await controller.enterAiSpeaking(1);
    expect(
      fakeWs.sentEvents.any((e) => e['type'] == 'audio.boundary' && e['reason'] == 'ai_speaking'),
      isTrue,
    );
  });

  test('endCall while disconnected does not throw when disposed mid-flight', () async {
    await controller.startCall();
    fakeWs.isConnected = false;

    final endFuture = controller.endCall();
    controller.dispose();
    await endFuture;
  });

  group('AI Call Billing & Timer', () {
    test('handles call_started billing metadata, warning, renewal, and exhausted', () async {
      int syncedBalance = 10;
      final billingController = AiCallController(
        speechService: fakeSpeech,
        audioPlaybackService: fakeAudio,
        wsClient: fakeWs,
        onCoinBalanceSynced: (bal) async {
          syncedBalance = bal;
        },
      );
      addTearDown(billingController.dispose);

      await billingController.startCall(customCallId: 'bill_call_1');

      fakeWs.eventController.add({
        'type': 'call_started',
        'voice_mode': 'mode_2',
        'billing': {
          'coins_per_minute': 1,
          'interval_seconds': 60,
          'warning_seconds': 15,
          'current_minute': 1,
          'remaining_balance': 1,
          'seconds_until_next_charge': 60,
        },
      });
      await pumpEventQueue();

      expect(syncedBalance, 1);
      expect(billingController.state.currentBilledMinute, 1);
      expect(billingController.state.remainingSecondsInCycle, 60);
      expect(billingController.state.isLowBalanceWarning, false);

      fakeWs.eventController.add({
        'type': 'call.billing_charged',
        'current_minute': 2,
        'coins_debited': 1,
        'remaining_balance': 0,
        'seconds_until_next_charge': 60,
      });
      await pumpEventQueue();

      expect(syncedBalance, 0);
      expect(billingController.state.currentBilledMinute, 2);
      expect(billingController.state.remainingSecondsInCycle, 60);

      fakeWs.eventController.add({
        'type': 'call.billing_warning',
        'seconds_remaining': 15,
        'coin_balance': 0,
        'will_expire_if_zero': true,
      });
      await pumpEventQueue();

      expect(billingController.state.isLowBalanceWarning, true);
      expect(billingController.state.remainingSecondsInCycle, 15);

      fakeWs.eventController.add({
        'type': 'call.billing_exhausted',
        'reason': 'insufficient_coins',
        'coin_balance': 0,
        'grace_seconds': 5,
        'is_crisis': false,
      });
      await pumpEventQueue();

      expect(billingController.state.isBillingEnded, true);
      expect(billingController.state.remainingSecondsInCycle, 0);

      fakeWs.eventController.add({
        'type': 'call.ended_by_billing',
        'reason': 'insufficient_coins',
      });
      await pumpEventQueue();

      expect(billingController.state.callState, CallState.ended);
    });

    test('mock billing mode deducts 1 coin on start and ends when coins are 0', () async {
      int mockCoins = 0;
      final emptyController = AiCallController(
        speechService: fakeSpeech,
        audioPlaybackService: fakeAudio,
        wsClient: fakeWs,
        isMockBillingMode: true,
        readCurrentCoinBalance: () => mockCoins,
        onMockSpendCoins: (coins) async {
          if (mockCoins < coins) return false;
          mockCoins -= coins;
          return true;
        },
      );
      addTearDown(emptyController.dispose);

      await emptyController.startCall(customCallId: 'mock_empty_call');
      expect(emptyController.state.callState, CallState.ended);
      expect(emptyController.state.isBillingEnded, true);
      expect(emptyController.state.billingEndReason, 'call.billing_insufficient');

      mockCoins = 2;
      final activeController = AiCallController(
        speechService: fakeSpeech,
        audioPlaybackService: fakeAudio,
        wsClient: fakeWs,
        isMockBillingMode: true,
        readCurrentCoinBalance: () => mockCoins,
        onMockSpendCoins: (coins) async {
          if (mockCoins < coins) return false;
          mockCoins -= coins;
          return true;
        },
      );
      addTearDown(activeController.dispose);

      await activeController.startCall(customCallId: 'mock_active_call');
      expect(mockCoins, 1);
      expect(activeController.state.currentBilledMinute, 1);
      expect(activeController.state.remainingSecondsInCycle, 60);
    });
  });
}

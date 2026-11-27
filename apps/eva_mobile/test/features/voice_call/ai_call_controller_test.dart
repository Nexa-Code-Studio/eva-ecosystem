import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:eva_mobile/features/voice_call/data/datasources/voice_call_ws_client.dart';
import 'package:eva_mobile/features/voice_call/data/services/ai_audio_playback_service.dart';
import 'package:eva_mobile/features/voice_call/data/services/single_audio_capture_service.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/call_state.dart';
import 'package:eva_mobile/features/voice_call/presentation/controllers/ai_call_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSingleAudioCaptureService extends Fake implements SingleAudioCaptureService {
  @override
  bool isInitialized = false;
  @override
  bool isCapturing = false;
  @override
  bool isMuted = false;

  int startCount = 0;
  int stopCount = 0;

  final StreamController<Uint8List> audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> soundLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> errorController =
      StreamController<String>.broadcast();

  @override
  Stream<Uint8List> get audioStream => audioController.stream;
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
  Future<bool> startCapture() async {
    if (isMuted) return false;
    isCapturing = true;
    startCount++;
    return true;
  }

  @override
  Future<void> stopCapture() async {
    isCapturing = false;
    stopCount++;
  }

  @override
  Future<void> setMuted(bool muted) async {
    isMuted = muted;
    if (muted) isCapturing = false;
  }

  @override
  void dispose() {
    audioController.close();
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

  List<double> lastEnqueuedEnvelope = [];
  Uint8List? lastEnqueuedBytes;

  @override
  Stream<int> get onPlaybackCompleted => playbackCompletedController.stream;
  @override
  Stream<double> get soundLevelStream => soundLevelController.stream;

  @override
  void prepareNewAssistantTurn(int assistantTurnId) {
    currentTurn = assistantTurnId;
  }

  @override
  void enqueueChunk({
    required Uint8List bytes,
    required int assistantTurnId,
    required int sequence,
    List<double> envelope = const [],
  }) {
    lastEnqueuedBytes = bytes;
    lastEnqueuedEnvelope = envelope;
    isPlaying = true;
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
  final List<Uint8List> sentAudioChunks = [];

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
  void sendAudioChunk(Uint8List audioBytes) {
    sentAudioChunks.add(audioBytes);
  }

  @override
  void sendStartCall({String? voiceMode}) {
    final payload = <String, dynamic>{'type': 'start_call'};
    if (voiceMode != null) payload['voice_mode'] = voiceMode;
    sentEvents.add(payload);
  }

  @override
  void sendAudioBoundary({required String callId, required String reason}) {
    sentEvents.add({'type': 'audio.boundary', 'call_id': callId, 'reason': reason});
  }

  @override
  void sendForceCommit({required String callId, required int userTurnId}) {
    sentEvents.add({'type': 'user.force_commit', 'call_id': callId, 'user_turn_id': userTurnId});
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
  void sendPlaybackFinished({required String callId, required int assistantTurnId}) {
    sentEvents.add({
      'type': 'playback.finished',
      'call_id': callId,
      'assistant_turn_id': assistantTurnId,
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
    });
  }

  @override
  void sendEndCall(int durationSeconds) {
    sentEvents.add({'type': 'end_call', 'duration_seconds': durationSeconds});
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSingleAudioCaptureService fakeCapture;
  late FakeAiAudioPlaybackService fakePlayback;
  late FakeVoiceCallWsClient fakeWs;
  late AiCallController controller;

  setUp(() {
    fakeCapture = FakeSingleAudioCaptureService();
    fakePlayback = FakeAiAudioPlaybackService();
    fakeWs = FakeVoiceCallWsClient();
    controller = AiCallController(
      audioCaptureService: fakeCapture,
      audioPlaybackService: fakePlayback,
      wsClient: fakeWs,
    );
  });

  tearDown(() {
    controller.dispose();
    fakePlayback.dispose();
    fakeWs.dispose();
  });

  test('streams binary PCM only while listening and unmuted', () async {
    await controller.startCall(customCallId: 'call_pcm_1', voiceMode: 'mode_2');

    expect(controller.state.callState, CallState.listening);
    expect(fakeCapture.isCapturing, isTrue);

    final pcmFrame = Uint8List.fromList(List<int>.filled(4800, 3));
    fakeCapture.audioController.add(pcmFrame);
    await pumpEventQueue();
    expect(fakeWs.sentAudioChunks.length, 1);

    // Mute blocks PCM sending and emits audio.boundary(mute)
    controller.toggleMute();
    fakeCapture.audioController.add(pcmFrame);
    await pumpEventQueue();
    expect(fakeWs.sentAudioChunks.length, 1);
    expect(
      fakeWs.sentEvents.any((e) => e['type'] == 'audio.boundary' && e['reason'] == 'mute'),
      isTrue,
    );

    // Unmute resumes capture and emits audio.boundary(unmute)
    controller.toggleMute();
    fakeCapture.audioController.add(pcmFrame);
    await pumpEventQueue();
    expect(fakeWs.sentAudioChunks.length, 2);
    expect(
      fakeWs.sentEvents.any((e) => e['type'] == 'audio.boundary' && e['reason'] == 'unmute'),
      isTrue,
    );

    // Entering thinking stops capture and blocks PCM frames
    await controller.enterThinking();
    expect(fakeCapture.isCapturing, isFalse);
    fakeCapture.audioController.add(pcmFrame);
    await pumpEventQueue();
    expect(fakeWs.sentAudioChunks.length, 2);
  });

  test('renders backend stt.partial, stt.final_segment, and stt.status events live', () async {
    await controller.startCall(customCallId: 'call_stt_ws');

    fakeWs.eventController.add({
      'type': 'stt.status',
      'user_turn_id': 1,
      'stt_session_id': 2,
      'status': 'listening',
    });
    fakeWs.eventController.add({
      'type': 'stt.partial',
      'user_turn_id': 1,
      'stt_session_id': 2,
      'text': 'hari ini aku',
    });
    await pumpEventQueue();

    expect(controller.state.activeSttSessionId, 2);
    expect(controller.state.latestPartial, 'hari ini aku');
    expect(controller.state.isUserSpeaking, isTrue);

    fakeWs.eventController.add({
      'type': 'stt.final_segment',
      'user_turn_id': 1,
      'stt_session_id': 2,
      'text': 'hari ini aku capek banget',
    });
    await pumpEventQueue();

    expect(controller.state.currentTranscript, 'hari ini aku capek banget');
    expect(controller.state.latestPartial, '');

    // Incognito block notice surfaces user-friendly message
    fakeWs.eventController.add({
      'type': 'stt.status',
      'user_turn_id': 1,
      'stt_session_id': 2,
      'status': 'incognito_blocked',
    });
    await pumpEventQueue();
    expect(controller.state.errorMessage, contains('incognito'));
  });

  test('handles turn.committed, ai audio playback, playback.finished, bargeIn, and forceCommit', () async {
    await controller.startCall(customCallId: 'call_flow_1');

    // Manual force commit
    await controller.forceCommit();
    expect(controller.state.callState, CallState.thinking);
    expect(fakeCapture.isCapturing, isFalse);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'user.force_commit'), isTrue);

    // Backend returns turn.keep_open -> recovers to listening
    fakeWs.eventController.add({
      'type': 'turn.keep_open',
      'user_turn_id': 1,
      'restart_stt': true,
    });
    await pumpEventQueue();
    expect(controller.state.callState, CallState.listening);
    expect(fakeCapture.isCapturing, isTrue);

    // Backend commits turn and streams AI audio
    fakeWs.eventController.add({
      'type': 'turn.committed',
      'user_turn_id': 1,
      'final_transcript': 'Aku lagi cemas',
    });
    fakeWs.eventController.add({
      'type': 'ai.audio_chunk',
      'assistant_turn_id': 1,
      'sequence': 1,
      'audio_base64': base64Encode([1, 2, 3, 4]),
      'envelope': [0.2, 0.6],
    });
    await pumpEventQueue();

    expect(controller.state.callState, CallState.aiSpeaking);
    expect(fakeCapture.isCapturing, isFalse);
    expect(fakePlayback.lastEnqueuedBytes, isNotNull);

    // Barge-in interrupts AI and resumes capture
    await controller.bargeIn();
    expect(controller.state.callState, CallState.listening);
    expect(fakeCapture.isCapturing, isTrue);
    expect(fakeWs.sentEvents.any((e) => e['type'] == 'assistant.interrupt'), isTrue);

    // Receive live emotion_result from backend
    fakeWs.eventController.add({
      'type': 'emotion_result',
      'status': 'ready',
      'primary_emotion': 'sad',
      'confidence': 0.84,
      'emotions_breakdown': [
        {'name': 'sad', 'percent': 0.84},
      ],
    });
    await pumpEventQueue();
    expect(controller.state.detectedEmotion, 'sad');
    expect(controller.state.detectedEmotionConfidence, 0.84);
  });

  group('AI Call Billing & Timer', () {
    test('handles call_started billing metadata, warning, renewal, and exhausted', () async {
      int syncedBalance = 10;
      final billingController = AiCallController(
        audioCaptureService: fakeCapture,
        audioPlaybackService: fakePlayback,
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
        audioCaptureService: fakeCapture,
        audioPlaybackService: fakePlayback,
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
        audioCaptureService: fakeCapture,
        audioPlaybackService: fakePlayback,
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

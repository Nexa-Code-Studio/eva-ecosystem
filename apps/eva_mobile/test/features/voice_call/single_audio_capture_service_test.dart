import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/voice_call/config/audio_pipeline_config.dart';
import 'package:eva_mobile/features/voice_call/data/services/single_audio_capture_service.dart';
import 'package:eva_mobile/features/voice_call/data/services/speech_recognition_service.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/audio_pipeline_mode.dart';

import 'ai_call_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannelName = 'com.eva.single_audio/methods_test';
  const audioEventChannelName = 'com.eva.single_audio/audio_stream_test';
  const sttEventChannelName = 'com.eva.single_audio/stt_events_test';

  const methodChannel = MethodChannel(methodChannelName);
  const audioEventChannel = EventChannel(audioEventChannelName);
  const sttEventChannel = EventChannel(sttEventChannelName);

  late FakeSpeechRecognitionService fakeSpeech;
  late List<String> callLog;
  late List<String> diagnosticLogs;
  late Map<String, dynamic> mockCapabilityResponse;
  late bool mockStartNativeResult;

  Future<void> emitPlatformEvent(String channelName, Object? event) async {
    final encoded = const StandardMethodCodec().encodeSuccessEnvelope(event);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channelName, encoded, (_) {});
  }

  setUp(() {
    fakeSpeech = FakeSpeechRecognitionService();
    callLog = [];
    diagnosticLogs = [];
    mockStartNativeResult = true;
    mockCapabilityResponse = {
      'supported': true,
      'sdkInt': 35,
      'isRecognitionAvailable': true,
      'isOnDeviceAvailable': true,
      'recognitionServicePackage': 'com.google.android.tts',
      'supportsAudioSourceApi': true,
      'localeSupported': true,
      'segmentedSessionCandidate': true,
      'checkSupportStatus': 'supported',
    };

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      callLog.add('native:${call.method}');
      switch (call.method) {
        case 'checkCapability':
          return mockCapabilityResponse;
        case 'startNativeHybrid':
          return mockStartNativeResult;
        case 'rearmStt':
          return true;
        case 'setMuted':
          return true;
        case 'stopAll':
          return true;
        case 'getDiagnostics':
          return {'state': 'NATIVE_HYBRID_ACTIVE'};
        default:
          return null;
      }
    });

    // Mock EventChannel listen/cancel handlers
    messenger.setMockMethodCallHandler(
      const MethodChannel(audioEventChannelName),
      (MethodCall call) async {
        callLog.add('audio_stream:${call.method}');
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(sttEventChannelName),
      (MethodCall call) async {
        callLog.add('stt_events:${call.method}');
        return null;
      },
    );
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMethodCallHandler(const MethodChannel(audioEventChannelName), null);
    messenger.setMockMethodCallHandler(const MethodChannel(sttEventChannelName), null);
  });

  test('Non-Android auto mode uses stt_only fallback and forwards streams', () async {
    final service = SingleAudioCaptureService(
      fallbackSpeechService: fakeSpeech,
      configResolver: const AudioPipelineConfigResolver(rawOverride: 'auto', isReleaseMode: false),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: false,
      diagnosticLogger: diagnosticLogs.add,
    );

    final ok = await service.initialize();
    expect(ok, isTrue);
    expect(service.effectiveMode, EffectiveAudioPipelineMode.sttOnly);
    expect(service.fallbackReason, FallbackReason.platformUnsupported);
    expect(service.isRawAudioStreamSupported, isFalse);
    expect(callLog, isEmpty);

    await service.startListening(sttSessionId: 42);
    expect(fakeSpeech.isListening, isTrue);
    expect(fakeSpeech.activeSessionId, 42);

    String? receivedPartial;
    service.partialStream.listen((res) => receivedPartial = res.text);
    fakeSpeech.partialController.add(const SttPartialResult(
      text: 'halo eva',
      sttSessionId: 42,
      sequence: 1,
    ));
    await pumpEventQueue();
    expect(receivedPartial, 'halo eva');

    // Diagnostics must expose mode & capability without transcript content
    expect(diagnosticLogs.any((l) => l.contains('selectedMode=auto') && l.contains('effectiveMode=stt_only')), isTrue);
    expect(diagnosticLogs.any((l) => l.contains('halo eva')), isFalse);

    await service.stopListening();
    expect(fakeSpeech.isListening, isFalse);
    service.dispose();
  });

  test('Android API 33+ auto mode activates native_hybrid with single mic ownership and PCM fan-out', () async {
    final service = SingleAudioCaptureService(
      fallbackSpeechService: fakeSpeech,
      configResolver: const AudioPipelineConfigResolver(rawOverride: 'auto', isReleaseMode: false),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: true,
      diagnosticLogger: diagnosticLogs.add,
    );

    final ok = await service.initialize();
    expect(ok, isTrue);
    expect(service.effectiveMode, EffectiveAudioPipelineMode.nativeHybrid);
    expect(service.isRawAudioStreamSupported, isTrue);
    expect(callLog, contains('native:checkCapability'));

    await service.startListening(sttSessionId: 11);
    expect(callLog, contains('native:startNativeHybrid'));
    // Mutual exclusion invariant: speech_to_text must NOT be started while native owns mic
    expect(fakeSpeech.isListening, isFalse);

    final pcmChunks = <Uint8List>[];
    final partials = <SttPartialResult>[];
    service.audioStream.listen(pcmChunks.add);
    service.partialStream.listen(partials.add);

    await emitPlatformEvent(audioEventChannelName, Uint8List(4800));
    await emitPlatformEvent(sttEventChannelName, {
      'type': 'partial',
      'sttSessionId': 11,
      'generationId': 1,
      'sequence': 1,
      'text': 'aku merasa cukup tenang',
    });
    await pumpEventQueue();

    expect(pcmChunks.length, 1);
    expect(pcmChunks.first.length, 4800);
    expect(partials.length, 1);
    expect(partials.first.text, 'aku merasa cukup tenang');

    // Keep capture warm uses rearmStt instead of stop/start
    await service.startListening(sttSessionId: 12, keepCaptureWarm: true);
    expect(callLog, contains('native:rearmStt'));

    // Mute/unmute calls native setMuted without double-stop
    await service.setMuted(true);
    expect(service.isMuted, isTrue);
    expect(callLog, contains('native:setMuted'));

    service.dispose();
  });

  test('Android auto mode enforces Mic-Release Barrier (stopAll) BEFORE starting stt_only fallback', () async {
    final trackedSpeech = _TrackingFallbackSpeechService(callLog);
    final service = SingleAudioCaptureService(
      fallbackSpeechService: trackedSpeech,
      configResolver: const AudioPipelineConfigResolver(rawOverride: 'auto', isReleaseMode: false),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: true,
      diagnosticLogger: diagnosticLogs.add,
    );

    await service.initialize();
    await service.startListening(sttSessionId: 77);
    expect(service.effectiveMode, EffectiveAudioPipelineMode.nativeHybrid);
    expect(trackedSpeech.isListening, isFalse);

    // Native emits runtime probe failure -> fallback_required
    await emitPlatformEvent(sttEventChannelName, {
      'type': 'fallback_required',
      'sttSessionId': 77,
      'generationId': 2,
      'reason': 'mic_silenced_by_recognizer',
    });
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.effectiveMode, EffectiveAudioPipelineMode.sttOnly);
    expect(service.fallbackReason, FallbackReason.micSilencedByRecognizer);
    expect(service.isRawAudioStreamSupported, isFalse);
    expect(trackedSpeech.isListening, isTrue);

    final stopAllIdx = callLog.indexOf('native:stopAll');
    final fallbackStartIdx = callLog.indexOf('fallback:startListening');
    expect(stopAllIdx, greaterThanOrEqualTo(0));
    expect(fallbackStartIdx, greaterThan(stopAllIdx));

    service.dispose();
  });

  test('Forced native_hybrid override NEVER performs silent fallback on capability or runtime failure', () async {
    // 1. Capability unavailable case
    mockCapabilityResponse['supportsAudioSourceApi'] = false;
    final errors = <String>[];
    final service = SingleAudioCaptureService(
      fallbackSpeechService: fakeSpeech,
      configResolver: const AudioPipelineConfigResolver(
        rawOverride: 'native_hybrid',
        isReleaseMode: false,
      ),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: true,
      diagnosticLogger: diagnosticLogs.add,
    );
    service.errorStream.listen(errors.add);

    final initOk = await service.initialize();
    await pumpEventQueue();

    expect(initOk, isFalse);
    expect(service.effectiveMode, EffectiveAudioPipelineMode.failed);
    expect(fakeSpeech.isListening, isFalse);
    expect(errors.any((e) => e.contains('native_hybrid_forced_unavailable')), isTrue);
    service.dispose();

    // 2. Runtime probe failure case
    mockCapabilityResponse['supportsAudioSourceApi'] = true;
    final runtimeErrors = <String>[];
    final service2 = SingleAudioCaptureService(
      fallbackSpeechService: fakeSpeech,
      configResolver: const AudioPipelineConfigResolver(
        rawOverride: 'native_hybrid',
        isReleaseMode: false,
      ),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: true,
      diagnosticLogger: diagnosticLogs.add,
    );
    service2.errorStream.listen(runtimeErrors.add);

    expect(await service2.initialize(), isTrue);
    await service2.startListening(sttSessionId: 5);

    await emitPlatformEvent(sttEventChannelName, {
      'type': 'native_hybrid_failed',
      'sttSessionId': 5,
      'generationId': 2,
      'reason': 'ready_for_speech_timeout',
    });
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service2.effectiveMode, EffectiveAudioPipelineMode.failed);
    expect(fakeSpeech.isListening, isFalse);
    expect(runtimeErrors.any((e) => e.contains('native_hybrid_failed')), isTrue);
    service2.dispose();
  });

  test('Forced stt_only override completely disables native PCM capture and emotion streaming', () async {
    final service = SingleAudioCaptureService(
      fallbackSpeechService: fakeSpeech,
      configResolver: const AudioPipelineConfigResolver(
        rawOverride: 'stt_only',
        isReleaseMode: false,
      ),
      methodChannel: methodChannel,
      audioStreamChannel: audioEventChannel,
      sttEventsChannel: sttEventChannel,
      isAndroidOverride: true,
      diagnosticLogger: diagnosticLogs.add,
    );

    final pcmChunks = <Uint8List>[];
    service.audioStream.listen(pcmChunks.add);

    expect(await service.initialize(), isTrue);
    expect(service.selectedMode, AudioPipelineModeConfig.sttOnly);
    expect(service.effectiveMode, EffectiveAudioPipelineMode.sttOnly);
    expect(service.isRawAudioStreamSupported, isFalse);

    await service.startListening(sttSessionId: 99);
    expect(fakeSpeech.isListening, isTrue);

    // Zero native method or audio stream channel invocations allowed in stt_only mode
    expect(callLog.where((e) => e.startsWith('native:')), isEmpty);
    expect(callLog.where((e) => e.startsWith('audio_stream:')), isEmpty);
    expect(pcmChunks, isEmpty);

    await service.setMuted(true);
    expect(service.isMuted, isTrue);
    expect(fakeSpeech.isMuted, isTrue);

    service.dispose();
  });
}

class _TrackingFallbackSpeechService extends FakeSpeechRecognitionService {
  final List<String> log;
  _TrackingFallbackSpeechService(this.log);

  @override
  Future<void> startListening({required int sttSessionId}) async {
    log.add('fallback:startListening');
    await super.startListening(sttSessionId: sttSessionId);
  }
}

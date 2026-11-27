import 'package:eva_mobile/features/voice_call/data/services/single_audio_capture_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('test.eva.single_audio/methods');
  const audioStreamChannel = EventChannel('test.eva.single_audio/audio_stream');
  const audioEventsChannel = EventChannel('test.eva.single_audio/audio_events');

  late List<MethodCall> methodCalls;
  late SingleAudioCaptureService service;

  setUp(() {
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      methodCalls.add(call);
      if (call.method == 'startCapture') return true;
      if (call.method == 'stopCapture') return true;
      if (call.method == 'setMuted') return true;
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      audioStreamChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      audioEventsChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );

    service = SingleAudioCaptureService(
      methodChannel: methodChannel,
      audioStreamChannel: audioStreamChannel,
      audioEventsChannel: audioEventsChannel,
      isAndroidPlatform: () => true,
      permissionRequester: () async => true,
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(audioStreamChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(audioEventsChannel, null);
  });

  test('initializes, starts/stops idempotently, and handles mute', () async {
    expect(service.isRawAudioStreamSupported, isTrue);

    final initOk = await service.initialize();
    expect(initOk, isTrue);
    expect(service.isInitialized, isTrue);

    final started1 = await service.startCapture();
    final started2 = await service.startCapture();
    expect(started1, isTrue);
    expect(started2, isTrue);
    expect(service.isCapturing, isTrue);
    expect(methodCalls.where((c) => c.method == 'startCapture').length, 1);

    await service.setMuted(true);
    expect(service.isMuted, isTrue);
    expect(service.isCapturing, isFalse);
    expect(methodCalls.any((c) => c.method == 'setMuted' && c.arguments['muted'] == true), isTrue);
    expect(methodCalls.where((c) => c.method == 'stopCapture').length, 1);

    // Calling startCapture while muted must no-op
    expect(await service.startCapture(), isFalse);

    await service.setMuted(false);
    expect(service.isMuted, isFalse);
    expect(await service.startCapture(), isTrue);

    await service.stopCapture();
    await service.stopCapture();
    expect(service.isCapturing, isFalse);
    expect(methodCalls.where((c) => c.method == 'stopCapture').length, 2);
  });

  test('forwards PCM audio chunks and RMS sound level events while capturing', () async {
    late MockStreamHandlerEventSink audioSink;
    late MockStreamHandlerEventSink metaSink;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      audioStreamChannel,
      MockStreamHandler.inline(onListen: (_, sink) => audioSink = sink),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      audioEventsChannel,
      MockStreamHandler.inline(onListen: (_, sink) => metaSink = sink),
    );

    final receivedChunks = <Uint8List>[];
    final receivedLevels = <double>[];
    final receivedErrors = <String>[];

    service.audioStream.listen(receivedChunks.add);
    service.soundLevelStream.listen(receivedLevels.add);
    service.errorStream.listen(receivedErrors.add);

    await service.startCapture();

    final pcmFrame = Uint8List.fromList(List<int>.filled(4800, 7));
    audioSink.success(pcmFrame);
    metaSink.success({'type': 'sound_level', 'level': 0.42});
    metaSink.success({'type': 'error', 'error': 'audio_hw_busy'});

    await pumpEventQueue();

    expect(receivedChunks.length, 1);
    expect(receivedChunks.first.length, 4800);
    expect(receivedLevels, [0.42]);
    expect(receivedErrors, ['audio_hw_busy']);
  });
}

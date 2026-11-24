import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/voice_call/data/services/single_audio_capture_service.dart';
import 'package:eva_mobile/features/voice_call/data/services/speech_recognition_service.dart';

import 'ai_call_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpeechRecognitionService fakeSpeech;
  late SingleAudioCaptureService service;

  setUp(() {
    fakeSpeech = FakeSpeechRecognitionService();
    service = SingleAudioCaptureService(fallbackSpeechService: fakeSpeech);
  });

  tearDown(() {
    service.dispose();
  });

  test('SingleAudioCaptureService initializes and forwards fallback streams', () async {
    final ok = await service.initialize();
    expect(ok, isTrue);
    expect(service.isInitialized, isTrue);

    // Expect fallback mode on non-Android test runner
    expect(service.isInjectionSupported, isFalse);

    // Test startListening triggers fallback
    await service.startListening(sttSessionId: 42);
    expect(fakeSpeech.isListening, isTrue);
    expect(fakeSpeech.activeSessionId, 42);

    // Test stream forwarding
    String? receivedPartial;
    service.partialStream.listen((res) {
      receivedPartial = res.text;
    });

    fakeSpeech.partialController.add(const SttPartialResult(
      text: 'halo eva',
      sttSessionId: 42,
      sequence: 1,
    ));

    await pumpEventQueue();
    expect(receivedPartial, 'halo eva');

    // Test stopListening
    await service.stopListening();
    expect(fakeSpeech.isListening, isFalse);
  });

  test('SingleAudioCaptureService handles mute correctly', () async {
    await service.initialize();
    await service.startListening(sttSessionId: 10);
    expect(service.isMuted, isFalse);

    service.setMuted(true);
    expect(service.isMuted, isTrue);
    expect(fakeSpeech.isMuted, isTrue);
  });
}

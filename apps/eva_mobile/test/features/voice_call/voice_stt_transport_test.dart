import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/voice_call/data/services/voice_stt_transport.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/audio_pipeline_mode.dart';

/// Reusable lifecycle contract suite that any future VoiceSttTransport provider must pass.
void runVoiceSttTransportContractTests(
  String name,
  VoiceSttTransport Function() createTransport,
) {
  group('VoiceSttTransport Contract ($name)', () {
    late VoiceSttTransport transport;

    setUp(() {
      transport = createTransport();
    });

    tearDown(() async {
      await transport.dispose();
    });

    test('initialize returns explicit availability and is idempotent', () async {
      final first = await transport.initialize();
      final second = await transport.initialize();

      expect(transport.providerId, isNotEmpty);
      expect(transport.isInitialized, isTrue);
      expect(first, transport.availability);
      expect(second, first);
    });

    test('audio ingestion, stop, cancel, and double dispose never throw unhandled exceptions', () async {
      await transport.initialize();
      await transport.start(sttSessionId: 1, generationId: 1, locale: 'id-ID');

      final frame = AudioPcmFrame(
        bytes: Uint8List(4800),
        sessionId: 1,
        generationId: 1,
        sequence: 1,
        timestampMs: 1000,
      );
      await transport.ingestAudioFrame(frame);
      await transport.stop();
      await transport.cancel();

      await transport.dispose();
      // Idempotent second dispose
      await transport.dispose();
    });
  });
}

void main() {
  runVoiceSttTransportContractTests(
    'UnconfiguredRemoteHybridSttTransport',
    () => UnconfiguredRemoteHybridSttTransport(),
  );

  group('UnconfiguredRemoteHybridSttTransport unit behavior', () {
    late UnconfiguredRemoteHybridSttTransport stub;

    setUp(() {
      stub = UnconfiguredRemoteHybridSttTransport();
    });

    tearDown(() async {
      await stub.dispose();
    });

    test('explicitly reports unavailable status and emits structured error on start', () async {
      final availability = await stub.initialize();
      expect(availability, VoiceSttTransportAvailability.unavailable);
      expect(stub.availability, VoiceSttTransportAvailability.unavailable);
      expect(stub.isActive, isFalse);

      final statuses = <String>[];
      final errors = <VoiceSttTransportError>[];
      stub.statusStream.listen((e) => statuses.add(e.status));
      stub.errorStream.listen(errors.add);

      await stub.start(sttSessionId: 7, generationId: 3, locale: 'id-ID');
      await pumpEventQueue();

      expect(statuses, ['unavailable']);
      expect(errors.length, 1);
      expect(errors.first.code, 'remote_stt_unavailable');
      expect(errors.first.isRecoverable, isFalse);
      expect(errors.first.sttSessionId, 7);
      expect(errors.first.generationId, 3);
    });

    test('safely drops ingested audio frames without throwing', () async {
      await stub.initialize();
      for (var i = 1; i <= 5; i++) {
        await stub.ingestAudioFrame(AudioPcmFrame(
          bytes: Uint8List(4800),
          sessionId: 1,
          generationId: 1,
          sequence: i,
          timestampMs: i * 150,
        ));
      }
      expect(stub.droppedFramesCount, 5);
    });
  });
}

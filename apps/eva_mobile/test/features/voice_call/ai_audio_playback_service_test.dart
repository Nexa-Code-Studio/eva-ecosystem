import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:eva_mobile/features/voice_call/config/call_config.dart';
import 'package:eva_mobile/features/voice_call/data/services/ai_audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioPlayer extends Fake implements AudioPlayer {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  final List<String> events = [];
  Completer<void>? stopCompleter;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    events.add('play');
  }

  @override
  Future<void> stop() async {
    events.add('stop_start');
    if (stopCompleter != null) {
      await stopCompleter!.future;
    }
    events.add('stop_end');
  }

  void emitComplete() {
    _completeController.add(null);
  }

  @override
  Future<void> dispose() async {
    await _completeController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepareNewAssistantTurn awaits stop before enqueueChunk plays audio', () async {
    final fakePlayer = _FakeAudioPlayer();
    fakePlayer.stopCompleter = Completer<void>();
    final service = AiAudioPlaybackService(player: fakePlayer);
    addTearDown(service.dispose);

    final prepFuture = service.prepareNewAssistantTurn(1);
    await pumpEventQueue();
    expect(fakePlayer.events, ['stop_start']);

    fakePlayer.stopCompleter!.complete();
    await prepFuture;
    service.enqueueChunk(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      assistantTurnId: 1,
      sequence: 1,
    );
    await pumpEventQueue();

    expect(fakePlayer.events, ['stop_start', 'stop_end', 'play']);
  });

  test('enqueueChunk during interChunkPauseMs does not double-play or skip pause', () async {
    final fakePlayer = _FakeAudioPlayer();
    final service = AiAudioPlaybackService(player: fakePlayer);
    addTearDown(service.dispose);

    await service.prepareNewAssistantTurn(1);
    service.enqueueChunk(
      bytes: Uint8List.fromList([1, 2, 3]),
      assistantTurnId: 1,
      sequence: 1,
    );
    service.enqueueChunk(
      bytes: Uint8List.fromList([4, 5, 6]),
      assistantTurnId: 1,
      sequence: 2,
    );
    await pumpEventQueue();

    expect(fakePlayer.events.where((e) => e == 'play').length, 1);

    // Chunk 1 finishes -> enters interChunkPauseMs (500ms)
    fakePlayer.emitComplete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Chunk 3 arrives mid-pause; must NOT start a second concurrent play
    service.enqueueChunk(
      bytes: Uint8List.fromList([7, 8, 9]),
      assistantTurnId: 1,
      sequence: 3,
    );
    service.markStreamFinished(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fakePlayer.events.where((e) => e == 'play').length, 1);

    // After interChunkPauseMs elapses, chunk 2 plays cleanly without premature completion
    await Future<void>.delayed(
      const Duration(milliseconds: CallConfig.interChunkPauseMs + 100),
    );
    expect(fakePlayer.events.where((e) => e == 'play').length, 2);
  });
}

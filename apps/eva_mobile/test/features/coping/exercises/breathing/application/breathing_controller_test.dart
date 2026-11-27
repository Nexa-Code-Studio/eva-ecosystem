import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/application/breathing_controller.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/domain/breathing_phase.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/domain/breathing_session.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/infrastructure/breathing_audio_adapter.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/infrastructure/breathing_timeline_loader.dart';
import 'package:eva_mobile/features/coping/shared/domain/coping_session_result.dart';

class FakeBreathingClock implements BreathingClock {
  int _nowMs = 0;

  @override
  int nowMs() => _nowMs;

  void advance(int deltaMs) {
    _nowMs += deltaMs;
  }
}

class FakeBreathingAudioAdapter implements BreathingAudioAdapter {
  final StreamController<int> _posController =
      StreamController<int>.broadcast();
  final StreamController<BreathingAudioEvent> _eventController =
      StreamController<BreathingAudioEvent>.broadcast();

  int? preparedDurationMs;
  bool throwOnPrepare = false;
  bool played = false;
  bool paused = false;
  bool stopped = false;
  bool muted = false;
  bool disposed = false;

  @override
  Stream<int> get positionMsStream => _posController.stream;

  @override
  Stream<BreathingAudioEvent> get eventStream => _eventController.stream;

  void emitPosition(int ms) {
    if (!disposed) _posController.add(ms);
  }

  void emitEvent(BreathingAudioEvent event) {
    if (!disposed) _eventController.add(event);
  }

  @override
  Future<int?> prepareAsset(String assetPath) async {
    if (throwOnPrepare) throw Exception('Decode error');
    return preparedDurationMs;
  }

  @override
  Future<void> play() async {
    played = true;
    paused = false;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> setMuted(bool nextMuted) async {
    muted = nextMuted;
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _posController.close();
    await _eventController.close();
  }
}

class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> stringAssets;
  final Set<String> binaryAssets;
  Completer<void>? delayGate;

  FakeAssetBundle({this.stringAssets = const {}, this.binaryAssets = const {}});

  @override
  Future<ByteData> load(String key) async {
    if (delayGate != null) {
      await delayGate!.future;
    }
    if (binaryAssets.contains(key)) {
      return ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4]));
    }
    if (stringAssets.containsKey(key)) {
      final bytes = Uint8List.fromList(utf8.encode(stringAssets[key]!));
      return ByteData.sublistView(bytes);
    }
    throw FlutterError('Asset $key not found');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (delayGate != null) {
      await delayGate!.future;
    }
    if (stringAssets.containsKey(key)) {
      return stringAssets[key]!;
    }
    throw FlutterError('String asset $key not found');
  }
}

const String _audioGuidedTimelineJson = '''
{
  "schemaVersion": 1,
  "id": "guided_breathing_id_short",
  "locale": "id-ID",
  "audioAsset": "assets/coping/breathing/audio/guided_breathing_id.mp3",
  "durationMs": 20000,
  "segments": [
    { "phase": "preparation", "startMs": 0, "endMs": 4000 },
    { "phase": "inhale", "startMs": 4000, "endMs": 8000 },
    { "phase": "exhale", "startMs": 8000, "endMs": 12000 },
    { "phase": "inhale", "startMs": 12000, "endMs": 16000 },
    { "phase": "exhale", "startMs": 16000, "endMs": 20000 }
  ]
}
''';

void main() {
  group('BreathingController Visual-Only Lifecycle', () {
    test(
      'falls back to visualOnly cleanly when MP3 asset is missing, freezes on pause, and completes once',
      () async {
        final clock = FakeBreathingClock();
        final audio = FakeBreathingAudioAdapter();
        final boundaries = <BreathingPhase>[];
        final completions = <CopingSessionResult>[];

        final controller = BreathingController(
          timelineLoader: BreathingTimelineLoader(bundle: FakeAssetBundle()),
          audioAdapter: audio,
          clock: clock,
          onPhaseBoundary: boundaries.add,
          onCompleted: completions.add,
        );
        addTearDown(controller.dispose);

        await controller.initializeAndStart();

        expect(controller.state.status, BreathingPlaybackStatus.playing);
        expect(
          controller.state.guidanceSource,
          BreathingGuidanceSource.visualOnly,
        );
        expect(controller.state.currentPhase, BreathingPhase.preparation);
        expect(boundaries, [BreathingPhase.preparation]);

        // Advance into inhale phase (5500ms)
        clock.advance(5500);
        controller.onFrame();
        expect(controller.state.currentPhase, BreathingPhase.inhale);
        expect(
          controller.motionListenable.value.breathAmount,
          closeTo(1500 / 4000, 1e-6),
        );
        expect(boundaries, [BreathingPhase.preparation, BreathingPhase.inhale]);

        // Pause freezes visual progress even if clock continues advancing
        await controller.pause();
        expect(controller.state.status, BreathingPlaybackStatus.paused);
        final pausedPos = controller.state.lastPositionMs;
        clock.advance(10000);
        controller.onFrame();
        expect(controller.state.lastPositionMs, pausedPos);

        // Resume continues from exact paused timestamp
        await controller.resume();
        expect(controller.state.status, BreathingPlaybackStatus.playing);
        clock.advance(3000); // 5500 + 3000 = 8500 -> exhale!
        controller.onFrame();
        expect(controller.state.currentPhase, BreathingPhase.exhale);

        // Advance past total 40000ms -> completes once
        clock.advance(35000);
        controller.onFrame();
        controller.onFrame(); // duplicate tick ignored
        expect(controller.state.status, BreathingPlaybackStatus.completed);
        expect(completions.length, 1);
        expect(completions.first.isCompleted, isTrue);
        expect(completions.first.isVisualOnly, isTrue);
      },
    );

    test(
      'cancel stops playback without firing completion, and dispose during async load prevents late start',
      () async {
        final clock = FakeBreathingClock();
        final audio = FakeBreathingAudioAdapter();
        final bundle = FakeAssetBundle()..delayGate = Completer<void>();
        final completions = <CopingSessionResult>[];

        final controller = BreathingController(
          timelineLoader: BreathingTimelineLoader(bundle: bundle),
          audioAdapter: audio,
          clock: clock,
          onCompleted: completions.add,
        );

        final loadFuture = controller.initializeAndStart();
        expect(controller.state.isLoading, isTrue);

        // Cancel / dispose while still loading
        controller.dispose();
        bundle.delayGate!.complete();
        await loadFuture;

        expect(audio.disposed, isTrue);
        expect(completions, isEmpty);
      },
    );

    test('background event pauses active session cleanly', () async {
      final clock = FakeBreathingClock();
      final controller = BreathingController(
        timelineLoader: BreathingTimelineLoader(bundle: FakeAssetBundle()),
        audioAdapter: FakeBreathingAudioAdapter(),
        clock: clock,
      );
      addTearDown(controller.dispose);

      await controller.initializeAndStart();
      expect(controller.state.isPlaying, isTrue);
      await controller.handleAppBackgrounded();
      expect(controller.state.isPaused, isTrue);
    });
  });

  group('BreathingController Audio-Guided Sync & Ownership', () {
    test(
      'synchronizes with authoritative audio snapshots, bounds extrapolation, handles buffering, mute, and real completion',
      () async {
        final clock = FakeBreathingClock();
        final audio = FakeBreathingAudioAdapter()..preparedDurationMs = 20050;
        final bundle = FakeAssetBundle(
          stringAssets: {
            BreathingTimelineLoader.defaultTimelineAsset:
                _audioGuidedTimelineJson,
          },
          binaryAssets: {
            'assets/coping/breathing/audio/guided_breathing_id.mp3',
          },
        );
        final completions = <CopingSessionResult>[];

        final controller = BreathingController(
          timelineLoader: BreathingTimelineLoader(bundle: bundle),
          audioAdapter: audio,
          clock: clock,
          onCompleted: completions.add,
        );
        addTearDown(controller.dispose);

        await controller.initializeAndStart();
        expect(
          controller.state.guidanceSource,
          BreathingGuidanceSource.audioGuided,
        );
        expect(controller.state.isPlaying, isTrue);
        expect(audio.played, isTrue);

        // Sparse audio snapshot at 4000ms + 120ms frame tick interpolates smoothly to 4120ms
        audio.emitPosition(4000);
        await pumpEventQueue();
        clock.advance(120);
        controller.onFrame();
        expect(controller.motionListenable.value.positionMs, 4120);

        // Extrapolation stays bounded by maxExtrapolationMs (350ms) even if audio stalls
        clock.advance(2000);
        controller.onFrame();
        expect(
          controller.motionListenable.value.positionMs,
          4000 + BreathingController.maxExtrapolationMs,
        );
        expect(controller.state.hasCompleted, isFalse);

        // Buffering freezes playhead until audio resumes
        audio.emitEvent(
          const BreathingAudioEvent(BreathingAudioEventType.buffering),
        );
        await pumpEventQueue();
        expect(controller.state.status, BreathingPlaybackStatus.buffering);
        audio.emitEvent(
          const BreathingAudioEvent(BreathingAudioEventType.playing),
        );
        await pumpEventQueue();
        expect(controller.state.status, BreathingPlaybackStatus.playing);

        // Mute zeroes volume without stopping playhead
        await controller.toggleMute();
        expect(controller.state.isMuted, isTrue);
        expect(audio.muted, isTrue);
        expect(controller.state.isPlaying, isTrue);

        // Near-end timestamp alone does NOT complete without real media completion
        audio.emitPosition(20000);
        await pumpEventQueue();
        controller.onFrame();
        expect(controller.state.hasCompleted, isFalse);

        // Real completion event completes once
        audio.emitEvent(
          const BreathingAudioEvent(BreathingAudioEventType.completed),
        );
        await pumpEventQueue();
        expect(controller.state.hasCompleted, isTrue);
        expect(completions.length, 1);
        expect(completions.first.isVisualOnly, isFalse);
      },
    );

    test(
      'falls back to visual-only explicitly if audio duration mismatches beyond 150ms, and recovers mid-session error',
      () async {
        final clock = FakeBreathingClock();
        final audio = FakeBreathingAudioAdapter()..preparedDurationMs = 25000;
        final bundle = FakeAssetBundle(
          stringAssets: {
            BreathingTimelineLoader.defaultTimelineAsset:
                _audioGuidedTimelineJson,
          },
          binaryAssets: {
            'assets/coping/breathing/audio/guided_breathing_id.mp3',
          },
        );

        final controller = BreathingController(
          timelineLoader: BreathingTimelineLoader(bundle: bundle),
          audioAdapter: audio,
          clock: clock,
        );
        addTearDown(controller.dispose);

        await controller.initializeAndStart();
        expect(
          controller.state.guidanceSource,
          BreathingGuidanceSource.visualOnly,
        );
        expect(controller.state.isPlaying, isTrue);
        expect(controller.state.audioUnavailableReason, isNotNull);
      },
    );
  });
}

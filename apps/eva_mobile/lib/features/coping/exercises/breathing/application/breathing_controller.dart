import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/coping_exercise_id.dart';
import '../../../shared/domain/coping_session_result.dart';
import '../domain/breathing_phase.dart';
import '../domain/breathing_session.dart';
import '../domain/breathing_timeline.dart';
import '../infrastructure/breathing_audio_adapter.dart';
import '../infrastructure/breathing_timeline_loader.dart';
import 'breathing_state.dart';

/// Monotonic millisecond clock interface for deterministic tests.
abstract class BreathingClock {
  int nowMs();
}

class StopwatchBreathingClock implements BreathingClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  int nowMs() => _stopwatch.elapsedMilliseconds;
}

typedef BreathingPhaseBoundaryCallback = void Function(BreathingPhase phase);
typedef BreathingCompletionCallback = void Function(CopingSessionResult result);

/// Authoritative coordinator for guided breathing playhead, audio synchronization,
/// frame-rate visual state, pause/resume lifecycle, and completion guarantees.
class BreathingController extends StateNotifier<BreathingState> {
  static const int maxExtrapolationMs = 350;
  static const int seekDiscontinuityThresholdMs = 180;

  final BreathingTimelineLoader _timelineLoader;
  final BreathingAudioAdapter _audioAdapter;
  final BreathingClock _clock;
  final BreathingPhaseBoundaryCallback? _onPhaseBoundary;
  final BreathingCompletionCallback? _onCompleted;

  final ValueNotifier<BreathingMotionFrame> _motionNotifier =
      ValueNotifier<BreathingMotionFrame>(BreathingMotionFrame.initial);

  ValueListenable<BreathingMotionFrame> get motionListenable => _motionNotifier;

  BreathingTimeline _timeline = BreathingTimeline.defaultGuidedId();
  BreathingTimeline get timeline => _timeline;

  Ticker? _ticker;
  StreamSubscription<int>? _positionSub;
  StreamSubscription<BreathingAudioEvent>? _eventSub;

  int _loadGeneration = 0;
  int _lastNotifiedSegmentIndex = -1;
  bool _audioPrepared = false;
  bool _disposed = false;

  // Visual-only monotonic playhead state.
  int _visualAccumulatedMs = 0;
  int? _visualSegmentStartedAtClockMs;

  // Audio-guided anchored playhead state.
  int _audioAnchorPositionMs = 0;
  int _audioAnchorClockMs = 0;
  int _lastRenderedPositionMs = 0;

  BreathingController({
    required BreathingTimelineLoader timelineLoader,
    required BreathingAudioAdapter audioAdapter,
    BreathingClock? clock,
    BreathingPhaseBoundaryCallback? onPhaseBoundary,
    BreathingCompletionCallback? onCompleted,
  }) : _timelineLoader = timelineLoader,
       _audioAdapter = audioAdapter,
       _clock = clock ?? StopwatchBreathingClock(),
       _onPhaseBoundary = onPhaseBoundary,
       _onCompleted = onCompleted,
       super(const BreathingState());

  void attachTickerProvider(TickerProvider vsync) {
    if (_disposed) return;
    _ticker?.dispose();
    _ticker = vsync.createTicker((_) => onFrame());
    if (state.isPlaying) {
      _startTickerIfIdle();
    }
  }

  /// Detaches and disposes the page-owned ticker before State.dispose runs.
  void detachTickerProvider() {
    _stopTicker();
    _ticker?.dispose();
    _ticker = null;
  }

  void setReducedMotion(bool enabled) {
    if (_disposed || state.reducedMotion == enabled) return;
    state = state.copyWith(reducedMotion: enabled);
  }

  /// Loads timeline & optional audio asset, transitioning `idle -> loading -> playing`.
  Future<void> initializeAndStart({
    String timelineAsset = BreathingTimelineLoader.defaultTimelineAsset,
    bool forceVisualOnly = false,
  }) async {
    if (_disposed) return;
    final gen = ++_loadGeneration;
    _stopTicker();

    _visualAccumulatedMs = 0;
    _visualSegmentStartedAtClockMs = null;
    _audioAnchorPositionMs = 0;
    _audioAnchorClockMs = _clock.nowMs();
    _lastRenderedPositionMs = 0;
    _lastNotifiedSegmentIndex = -1;

    state = state.copyWith(
      status: BreathingPlaybackStatus.loading,
      completionEmitted: false,
      clearErrorMessage: true,
      clearAudioUnavailableReason: true,
    );

    await _cancelAudioSubscriptions();
    if (_disposed || gen != _loadGeneration) return;

    try {
      final loaded = await _timelineLoader.loadProgram(
        timelineAsset: timelineAsset,
        forceVisualOnly: forceVisualOnly,
      );
      if (_disposed || gen != _loadGeneration) return;

      _timeline = loaded.timeline;
      var effectiveSource = loaded.source;
      var unavailableReason = loaded.audioUnavailableReason;

      if (effectiveSource == BreathingGuidanceSource.audioGuided &&
          _timeline.audioAsset != null) {
        _audioPrepared = true;
        try {
          final measuredMs = await _audioAdapter.prepareAsset(
            _timeline.audioAsset!,
          );
          if (_disposed || gen != _loadGeneration) return;

          if (measuredMs != null && measuredMs > 0) {
            _timeline.assertCompatibleWithAudioDuration(measuredMs);
          }

          _bindAudioStreams(gen);
        } catch (e) {
          if (_disposed || gen != _loadGeneration) return;
          // Media load / duration validation failed -> safe explicit visual fallback.
          await _audioAdapter.stop();
          effectiveSource = BreathingGuidanceSource.visualOnly;
          unavailableReason =
              'Narasi audio gagal dimuat (${e is BreathingTimelineException ? e.message : 'kesalahan media'}); beralih ke mode visual.';
        }
      }

      if (_disposed || gen != _loadGeneration) return;

      final initialSnapshot = _timeline.resolvePosition(0);
      _publishFrame(initialSnapshot, notifyBoundary: false);

      state = state.copyWith(
        status: BreathingPlaybackStatus.ready,
        guidanceSource: effectiveSource,
        durationMs: _timeline.durationMs,
        currentPhase: initialSnapshot.phase,
        phaseRemainingSeconds: initialSnapshot.phaseRemainingSeconds,
        lastPositionMs: 0,
        audioUnavailableReason: unavailableReason,
        clearAudioUnavailableReason: unavailableReason == null,
      );

      await _beginPlayback(gen);
    } catch (e) {
      if (_disposed || gen != _loadGeneration) return;
      state = state.copyWith(
        status: BreathingPlaybackStatus.error,
        errorMessage: 'Gagal menyiapkan latihan pernapasan: $e',
      );
    }
  }

  Future<void> _beginPlayback(int gen) async {
    if (_disposed || gen != _loadGeneration) return;
    if (state.hasCompleted) return;

    final now = _clock.nowMs();
    if (state.isAudioGuided) {
      _audioAnchorClockMs = now;
      await _audioAdapter.setMuted(state.isMuted);
      if (_disposed || gen != _loadGeneration) return;
      try {
        await _audioAdapter.play();
      } catch (e) {
        if (_disposed || gen != _loadGeneration) return;
        state = state.copyWith(
          status: BreathingPlaybackStatus.error,
          errorMessage: 'Pemutaran audio terganggu: $e',
        );
        return;
      }
      if (_disposed || gen != _loadGeneration) return;
    } else {
      _visualSegmentStartedAtClockMs = now;
    }

    state = state.copyWith(
      status: BreathingPlaybackStatus.playing,
      clearErrorMessage: true,
    );
    _lastNotifiedSegmentIndex = _timeline
        .resolvePosition(_lastRenderedPositionMs)
        .segmentIndex;
    _onPhaseBoundary?.call(state.currentPhase);
    _startTickerIfIdle();
  }

  void _bindAudioStreams(int gen) {
    _positionSub = _audioAdapter.positionMsStream.listen((playerMs) {
      if (_disposed || gen != _loadGeneration) return;
      _handleAudioPositionSnapshot(playerMs);
    });

    _eventSub = _audioAdapter.eventStream.listen((event) {
      if (_disposed || gen != _loadGeneration) return;
      _handleAudioEvent(event, gen);
    });
  }

  void _handleAudioPositionSnapshot(int rawPlayerMs) {
    final clampedMs = rawPlayerMs.clamp(0, _timeline.durationMs);
    final now = _clock.nowMs();

    final drift = (clampedMs - _lastRenderedPositionMs).abs();
    if (drift >= seekDiscontinuityThresholdMs ||
        state.status == BreathingPlaybackStatus.paused ||
        state.status == BreathingPlaybackStatus.buffering) {
      _lastRenderedPositionMs = clampedMs;
    }

    _audioAnchorPositionMs = clampedMs;
    _audioAnchorClockMs = now;

    if (state.isPlaying) {
      final snapshot = _timeline.resolvePosition(clampedMs);
      _publishFrame(snapshot, notifyBoundary: true);
    }
  }

  void _handleAudioEvent(BreathingAudioEvent event, int gen) {
    if (_disposed || gen != _loadGeneration) return;
    switch (event.type) {
      case BreathingAudioEventType.buffering:
        if (state.isPlaying) {
          _freezeAudioAnchor();
          _stopTicker();
          state = state.copyWith(status: BreathingPlaybackStatus.buffering);
        }
        break;
      case BreathingAudioEventType.playing:
        if (state.isBuffering) {
          _audioAnchorClockMs = _clock.nowMs();
          state = state.copyWith(status: BreathingPlaybackStatus.playing);
          _startTickerIfIdle();
        }
        break;
      case BreathingAudioEventType.paused:
      case BreathingAudioEventType.interrupted:
        if (state.isPlaying || state.isBuffering) {
          pause();
        }
        break;
      case BreathingAudioEventType.completed:
        if (state.isPlaying || state.isBuffering) {
          _completeSession();
        }
        break;
      case BreathingAudioEventType.error:
        _freezeAudioAnchor();
        _stopTicker();
        state = state.copyWith(
          status: BreathingPlaybackStatus.error,
          errorMessage: event.message ?? 'Audio narasi terganggu.',
        );
        break;
      case BreathingAudioEventType.ready:
        break;
    }
  }

  void _freezeAudioAnchor() {
    _audioAnchorPositionMs = _currentAudioExtrapolatedMs();
    _audioAnchorClockMs = _clock.nowMs();
    _lastRenderedPositionMs = _audioAnchorPositionMs;
  }

  int _currentAudioExtrapolatedMs() {
    if (!state.isPlaying) return _audioAnchorPositionMs;
    final elapsedSinceAnchor = math.max(
      0,
      _clock.nowMs() - _audioAnchorClockMs,
    );
    final boundedElapsed = math.min(elapsedSinceAnchor, maxExtrapolationMs);
    final candidate = math.min(
      _timeline.durationMs,
      _audioAnchorPositionMs + boundedElapsed,
    );
    return math.max(_lastRenderedPositionMs, candidate);
  }

  /// Frame tick driven by [Ticker] or deterministic unit tests.
  void onFrame() {
    if (_disposed || !state.isPlaying) return;

    final int posMs;
    if (state.isAudioGuided) {
      posMs = _currentAudioExtrapolatedMs();
      _lastRenderedPositionMs = posMs;
      // Never mark complete solely from extrapolation in audio-guided mode;
      // wait for actual media completion or near-end snapshot.
      final cappedPosMs = math.min(
        posMs,
        math.max(0, _timeline.durationMs - 1),
      );
      final snapshot = _timeline.resolvePosition(cappedPosMs);
      _publishFrame(snapshot, notifyBoundary: true);
      return;
    }

    final startClock = _visualSegmentStartedAtClockMs ?? _clock.nowMs();
    posMs = _visualAccumulatedMs + math.max(0, _clock.nowMs() - startClock);
    _lastRenderedPositionMs = posMs.clamp(0, _timeline.durationMs);

    if (posMs >= _timeline.durationMs) {
      _completeSession();
      return;
    }

    final snapshot = _timeline.resolvePosition(posMs);
    _publishFrame(snapshot, notifyBoundary: true);
  }

  void _publishFrame(
    BreathingFrameSnapshot snapshot, {
    required bool notifyBoundary,
  }) {
    _motionNotifier.value = BreathingMotionFrame(
      phase: snapshot.phase,
      phaseProgress: snapshot.phaseProgress,
      breathAmount: snapshot.breathAmount,
      lungScale: BreathingMotionMapper.lungScale(snapshot.breathAmount),
      glowIntensity: BreathingMotionMapper.glowIntensity(snapshot.breathAmount),
      sessionProgress: snapshot.sessionProgress,
      positionMs: snapshot.positionMs,
      phaseRemainingSeconds: snapshot.phaseRemainingSeconds,
    );

    final phaseChanged = _lastNotifiedSegmentIndex != snapshot.segmentIndex;
    final secondsChanged =
        state.phaseRemainingSeconds != snapshot.phaseRemainingSeconds;

    if (phaseChanged ||
        secondsChanged ||
        state.currentPhase != snapshot.phase) {
      state = state.copyWith(
        currentPhase: snapshot.phase,
        phaseRemainingSeconds: snapshot.phaseRemainingSeconds,
        lastPositionMs: snapshot.positionMs,
      );
    }

    if (notifyBoundary && phaseChanged) {
      _lastNotifiedSegmentIndex = snapshot.segmentIndex;
      _onPhaseBoundary?.call(snapshot.phase);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    if (!state.isPlaying && !state.isBuffering) return;

    _stopTicker();
    final now = _clock.nowMs();

    if (state.isAudioGuided) {
      _audioAnchorPositionMs = _currentAudioExtrapolatedMs();
      _audioAnchorClockMs = now;
      _lastRenderedPositionMs = _audioAnchorPositionMs;
      await _audioAdapter.pause();
    } else {
      final startClock = _visualSegmentStartedAtClockMs;
      if (startClock != null) {
        _visualAccumulatedMs =
            (_visualAccumulatedMs + math.max(0, now - startClock))
                .clamp(0, _timeline.durationMs)
                .toInt();
      }
      _visualSegmentStartedAtClockMs = null;
      _lastRenderedPositionMs = _visualAccumulatedMs;
    }

    if (_disposed) return;
    state = state.copyWith(
      status: BreathingPlaybackStatus.paused,
      lastPositionMs: _lastRenderedPositionMs,
    );
  }

  Future<void> resume() async {
    if (_disposed) return;
    if (!state.isPaused) return;

    final now = _clock.nowMs();
    if (state.isAudioGuided) {
      _audioAnchorClockMs = now;
      try {
        await _audioAdapter.play();
      } catch (e) {
        if (_disposed) return;
        state = state.copyWith(
          status: BreathingPlaybackStatus.error,
          errorMessage: 'Gagal melanjutkan audio: $e',
        );
        return;
      }
      if (_disposed) return;
    } else {
      _visualSegmentStartedAtClockMs = now;
    }

    state = state.copyWith(
      status: BreathingPlaybackStatus.playing,
      clearErrorMessage: true,
    );
    _startTickerIfIdle();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying || state.isBuffering) {
      await pause();
    } else if (state.isPaused) {
      await resume();
    }
  }

  Future<void> toggleMute() async {
    if (_disposed || !state.isAudioGuided) return;
    final nextMuted = !state.isMuted;
    await _audioAdapter.setMuted(nextMuted);
    if (_disposed) return;
    state = state.copyWith(isMuted: nextMuted);
  }

  /// Switches explicitly to monotonic visual-only mode mid-session after an audio failure.
  Future<void> switchToVisualOnlyFromError() async {
    if (_disposed) return;
    _loadGeneration++;
    await _cancelAudioSubscriptions();
    await _audioAdapter.stop();

    _visualAccumulatedMs = _lastRenderedPositionMs.clamp(
      0,
      _timeline.durationMs,
    );
    _visualSegmentStartedAtClockMs = _clock.nowMs();

    state = state.copyWith(
      guidanceSource: BreathingGuidanceSource.visualOnly,
      status: BreathingPlaybackStatus.playing,
      audioUnavailableReason: 'Dilanjutkan dengan panduan visual tanpa suara.',
      clearErrorMessage: true,
    );
    _startTickerIfIdle();
  }

  Future<void> handleAppBackgrounded() async {
    if (_disposed) return;
    if (state.isPlaying || state.isBuffering) {
      await pause();
    }
  }

  void _completeSession() {
    if (_disposed || state.completionEmitted) return;
    _stopTicker();
    _visualSegmentStartedAtClockMs = null;
    _lastRenderedPositionMs = _timeline.durationMs;

    final endSnapshot = _timeline.resolvePosition(_timeline.durationMs);
    _publishFrame(endSnapshot, notifyBoundary: false);

    final result = CopingSessionResult.completed(
      exerciseId: CopingExerciseId.breathing,
      elapsed: Duration(milliseconds: _timeline.durationMs),
      isVisualOnly: !state.isAudioGuided,
    );

    state = state.copyWith(
      status: BreathingPlaybackStatus.completed,
      currentPhase: BreathingPhase.outro,
      phaseRemainingSeconds: 0,
      lastPositionMs: _timeline.durationMs,
      completionEmitted: true,
    );
    _onCompleted?.call(result);
  }

  /// Cancels an active or loading session without recording completion.
  Future<CopingSessionResult> cancel() async {
    _loadGeneration++;
    _stopTicker();
    final elapsedMs = state.hasCompleted
        ? _timeline.durationMs
        : _lastRenderedPositionMs.clamp(0, _timeline.durationMs);
    if (_audioPrepared) {
      _audioPrepared = false;
      try {
        await _audioAdapter.stop().timeout(
          const Duration(milliseconds: 250),
          onTimeout: () {},
        );
      } catch (_) {}
    }
    await _cancelAudioSubscriptions();

    if (!_disposed && !state.hasCompleted) {
      state = state.copyWith(
        status: BreathingPlaybackStatus.idle,
        lastPositionMs: elapsedMs,
      );
    }

    return state.hasCompleted
        ? CopingSessionResult.completed(
            exerciseId: CopingExerciseId.breathing,
            elapsed: Duration(milliseconds: _timeline.durationMs),
            isVisualOnly: !state.isAudioGuided,
          )
        : CopingSessionResult.cancelled(
            exerciseId: CopingExerciseId.breathing,
            elapsed: Duration(milliseconds: elapsedMs),
            isVisualOnly: !state.isAudioGuided,
          );
  }

  void _startTickerIfIdle() {
    final ticker = _ticker;
    if (ticker != null && !ticker.isActive) {
      ticker.start();
    }
  }

  void _stopTicker() {
    final ticker = _ticker;
    if (ticker != null && ticker.isActive) {
      ticker.stop();
    }
  }

  Future<void> _cancelAudioSubscriptions() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _loadGeneration++;
    detachTickerProvider();
    unawaited(_cancelAudioSubscriptions());
    unawaited(_audioAdapter.dispose());
    _motionNotifier.dispose();
    if (mounted) {
      state = state.copyWith(status: BreathingPlaybackStatus.disposed);
      super.dispose();
    }
  }
}

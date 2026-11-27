import '../domain/breathing_phase.dart';
import '../domain/breathing_session.dart';

/// Frame-rate visual values published via [ValueNotifier] for localized painter repaints.
class BreathingMotionFrame {
  final BreathingPhase phase;
  final double phaseProgress;
  final double breathAmount;
  final double lungScale;
  final double glowIntensity;
  final double sessionProgress;
  final int positionMs;
  final int phaseRemainingSeconds;

  const BreathingMotionFrame({
    required this.phase,
    required this.phaseProgress,
    required this.breathAmount,
    required this.lungScale,
    required this.glowIntensity,
    required this.sessionProgress,
    required this.positionMs,
    required this.phaseRemainingSeconds,
  });

  static const BreathingMotionFrame initial = BreathingMotionFrame(
    phase: BreathingPhase.preparation,
    phaseProgress: 0.0,
    breathAmount: 0.0,
    lungScale: 1.0,
    glowIntensity: 0.25,
    sessionProgress: 0.0,
    positionMs: 0,
    phaseRemainingSeconds: 4,
  );
}

/// Discrete UI state for guided breathing controls, semantics, and lifecycle.
class BreathingState {
  final BreathingPlaybackStatus status;
  final BreathingGuidanceSource guidanceSource;
  final BreathingPhase currentPhase;
  final int phaseRemainingSeconds;
  final int durationMs;
  final int lastPositionMs;
  final bool isMuted;
  final bool reducedMotion;
  final bool completionEmitted;
  final String? audioUnavailableReason;
  final String? errorMessage;

  const BreathingState({
    this.status = BreathingPlaybackStatus.idle,
    this.guidanceSource = BreathingGuidanceSource.visualOnly,
    this.currentPhase = BreathingPhase.preparation,
    this.phaseRemainingSeconds = 4,
    this.durationMs = 40000,
    this.lastPositionMs = 0,
    this.isMuted = false,
    this.reducedMotion = false,
    this.completionEmitted = false,
    this.audioUnavailableReason,
    this.errorMessage,
  });

  bool get isPlaying => status == BreathingPlaybackStatus.playing;
  bool get isPaused => status == BreathingPlaybackStatus.paused;
  bool get isLoading => status == BreathingPlaybackStatus.loading;
  bool get isBuffering => status == BreathingPlaybackStatus.buffering;
  bool get hasCompleted => status == BreathingPlaybackStatus.completed;
  bool get hasError => status == BreathingPlaybackStatus.error;
  bool get isAudioGuided =>
      guidanceSource == BreathingGuidanceSource.audioGuided;

  BreathingState copyWith({
    BreathingPlaybackStatus? status,
    BreathingGuidanceSource? guidanceSource,
    BreathingPhase? currentPhase,
    int? phaseRemainingSeconds,
    int? durationMs,
    int? lastPositionMs,
    bool? isMuted,
    bool? reducedMotion,
    bool? completionEmitted,
    String? audioUnavailableReason,
    bool clearAudioUnavailableReason = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return BreathingState(
      status: status ?? this.status,
      guidanceSource: guidanceSource ?? this.guidanceSource,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseRemainingSeconds:
          phaseRemainingSeconds ?? this.phaseRemainingSeconds,
      durationMs: durationMs ?? this.durationMs,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      isMuted: isMuted ?? this.isMuted,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      completionEmitted: completionEmitted ?? this.completionEmitted,
      audioUnavailableReason: clearAudioUnavailableReason
          ? null
          : (audioUnavailableReason ?? this.audioUnavailableReason),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

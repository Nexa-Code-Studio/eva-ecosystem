/// Playback lifecycle states separating media readiness from breathing phase.
enum BreathingPlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
  disposed,
}

/// Authoritative session timing source.
enum BreathingGuidanceSource { visualOnly, audioGuided }

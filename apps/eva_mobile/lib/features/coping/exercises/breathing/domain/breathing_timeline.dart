import 'dart:convert';
import 'dart:math' as math;

import 'breathing_phase.dart';

/// Exception thrown when a guided breathing JSON timeline violates schema v1 invariants.
class BreathingTimelineException implements Exception {
  final String message;

  const BreathingTimelineException(this.message);

  @override
  String toString() => 'BreathingTimelineException: $message';
}

/// Half-open timeline segment `[startMs, endMs)` mapped to a single [BreathingPhase].
class BreathingSegment {
  final BreathingPhase phase;
  final int startMs;
  final int endMs;

  const BreathingSegment({
    required this.phase,
    required this.startMs,
    required this.endMs,
  });

  int get durationMs => endMs - startMs;

  bool contains(int positionMs) => positionMs >= startMs && positionMs < endMs;
}

/// Pure, immutable frame values resolved from a timeline timestamp.
class BreathingFrameSnapshot {
  final BreathingPhase phase;
  final double phaseProgress;
  final double breathAmount;
  final double sessionProgress;
  final int positionMs;
  final int durationMs;
  final int phaseRemainingMs;
  final int segmentIndex;
  final bool isCompleted;

  const BreathingFrameSnapshot({
    required this.phase,
    required this.phaseProgress,
    required this.breathAmount,
    required this.sessionProgress,
    required this.positionMs,
    required this.durationMs,
    required this.phaseRemainingMs,
    required this.segmentIndex,
    required this.isCompleted,
  });

  /// Whole-second countdown shown in UI (1..N) without fractional flicker.
  int get phaseRemainingSeconds =>
      phaseRemainingMs <= 0 ? 0 : ((phaseRemainingMs + 999) ~/ 1000);

  int get sessionRemainingMs => math.max(0, durationMs - positionMs);
}

/// Pure math mapping common [breathAmount] to ring and lung visual coordinates.
class BreathingMotionMapper {
  BreathingMotionMapper._();

  /// Computes normalized breath fullness `[0.0, 1.0]` continuous across phase boundaries.
  static double breathAmount(BreathingPhase phase, double phaseProgress) {
    final p = phaseProgress.clamp(0.0, 1.0);
    switch (phase) {
      case BreathingPhase.preparation:
      case BreathingPhase.outro:
        return 0.0;
      case BreathingPhase.inhale:
        return p;
      case BreathingPhase.exhale:
        return 1.0 - p;
    }
  }

  /// Ring contracts linearly from [radiusMax] -> [radiusMin] on inhale,
  /// and expands linearly from [radiusMin] -> [radiusMax] on exhale.
  static double ringRadius(
    double breathAmount, {
    required double radiusMax,
    required double radiusMin,
  }) {
    final b = breathAmount.clamp(0.0, 1.0);
    return radiusMax + (radiusMin - radiusMax) * b;
  }

  /// Sine ease matching `Curves.easeInOutSine` in pure Dart without Flutter dependency.
  static double easeInOutSine(double t) {
    final x = t.clamp(0.0, 1.0);
    return 0.5 * (1.0 - math.cos(math.pi * x));
  }

  /// Lungs expand gently from [minScale] (1.00) -> [maxScale] (1.20) on inhale
  /// and contract symmetrically back during exhale.
  static double lungScale(
    double breathAmount, {
    double minScale = 1.0,
    double maxScale = 1.20,
  }) {
    final eased = easeInOutSine(breathAmount);
    return minScale + (maxScale - minScale) * eased;
  }

  /// Luminous intensity factor in `[0.25, 1.0]` synchronized with breath phase.
  static double glowIntensity(double breathAmount) {
    return 0.25 + 0.75 * easeInOutSine(breathAmount);
  }
}

/// Authoritative schema v1 guided breathing timeline and pure timestamp resolver.
class BreathingTimeline {
  static const int supportedSchemaVersion = 1;
  static const int defaultAudioDurationToleranceMs = 150;

  final int schemaVersion;
  final String id;
  final String locale;
  final String? audioAsset;
  final int durationMs;
  final List<BreathingSegment> segments;

  const BreathingTimeline._({
    required this.schemaVersion,
    required this.id,
    required this.locale,
    required this.audioAsset,
    required this.durationMs,
    required this.segments,
  });

  /// Built-in calm visual program (4s preparation + 4 cycles of 4s inhale / 4s exhale + 4s outro).
  factory BreathingTimeline.defaultGuidedId() {
    const List<BreathingSegment> segs = [
      BreathingSegment(
        phase: BreathingPhase.preparation,
        startMs: 0,
        endMs: 4000,
      ),
      BreathingSegment(
        phase: BreathingPhase.inhale,
        startMs: 4000,
        endMs: 8000,
      ),
      BreathingSegment(
        phase: BreathingPhase.exhale,
        startMs: 8000,
        endMs: 12000,
      ),
      BreathingSegment(
        phase: BreathingPhase.inhale,
        startMs: 12000,
        endMs: 16000,
      ),
      BreathingSegment(
        phase: BreathingPhase.exhale,
        startMs: 16000,
        endMs: 20000,
      ),
      BreathingSegment(
        phase: BreathingPhase.inhale,
        startMs: 20000,
        endMs: 24000,
      ),
      BreathingSegment(
        phase: BreathingPhase.exhale,
        startMs: 24000,
        endMs: 28000,
      ),
      BreathingSegment(
        phase: BreathingPhase.inhale,
        startMs: 28000,
        endMs: 32000,
      ),
      BreathingSegment(
        phase: BreathingPhase.exhale,
        startMs: 32000,
        endMs: 36000,
      ),
      BreathingSegment(
        phase: BreathingPhase.outro,
        startMs: 36000,
        endMs: 40000,
      ),
    ];

    return const BreathingTimeline._(
      schemaVersion: supportedSchemaVersion,
      id: 'guided_breathing_id_4_4',
      locale: 'id-ID',
      audioAsset: null,
      durationMs: 40000,
      segments: segs,
    );
  }

  /// Parses and validates a JSON string against timeline schema v1.
  factory BreathingTimeline.fromJsonString(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const BreathingTimelineException(
        'Timeline JSON must be an object.',
      );
    }
    return BreathingTimeline.fromJson(decoded);
  }

  /// Parses and validates a JSON map against timeline schema v1.
  factory BreathingTimeline.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int || version != supportedSchemaVersion) {
      throw BreathingTimelineException(
        'Unsupported schemaVersion: $version (expected $supportedSchemaVersion).',
      );
    }

    final rawId = json['id'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const BreathingTimelineException('Missing or empty timeline id.');
    }

    final rawLocale = json['locale'];
    if (rawLocale is! String || rawLocale.trim().isEmpty) {
      throw const BreathingTimelineException(
        'Missing or empty timeline locale.',
      );
    }

    final rawDuration = json['durationMs'];
    if (rawDuration is! int || rawDuration <= 0) {
      throw BreathingTimelineException('Invalid durationMs: $rawDuration.');
    }

    final rawAudioAsset = json['audioAsset'];
    if (rawAudioAsset != null && rawAudioAsset is! String) {
      throw const BreathingTimelineException(
        'audioAsset must be a string when present.',
      );
    }

    final rawSegments = json['segments'];
    if (rawSegments is! List || rawSegments.isEmpty) {
      throw const BreathingTimelineException(
        'Timeline segments must be a non-empty list.',
      );
    }

    final parsedSegments = <BreathingSegment>[];
    int expectedStart = 0;
    bool hasCompleteCycle = false;

    for (int i = 0; i < rawSegments.length; i++) {
      final entry = rawSegments[i];
      if (entry is! Map<String, dynamic>) {
        throw BreathingTimelineException(
          'Segment at index $i is not an object.',
        );
      }

      final phase = BreathingPhase.tryParse(entry['phase']?.toString());
      if (phase == null) {
        throw BreathingTimelineException(
          'Unsupported phase "${entry['phase']}" at segment index $i.',
        );
      }

      final startMs = entry['startMs'];
      final endMs = entry['endMs'];
      if (startMs is! int || endMs is! int) {
        throw BreathingTimelineException(
          'Segment $i must use integer timestamps.',
        );
      }
      if (startMs < 0 || endMs <= startMs) {
        throw BreathingTimelineException(
          'Segment $i has non-positive or negative bounds [$startMs, $endMs).',
        );
      }
      if (startMs != expectedStart) {
        throw BreathingTimelineException(
          'Segment $i startMs ($startMs) violates contiguous order (expected $expectedStart).',
        );
      }

      if (i > 0) {
        final prevPhase = parsedSegments[i - 1].phase;
        if (!_isValidTransition(prevPhase, phase)) {
          throw BreathingTimelineException(
            'Invalid phase transition $prevPhase -> $phase at segment $i.',
          );
        }
        if (prevPhase == BreathingPhase.inhale &&
            phase == BreathingPhase.exhale) {
          hasCompleteCycle = true;
        }
      }

      parsedSegments.add(
        BreathingSegment(phase: phase, startMs: startMs, endMs: endMs),
      );
      expectedStart = endMs;
    }

    if (expectedStart != rawDuration) {
      throw BreathingTimelineException(
        'Final segment endMs ($expectedStart) does not equal durationMs ($rawDuration).',
      );
    }

    if (!hasCompleteCycle) {
      throw const BreathingTimelineException(
        'Timeline must contain at least one complete inhale -> exhale cycle.',
      );
    }

    return BreathingTimeline._(
      schemaVersion: version,
      id: rawId.trim(),
      locale: rawLocale.trim(),
      audioAsset: (rawAudioAsset as String?)?.trim(),
      durationMs: rawDuration,
      segments: List<BreathingSegment>.unmodifiable(parsedSegments),
    );
  }

  static bool _isValidTransition(BreathingPhase prev, BreathingPhase next) {
    switch (prev) {
      case BreathingPhase.preparation:
        return next == BreathingPhase.inhale;
      case BreathingPhase.inhale:
        return next == BreathingPhase.exhale;
      case BreathingPhase.exhale:
        return next == BreathingPhase.inhale || next == BreathingPhase.outro;
      case BreathingPhase.outro:
        return false;
    }
  }

  /// Checks whether measured media duration matches [durationMs] within [toleranceMs].
  bool isCompatibleWithAudioDuration(
    int actualAudioDurationMs, {
    int toleranceMs = defaultAudioDurationToleranceMs,
  }) {
    if (actualAudioDurationMs <= 0) return false;
    return (actualAudioDurationMs - durationMs).abs() <= toleranceMs;
  }

  /// Validates measured media duration and throws [BreathingTimelineException] on mismatch.
  void assertCompatibleWithAudioDuration(
    int actualAudioDurationMs, {
    int toleranceMs = defaultAudioDurationToleranceMs,
  }) {
    if (!isCompatibleWithAudioDuration(
      actualAudioDurationMs,
      toleranceMs: toleranceMs,
    )) {
      throw BreathingTimelineException(
        'Audio duration (${actualAudioDurationMs}ms) differs from timeline '
        'duration (${durationMs}ms) beyond +/-${toleranceMs}ms tolerance.',
      );
    }
  }

  /// Resolves an arbitrary timestamp deterministically using half-open `[startMs, endMs)` bounds.
  BreathingFrameSnapshot resolvePosition(int rawPositionMs) {
    final clampedPos = rawPositionMs.clamp(0, durationMs);
    if (clampedPos >= durationMs) {
      final lastSeg = segments.last;
      return BreathingFrameSnapshot(
        phase: lastSeg.phase,
        phaseProgress: 1.0,
        breathAmount: BreathingMotionMapper.breathAmount(lastSeg.phase, 1.0),
        sessionProgress: 1.0,
        positionMs: durationMs,
        durationMs: durationMs,
        phaseRemainingMs: 0,
        segmentIndex: segments.length - 1,
        isCompleted: true,
      );
    }

    int low = 0;
    int high = segments.length - 1;
    int matchIdx = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final seg = segments[mid];
      if (clampedPos < seg.startMs) {
        high = mid - 1;
      } else if (clampedPos >= seg.endMs) {
        low = mid + 1;
      } else {
        matchIdx = mid;
        break;
      }
    }

    final seg = segments[matchIdx];
    final segDur = math.max(1, seg.durationMs);
    final phaseProgress = ((clampedPos - seg.startMs) / segDur).clamp(0.0, 1.0);
    final breath = BreathingMotionMapper.breathAmount(seg.phase, phaseProgress);

    return BreathingFrameSnapshot(
      phase: seg.phase,
      phaseProgress: phaseProgress,
      breathAmount: breath,
      sessionProgress: (clampedPos / durationMs).clamp(0.0, 1.0),
      positionMs: clampedPos,
      durationMs: durationMs,
      phaseRemainingMs: math.max(0, seg.endMs - clampedPos),
      segmentIndex: matchIdx,
      isCompleted: false,
    );
  }
}

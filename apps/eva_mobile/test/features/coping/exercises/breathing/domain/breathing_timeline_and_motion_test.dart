import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/domain/breathing_phase.dart';
import 'package:eva_mobile/features/coping/exercises/breathing/domain/breathing_timeline.dart';

void main() {
  group('BreathingTimeline Schema v1 & Validation', () {
    test(
      'parses valid schema v1 timeline and resolves boundary positions cleanly',
      () {
        const rawJson = '''
      {
        "schemaVersion": 1,
        "id": "guided_breathing_test",
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

        final timeline = BreathingTimeline.fromJsonString(rawJson);
        expect(timeline.id, 'guided_breathing_test');
        expect(timeline.durationMs, 20000);
        expect(timeline.segments.length, 5);

        // Start of preparation
        final s0 = timeline.resolvePosition(0);
        expect(s0.phase, BreathingPhase.preparation);
        expect(s0.phaseProgress, 0.0);
        expect(s0.breathAmount, 0.0);
        expect(s0.isCompleted, isFalse);

        // Exact boundary at 4000 -> belongs to half-open [4000, 8000) inhale
        final s4000 = timeline.resolvePosition(4000);
        expect(s4000.phase, BreathingPhase.inhale);
        expect(s4000.phaseProgress, 0.0);
        expect(s4000.phaseRemainingSeconds, 4);

        // Midpoint of inhale (6000ms -> 50% progress)
        final s6000 = timeline.resolvePosition(6000);
        expect(s6000.phase, BreathingPhase.inhale);
        expect(s6000.phaseProgress, closeTo(0.5, 1e-6));
        expect(s6000.breathAmount, closeTo(0.5, 1e-6));

        // Negative clamping -> clamps to 0
        final sNeg = timeline.resolvePosition(-500);
        expect(sNeg.positionMs, 0);
        expect(sNeg.phase, BreathingPhase.preparation);

        // At/beyond durationMs -> completed end state
        final sEnd = timeline.resolvePosition(25000);
        expect(sEnd.isCompleted, isTrue);
        expect(sEnd.positionMs, 20000);
        expect(sEnd.sessionProgress, 1.0);
        expect(sEnd.breathAmount, 0.0);
      },
    );

    test(
      'rejects invalid schema versions, unknown phases, gaps, overlaps, and mismatches',
      () {
        const invalidCases = <String>[
          // Wrong schema version
          '{"schemaVersion":2,"id":"x","locale":"id-ID","durationMs":8000,"segments":[{"phase":"inhale","startMs":0,"endMs":4000},{"phase":"exhale","startMs":4000,"endMs":8000}]}',
          // Unknown phase
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":8000,"segments":[{"phase":"hold_forever","startMs":0,"endMs":4000},{"phase":"exhale","startMs":4000,"endMs":8000}]}',
          // Gap between segments
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":9000,"segments":[{"phase":"inhale","startMs":0,"endMs":4000},{"phase":"exhale","startMs":5000,"endMs":9000}]}',
          // Overlap between segments
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":8000,"segments":[{"phase":"inhale","startMs":0,"endMs":4500},{"phase":"exhale","startMs":4000,"endMs":8000}]}',
          // Zero-length segment
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":4000,"segments":[{"phase":"inhale","startMs":0,"endMs":0},{"phase":"exhale","startMs":0,"endMs":4000}]}',
          // Negative start
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":4000,"segments":[{"phase":"inhale","startMs":-1,"endMs":2000},{"phase":"exhale","startMs":2000,"endMs":4000}]}',
          // Duration mismatch
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":9000,"segments":[{"phase":"inhale","startMs":0,"endMs":4000},{"phase":"exhale","startMs":4000,"endMs":8000}]}',
          // Missing inhale->exhale cycle
          '{"schemaVersion":1,"id":"x","locale":"id-ID","durationMs":4000,"segments":[{"phase":"preparation","startMs":0,"endMs":4000}]}',
        ];

        for (final raw in invalidCases) {
          expect(
            () => BreathingTimeline.fromJsonString(raw),
            throwsA(isA<BreathingTimelineException>()),
          );
        }
        expect(
          () => BreathingTimeline.fromJsonString('{malformed'),
          throwsException,
        );
      },
    );

    test(
      'validates audio duration within tolerance and rejects excess drift',
      () {
        final timeline = BreathingTimeline.defaultGuidedId();
        expect(timeline.isCompatibleWithAudioDuration(40120), isTrue);
        expect(timeline.isCompatibleWithAudioDuration(39880), isTrue);
        expect(timeline.isCompatibleWithAudioDuration(40500), isFalse);
        expect(
          () => timeline.assertCompatibleWithAudioDuration(40500),
          throwsA(isA<BreathingTimelineException>()),
        );
      },
    );
  });

  group('BreathingMotionMapper Continuity & Inverse Semantics', () {
    test(
      'ring contracts linearly on inhale, expands on exhale, lungs move inversely with continuous endpoints',
      () {
        final timeline = BreathingTimeline.defaultGuidedId();
        const radiusMax = 180.0;
        const radiusMin = 100.0;

        // Preparation -> inhale transition continuity at 4000ms
        final prepEnd = BreathingMotionMapper.breathAmount(
          BreathingPhase.preparation,
          1.0,
        );
        final inhaleStart = BreathingMotionMapper.breathAmount(
          BreathingPhase.inhale,
          0.0,
        );
        expect(prepEnd, equals(inhaleStart));

        // Inhale monotonic contraction for ring & monotonic expansion for lungs
        double prevRadius = radiusMax + 1;
        double prevLung = 0.0;
        for (int ms = 4000; ms <= 8000; ms += 250) {
          final snap = timeline.resolvePosition(ms == 8000 ? 7999 : ms);
          final r = BreathingMotionMapper.ringRadius(
            snap.breathAmount,
            radiusMax: radiusMax,
            radiusMin: radiusMin,
          );
          final l = BreathingMotionMapper.lungScale(snap.breathAmount);
          expect(r.isNaN, isFalse);
          expect(l.isNaN, isFalse);
          expect(r, lessThan(prevRadius));
          expect(l, greaterThan(prevLung));
          prevRadius = r;
          prevLung = l;
        }

        // Inhale end == Exhale start endpoint continuity
        final inhaleEndR = BreathingMotionMapper.ringRadius(
          BreathingMotionMapper.breathAmount(BreathingPhase.inhale, 1.0),
          radiusMax: radiusMax,
          radiusMin: radiusMin,
        );
        final exhaleStartR = BreathingMotionMapper.ringRadius(
          BreathingMotionMapper.breathAmount(BreathingPhase.exhale, 0.0),
          radiusMax: radiusMax,
          radiusMin: radiusMin,
        );
        expect(inhaleEndR, closeTo(radiusMin, 1e-6));
        expect(exhaleStartR, closeTo(inhaleEndR, 1e-6));

        // Exhale monotonic expansion for ring & contraction for lungs
        double prevExhaleR = radiusMin - 1;
        double prevExhaleLung = 2.0;
        for (int ms = 8000; ms < 12000; ms += 250) {
          final snap = timeline.resolvePosition(ms);
          final r = BreathingMotionMapper.ringRadius(
            snap.breathAmount,
            radiusMax: radiusMax,
            radiusMin: radiusMin,
          );
          final l = BreathingMotionMapper.lungScale(snap.breathAmount);
          expect(r, greaterThan(prevExhaleR));
          expect(l, lessThan(prevExhaleLung));
          prevExhaleR = r;
          prevExhaleLung = l;
        }

        // Outro matches exhale end
        expect(
          BreathingMotionMapper.lungScale(
            BreathingMotionMapper.breathAmount(BreathingPhase.outro, 0.0),
          ),
          closeTo(1.0, 1e-6),
        );
      },
    );
  });
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/breathing_state.dart';
import '../../domain/breathing_phase.dart';

/// Paints a serene side-profile head and neck facing right (`+X`) with a clear
/// nasal/oral upper airway passage and time-synced inhale/exhale airflow cues.
class BreathingHumanPainter extends CustomPainter {
  final ValueListenable<BreathingMotionFrame> motion;
  final bool reducedMotion;

  static const Color _headTop = Color(0xFF9AA7FF);
  static const Color _headMid = Color(0xFF5962BE);
  static const Color _headFade = Color(0x0017183D);
  static const Color _featureLine = Color(0xFFC9CCFF);
  static const Color _airwayBase = Color(0xFFB596FF);
  static const Color _airwayActive = Color(0xFFE7DAFF);
  static const Color _breathStreamColor = Color(0xFFEDE4FF);

  BreathingHumanPainter({required this.motion, this.reducedMotion = false})
    : super(repaint: motion);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = motion.value;
    final center = Offset(size.width / 2, size.height * 0.44);
    final figureScale = (size.shortestSide * 0.34).clamp(72.0, 145.0) / 100.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(figureScale, figureScale);

    _drawHeadProfile(canvas);
    _drawUpperAirway(
      canvas,
      phase: frame.phase,
      phaseProgress: frame.phaseProgress,
      glowIntensity: frame.glowIntensity,
    );
    if (!reducedMotion) {
      _drawTimeSyncedBreathFlow(
        canvas,
        phase: frame.phase,
        phaseProgress: frame.phaseProgress,
      );
    }

    canvas.restore();
  }

  void _drawHeadProfile(Canvas canvas) {
    // Side-profile human head and neck facing right (+X), no torso or lungs.
    final headPath = Path()
      ..moveTo(-36, 62)
      ..cubicTo(-26, 42, -23, 24, -27, 8)
      // Back of head and rounded cranium sweeping up over the crown.
      ..cubicTo(-43, -6, -44, -40, -19, -56)
      ..cubicTo(2, -68, 25, -58, 28, -36)
      // Subtle brow curve, straight nose bridge, tip, and nostril underside.
      ..quadraticBezierTo(27, -28, 30, -22)
      ..lineTo(42, -6)
      ..quadraticBezierTo(38, -2, 30, -3)
      // Upper lip, mouth notch, lower lip, rounded chin, and jawline.
      ..lineTo(34, 4)
      ..lineTo(27, 6)
      ..lineTo(33, 11)
      ..quadraticBezierTo(33, 21, 27, 25)
      ..cubicTo(20, 29, 8, 26, 4, 34)
      ..cubicTo(4, 44, 8, 54, 15, 62)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -64),
        const Offset(0, 62),
        [
          _headTop.withValues(alpha: 0.56),
          _headMid.withValues(alpha: 0.42),
          _headFade,
        ],
        const [0.0, 0.72, 1.0],
      );
    canvas.drawPath(headPath, fillPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = ui.Gradient.linear(
        const Offset(0, -64),
        const Offset(0, 62),
        [
          _featureLine.withValues(alpha: 0.62),
          _featureLine.withValues(alpha: 0.30),
          Colors.transparent,
        ],
        const [0.0, 0.72, 1.0],
      );
    canvas.drawPath(headPath, rimPaint);

    // Calm closed eye arc aligned to right-facing profile.
    final eyePath = Path()
      ..moveTo(15, -24)
      ..quadraticBezierTo(20.5, -21, 26, -24);
    canvas.drawPath(
      eyePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.35
        ..color = _featureLine.withValues(alpha: 0.68),
    );
  }

  void _drawUpperAirway(
    Canvas canvas, {
    required BreathingPhase phase,
    required double phaseProgress,
    required double glowIntensity,
  }) {
    // Anatomical nasal and oral upper airway converging cleanly into the neck trachea.
    final airwayShape = Path()
      // Start at nostril floor and trace upper nasal dome back toward pharynx.
      ..moveTo(32, -4)
      ..cubicTo(20, -15, 3, -17, -9, -11)
      ..cubicTo(-15, -7, -17, 6, -17, 24)
      ..lineTo(-16, 62)
      ..lineTo(-5, 62)
      ..lineTo(-6, 18)
      // Mouth opening floor curving up beneath soft palate into pharynx.
      ..cubicTo(-6, 13, 8, 12, 27, 9)
      ..lineTo(27, 4)
      ..cubicTo(15, 5, 3, 5, -2, 3)
      // Hard/soft palate arch separating oral cavity from nasal cavity.
      ..cubicTo(2, -3, 18, -3, 30, -2)
      ..close();

    final baseAlpha = 0.28 + 0.22 * glowIntensity;
    canvas.drawPath(
      airwayShape,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -16),
          const Offset(0, 62),
          [
            _airwayBase.withValues(alpha: baseAlpha + 0.16),
            _airwayBase.withValues(alpha: baseAlpha),
            _airwayBase.withValues(alpha: 0.04),
          ],
          const [0.0, 0.65, 1.0],
        ),
    );

    canvas.drawPath(
      airwayShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _airwayActive.withValues(alpha: 0.34 + 0.24 * glowIntensity),
    );

    if (reducedMotion ||
        (phase != BreathingPhase.inhale && phase != BreathingPhase.exhale)) {
      return;
    }

    // Traveling luminous breath pulse inside the active airway channel.
    final t = phaseProgress.clamp(0.0, 1.0);
    final Path activeTrack;
    if (phase == BreathingPhase.inhale) {
      // Inhale enters via the nose bridge -> pharynx -> down trachea.
      activeTrack = Path()
        ..moveTo(31, -3)
        ..quadraticBezierTo(12, -11, -10, -2)
        ..quadraticBezierTo(-12, 22, -11, 56);
    } else {
      // Exhale rises up trachea -> oral channel -> exits through lips.
      activeTrack = Path()
        ..moveTo(-11, 56)
        ..quadraticBezierTo(-10, 18, -2, 8)
        ..quadraticBezierTo(12, 7, 29, 7);
    }

    final metrics = activeTrack.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final len = metric.length;
    final headPos = t * len;
    final tailPos = (headPos - len * 0.36).clamp(0.0, len);

    if (headPos > tailPos) {
      final pulsePath = metric.extractPath(tailPos, headPos);
      canvas.drawPath(
        pulsePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4.2
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4.0)
          ..color = _airwayActive.withValues(alpha: 0.68),
      );
      canvas.drawPath(
        pulsePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.0
          ..color = _breathStreamColor.withValues(alpha: 0.90),
      );
    }
  }

  void _drawTimeSyncedBreathFlow(
    Canvas canvas, {
    required BreathingPhase phase,
    required double phaseProgress,
  }) {
    final t = phaseProgress.clamp(0.0, 1.0);
    if (phase == BreathingPhase.inhale) {
      // Airflow curves smoothly IN toward the right-facing nostril (34, -4).
      final paths = [
        Path()
          ..moveTo(80, -14)
          ..quadraticBezierTo(56, -11, 35, -5),
        Path()
          ..moveTo(84, -4)
          ..quadraticBezierTo(60, -4, 35, -4),
        Path()
          ..moveTo(77, 5)
          ..quadraticBezierTo(54, 1, 35, -3),
      ];
      _paintAnimatedStreamers(
        canvas,
        paths: paths,
        progress: t,
        inward: true,
        particleStart: const Offset(82, -4),
        particleEnd: const Offset(35, -4),
      );
    } else if (phase == BreathingPhase.exhale) {
      // Soft breath wisps curve OUTWARD to the right from the mouth (31, 7).
      final paths = [
        Path()
          ..moveTo(31, 7)
          ..quadraticBezierTo(56, 3, 84, -4),
        Path()
          ..moveTo(31, 7)
          ..quadraticBezierTo(59, 8, 88, 9),
        Path()
          ..moveTo(31, 7)
          ..quadraticBezierTo(54, 14, 80, 21),
      ];
      _paintAnimatedStreamers(
        canvas,
        paths: paths,
        progress: t,
        inward: false,
        particleStart: const Offset(31, 7),
        particleEnd: const Offset(86, 9),
      );
    }
  }

  void _paintAnimatedStreamers(
    Canvas canvas, {
    required List<Path> paths,
    required double progress,
    required bool inward,
    required Offset particleStart,
    required Offset particleEnd,
  }) {
    final envelope = math.sin(math.pi * progress).clamp(0.0, 1.0);
    final streamAlpha = 0.24 + 0.48 * envelope;

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      for (final metric in path.computeMetrics()) {
        final len = metric.length;
        for (var pulse = 0; pulse < 2; pulse++) {
          final p = (progress + pulse * 0.5) % 1.0;
          final segLen = len * 0.42;
          final start = (p * (len + segLen)) - segLen;
          final end = start + segLen;
          final clippedStart = start.clamp(0.0, len);
          final clippedEnd = end.clamp(0.0, len);
          if (clippedEnd <= clippedStart) continue;

          final extract = metric.extractPath(clippedStart, clippedEnd);
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = i == 1 ? 1.85 : 1.3
            ..color = _breathStreamColor.withValues(
              alpha: streamAlpha * (i == 1 ? 1.0 : 0.78),
            );
          canvas.drawPath(extract, paint);
        }
      }
    }

    final motePos = Offset.lerp(particleStart, particleEnd, progress)!;
    canvas.drawCircle(
      motePos,
      inward ? 2.4 : 2.8,
      Paint()..color = _breathStreamColor.withValues(alpha: 0.74 * envelope),
    );
  }

  @override
  bool shouldRepaint(covariant BreathingHumanPainter oldDelegate) {
    return oldDelegate.motion != motion ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}

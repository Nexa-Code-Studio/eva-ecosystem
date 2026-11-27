import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/breathing_state.dart';
import '../../domain/breathing_timeline.dart';

/// Paints the luminous breathing guide ring that contracts during inhale
/// and expands during exhale in sync with the shared motion frame.
class BreathingRingPainter extends CustomPainter {
  final ValueListenable<BreathingMotionFrame> motion;
  final bool reducedMotion;

  static const Color _ringHighlight = Color(0xFFD9C8FF);
  static const Color _ringGlow = Color(0xFFAC92FF);
  static const Color _staticGuideColor = Color(0xFF7D78AD);

  BreathingRingPainter({required this.motion, this.reducedMotion = false})
    : super(repaint: motion);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = motion.value;
    final center = Offset(size.width / 2, size.height * 0.44);
    final shortest = size.shortestSide;
    final radiusMax = shortest * 0.45;
    final radiusMin = shortest * 0.27;

    // Faint outer boundary reference ring so users always have spatial anchor.
    final staticGuidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _staticGuideColor.withValues(alpha: 0.24);
    canvas.drawCircle(center, radiusMax, staticGuidePaint);

    // Subtle inner reference halo around the torso.
    final innerGuidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _staticGuideColor.withValues(alpha: 0.14);
    canvas.drawCircle(center, radiusMin, innerGuidePaint);

    final activeRadius = BreathingMotionMapper.ringRadius(
      frame.breathAmount,
      radiusMax: radiusMax,
      radiusMin: radiusMin,
    );

    if (!reducedMotion) {
      // One subtle trailing echo ring for depth.
      final trailingRadius = (activeRadius + (radiusMax - radiusMin) * 0.14)
          .clamp(radiusMin, radiusMax * 1.03);
      final echoPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _ringGlow.withValues(alpha: 0.16 * frame.glowIntensity);
      canvas.drawCircle(center, trailingRadius, echoPaint);

      // Soft radial halo behind primary ring stroke (kept restrained).
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8.0)
        ..color = _ringGlow.withValues(alpha: 0.28 * frame.glowIntensity);
      canvas.drawCircle(center, activeRadius, glowPaint);
    }

    // Crisp luminous main ring.
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true
      ..color = _ringHighlight.withValues(
        alpha: 0.72 + 0.26 * frame.glowIntensity,
      );
    canvas.drawCircle(center, activeRadius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant BreathingRingPainter oldDelegate) {
    return oldDelegate.motion != motion ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}

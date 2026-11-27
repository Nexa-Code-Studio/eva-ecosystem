import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/breathing_state.dart';

class _ParticleSeed {
  final double angle;
  final double radialOffset;
  final double size;
  final double baseAlpha;

  const _ParticleSeed({
    required this.angle,
    required this.radialOffset,
    required this.size,
    required this.baseAlpha,
  });
}

/// Paints a small deterministic pool of soft ambient particles drifting gently
/// inward during inhalation and outward during exhalation.
class BreathingParticlesPainter extends CustomPainter {
  final ValueListenable<BreathingMotionFrame> motion;
  final bool enabled;

  static final List<_ParticleSeed> _seeds = _buildSeeds();

  static List<_ParticleSeed> _buildSeeds() {
    final rng = math.Random(171);
    return List<_ParticleSeed>.generate(26, (_) {
      return _ParticleSeed(
        angle: rng.nextDouble() * math.pi * 2,
        radialOffset: rng.nextDouble(),
        size: 1.2 + rng.nextDouble() * 1.8,
        baseAlpha: 0.14 + rng.nextDouble() * 0.24,
      );
    });
  }

  BreathingParticlesPainter({required this.motion, required this.enabled})
    : super(repaint: motion);

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final frame = motion.value;
    final center = Offset(size.width / 2, size.height * 0.44);
    final shortest = size.shortestSide;
    final outerBand = shortest * 0.54;
    final innerBand = shortest * 0.30;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final seed in _seeds) {
      // BreathAmount pulls particles slowly closer to center on inhale and eases back on exhale.
      final pull = 1.0 - (0.35 * frame.breathAmount);
      final radius =
          (innerBand + (outerBand - innerBand) * seed.radialOffset) * pull;
      final driftAngle = seed.angle + (frame.sessionProgress * 0.6);
      final pos = Offset(
        center.dx + math.cos(driftAngle) * radius,
        center.dy + math.sin(driftAngle) * radius,
      );
      paint.color = const Color(
        0xFFD9C8FF,
      ).withValues(alpha: seed.baseAlpha * (0.65 + 0.35 * frame.glowIntensity));
      canvas.drawCircle(pos, seed.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BreathingParticlesPainter oldDelegate) {
    return oldDelegate.motion != motion || oldDelegate.enabled != enabled;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/breathing_state.dart';
import '../painters/breathing_human_painter.dart';
import '../painters/breathing_particles_painter.dart';
import '../painters/breathing_ring_painter.dart';

/// Composes the dark navy/violet ambient backdrop, particles, contracting ring,
/// and human silhouette + lungs cleanly inside bounded repaint regions.
class BreathingVisualStage extends StatelessWidget {
  final ValueListenable<BreathingMotionFrame> motion;
  final bool reducedMotion;

  static const Color _bgBase = Color(0xFF0B1027);
  static const Color _bgDeep = Color(0xFF17183D);
  static const Color _ambientViolet = Color(0xFF302857);

  const BreathingVisualStage({
    super.key,
    required this.motion,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Calm dark obsidian-violet base gradient with gentle right ambient wash.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.55, -0.15),
              radius: 1.25,
              colors: [_ambientViolet, _bgDeep, _bgBase],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),

        // Soft bottom aurora horizon wash (subtle breath-linked brightness).
        if (!reducedMotion)
          ValueListenableBuilder<BreathingMotionFrame>(
            valueListenable: motion,
            builder: (context, frame, _) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.15, 0.92),
                    radius: 0.95,
                    colors: [
                      const Color(
                        0xFF5D48A8,
                      ).withValues(alpha: 0.14 + 0.14 * frame.glowIntensity),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),

        // Ambient deterministic particle drift (disabled on reduced-motion).
        if (!reducedMotion)
          RepaintBoundary(
            child: CustomPaint(
              painter: BreathingParticlesPainter(
                motion: motion,
                enabled: !reducedMotion,
              ),
              size: Size.infinite,
            ),
          ),

        // Mandatory contracting/expanding guide ring.
        RepaintBoundary(
          child: CustomPaint(
            painter: BreathingRingPainter(
              motion: motion,
              reducedMotion: reducedMotion,
            ),
            size: Size.infinite,
          ),
        ),

        // Centered stylized head/torso and independent lungs layer.
        RepaintBoundary(
          child: CustomPaint(
            painter: BreathingHumanPainter(
              motion: motion,
              reducedMotion: reducedMotion,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

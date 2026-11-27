import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/breathing_state.dart';
import '../../domain/breathing_phase.dart';

/// Stable lower HUD showing phase heading, calm instruction, and countdown dial
/// without layout jumping when labels change between phases.
class BreathingPhaseLabel extends StatelessWidget {
  final BreathingPhase phase;
  final int phaseRemainingSeconds;
  final bool isPaused;
  final ValueListenable<BreathingMotionFrame> motion;

  static const Color _primaryText = Color(0xFFF4EFFF);
  static const Color _secondaryText = Color(0xFFB6B2CF);
  static const Color _accentRing = Color(0xFFD9C8FF);

  const BreathingPhaseLabel({
    super.key,
    required this.phase,
    required this.phaseRemainingSeconds,
    required this.isPaused,
    required this.motion,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: isPaused
          ? 'Latihan dijeda. ${phase.accessibilityAnnouncement}'
          : phase.accessibilityAnnouncement,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              phase.localizedTitle,
              key: ValueKey<BreathingPhase>(phase),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: _primaryText,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxWidth: 320),
            child: Center(
              child: Text(
                isPaused
                    ? 'Latihan dijeda. Ketuk Lanjutkan saat kamu siap.'
                    : phase.localizedInstruction,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: _secondaryText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(58),
                  painter: _CountdownRingPainter(motion: motion),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$phaseRemainingSeconds',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _primaryText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final ValueListenable<BreathingMotionFrame> motion;

  _CountdownRingPainter({required this.motion}) : super(repaint: motion);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 2.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius, trackPaint);

    final sweep =
        (motion.value.phaseProgress.clamp(0.0, 1.0)) * 2 * 3.1415926535;
    if (sweep <= 0) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2
      ..color = BreathingPhaseLabel._accentRing;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.motion != motion;
  }
}

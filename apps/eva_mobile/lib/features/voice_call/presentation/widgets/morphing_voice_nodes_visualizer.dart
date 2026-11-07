import "dart:math" as math;
import "package:flutter/material.dart";

import "../../domain/entities/call_state.dart";

class MorphingVoiceNodesVisualizer extends StatefulWidget {
  final CallState callState;
  final double soundLevel;
  final bool isAiSpeaking;
  final double animValue;
  final bool isMuted;

  const MorphingVoiceNodesVisualizer({
    super.key,
    required this.callState,
    required this.soundLevel,
    required this.isAiSpeaking,
    required this.animValue,
    required this.isMuted,
  });

  @override
  State<MorphingVoiceNodesVisualizer> createState() => MorphingVoiceNodesVisualizerState();
}

class MorphingVoiceNodesVisualizerState extends State<MorphingVoiceNodesVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morphController;
  late final Animation<double> _morphAnimation;

  static const double _dotSize = 5.0;
  static const List<double> _minHeights = [8.0, 12.0, 16.0, 12.0, 8.0];
  static const List<double> _maxHeights = [26.0, 42.0, 58.0, 42.0, 26.0];

  final List<double> _currentHeights = [_dotSize, _dotSize, _dotSize, _dotSize, _dotSize];

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.callState == CallState.thinking) {
      _morphController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MorphingVoiceNodesVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.callState == CallState.thinking && oldWidget.callState != CallState.thinking) {
      _morphController.forward();
    } else if (widget.callState != CallState.thinking && oldWidget.callState == CallState.thinking) {
      _morphController.reverse();
    }

    _updatePhysics();
  }

  void _updatePhysics() {
    final double sound = widget.isMuted ? 0.0 : widget.soundLevel;
    final bool hasAudio = sound > 0.03 || (widget.isAiSpeaking && sound > 0.02);

    for (int i = 0; i < 5; i++) {
      double targetHeight;

      if (widget.callState == CallState.thinking) {
        // In thinking mode: nodes become circular dots
        targetHeight = _dotSize;
      } else if (!hasAudio || widget.isMuted) {
        // Silence / Idle: Flat dots
        targetHeight = _dotSize;
      } else if (widget.isAiSpeaking) {
        // AI Speaking: Dynamic vocal formant distribution & intonation contours
        // 5 nodes represent frequency bands across speech spectrum:
        // Node 0: Chest resonance / low fundamental (100-250 Hz)
        // Node 1: Pitch inflection / F0 contour (glide with Indonesian sentence intonation)
        // Node 2: First Formant F1 / Vowel energy (500-1000 Hz, peak acoustic power)
        // Node 3: Second Formant F2 / Articulation transitions (1.5-2.5 kHz)
        // Node 4: Sibilance / High treble energy (3-5 kHz)
        final double anim = widget.animValue;
        final double band0 = sound * (0.85 + 0.20 * math.sin(anim * 2 * math.pi * 3.5));
        final double band1 = sound * (1.15 + 0.28 * math.sin(anim * 2 * math.pi * 5.2 + 0.8));
        final double band2 = sound * (1.45 + 0.35 * math.sin(anim * 2 * math.pi * 7.0 + 1.6));
        final double band3 = sound * (1.15 + 0.26 * math.sin(anim * 2 * math.pi * 6.1 + 2.4));
        final double band4 = sound * (0.80 + 0.22 * math.sin(anim * 2 * math.pi * 8.4 + 3.2));

        final bands = [band0, band1, band2, band3, band4];
        final intonationScale = bands[i].clamp(0.0, 1.0);

        targetHeight = sound > 0.02
            ? _minHeights[i] + (intonationScale * (_maxHeights[i] - _minHeights[i]))
            : _dotSize;
      } else {
        // User speech
        final multipliers = [0.75, 1.1, 1.35, 1.05, 0.7];
        final variance = math.sin(widget.animValue * 2 * math.pi * 6.0 + (i * 1.5)) * 0.15;
        final intonationScale = (sound * multipliers[i] + variance).clamp(0.0, 1.0);
        targetHeight = _minHeights[i] + (intonationScale * (_maxHeights[i] - _minHeights[i]));
      }

      final isRising = targetHeight > _currentHeights[i];
      final factor = isRising
          ? (widget.isAiSpeaking ? 0.60 : 0.45)
          : (widget.isAiSpeaking ? 0.22 : 0.25);
      _currentHeights[i] += (targetHeight - _currentHeights[i]) * factor;
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _morphController,
      builder: (context, child) {
        final morphValue = _morphAnimation.value;

        return SizedBox(
          width: 174,
          height: 174,
          child: ClipOval(
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(174, 174),
                painter: _VoiceNodesMorphPainter(
                  morphProgress: morphValue,
                  animProgress: widget.animValue,
                  barHeights: List<double>.from(_currentHeights),
                  isThinking: widget.callState == CallState.thinking,
                  isMuted: widget.isMuted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Profile containing harmonized color tokens for each of the 5 nodes,
/// tailored to Eva AI's pastel/periwinkle/lavender brand design system.
class _NodeColorProfile {
  final Color core;       // Saturated core tone
  final Color highlight;  // Lighter glowing highlight tone
  final Color ambient;    // Soft luminous dispersion tint
  const _NodeColorProfile(this.core, this.highlight, this.ambient);
}

/// CustomPainter that renders continuous morphing of the 5 nodes into an organic,
/// abstract swirling fluid gradient ball (inspired by flow_thinking.gif).
class _VoiceNodesMorphPainter extends CustomPainter {
  final double morphProgress;
  final double animProgress;
  final List<double> barHeights;
  final bool isThinking;
  final bool isMuted;

  _VoiceNodesMorphPainter({
    required this.morphProgress,
    required this.animProgress,
    required this.barHeights,
    required this.isThinking,
    required this.isMuted,
  });

  // 5 Color profiles aligned with Eva AI brand & the abstract fluid palette:
  // Node 0 (Left): Sky Cyan (Eva Tertiary)
  // Node 1 (Mid-Left): Electric Periwinkle (Eva Primary)
  // Node 2 (Center): Deep Violet Orchid
  // Node 3 (Mid-Right): Radiant Fuchsia Pink
  // Node 4 (Right): Sunset Coral Rose
  static const List<_NodeColorProfile> _profiles = [
    _NodeColorProfile(Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFFA7E6FF)),
    _NodeColorProfile(Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFFC7D2FE)),
    _NodeColorProfile(Color(0xFF7E22CE), Color(0xFFA855F7), Color(0xFFE9D5FF)),
    _NodeColorProfile(Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFFFCE7F3)),
    _NodeColorProfile(Color(0xFFE11D48), Color(0xFFFB7185), Color(0xFFFFE4E6)),
  ];

  static const Color _defaultIndigo = Color(0xFF5358CB); // Eva Primary

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const int nodeCount = 5;
    const double barWidth = 4.8;
    const double lineSpacing = 10.5;

    // 1. FLUID ABSTRACT BACKGROUND BLEND (ACTIVE DURING THINKING)
    if (morphProgress > 0.01 && !isMuted) {
      // Soft atmospheric backdrop within the sphere (contained center spread)
      final backdropPaint = Paint()
        ..color = const Color(0xFFEDE9FE).withValues(alpha: 0.35 * morphProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);
      canvas.drawCircle(center, 44.0 * morphProgress, backdropPaint);

      // Render the 5 expanding organic fluid lobes
      for (int i = 0; i < nodeCount; i++) {
        final profile = _profiles[i];
        // 1.0x integer revolution ensures 100% seamless continuity when loop repeats
        final double theta = (i * 2 * math.pi / nodeCount) + (animProgress * 2 * math.pi * 1.0);

        // Controlled Lissajous displacement with integer harmonic cycles
        final double lissajousX = math.cos(theta) * (18.0 + math.sin(animProgress * 2 * math.pi * 1.0 + i) * 4.0);
        final double lissajousY = math.sin(theta) * (16.0 + math.cos(animProgress * 2 * math.pi * 1.0 - i) * 4.0);
        final Offset linePos = Offset(center.dx + (i - 2) * lineSpacing, center.dy);
        final Offset orbitPos = center + Offset(lissajousX, lissajousY);
        final Offset lobeCenter = Offset.lerp(linePos, orbitPos, morphProgress)!;

        // Controlled fluid radius with 2.0x integer harmonic breathing wave
        final double baseRadius = Tween<double>(begin: 3.0, end: 38.0).transform(morphProgress);
        final double breathing = math.sin((animProgress * 2 * math.pi * 2.0) + (i * 1.3)) * 4.5 * morphProgress;
        final double lobeRadius = baseRadius + breathing;

        // Generate undulating organic fluid path (harmonic contour with integer wave cycles)
        final Path lobePath = Path();
        const int vertices = 16;
        for (int v = 0; v <= vertices; v++) {
          final double angle = (v / vertices) * 2 * math.pi;
          final double wave1 = math.sin((angle * 2.0) + (animProgress * 2 * math.pi * 2.0) + i) * 0.16;
          final double wave2 = math.cos((angle * 3.0) - (animProgress * 2 * math.pi * 1.0) + (i * 0.8)) * 0.10;
          final double r = lobeRadius * (1.0 + (wave1 + wave2) * morphProgress);
          final double vx = lobeCenter.dx + r * math.cos(angle);
          final double vy = lobeCenter.dy + r * math.sin(angle);
          if (v == 0) {
            lobePath.moveTo(vx, vy);
          } else {
            lobePath.lineTo(vx, vy);
          }
        }
        lobePath.close();

        // Multi-stop radial gradient for silky fluid density
        final lobePaint = Paint()
          ..shader = RadialGradient(
            center: Alignment(
              -0.20 * math.cos(theta),
              -0.20 * math.sin(theta),
            ),
            radius: 0.90,
            colors: [
              profile.highlight.withValues(alpha: 0.82 * morphProgress),
              profile.core.withValues(alpha: 0.62 * morphProgress),
              profile.ambient.withValues(alpha: 0.22 * morphProgress),
              profile.core.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.42, 0.75, 1.0],
          ).createShader(Rect.fromCircle(center: lobeCenter, radius: lobeRadius * 1.2))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 * morphProgress);

        canvas.drawPath(lobePath, lobePaint);
      }

      // 2. CURVING FLUID SILK RIBBONS (with 1.0x integer revolution and synchronous sweep)
      final ribbonProgress = (morphProgress - 0.15).clamp(0.0, 0.85) / 0.85;
      if (ribbonProgress > 0.02) {
        final double ribbonAngle = animProgress * 2 * math.pi * 1.0;
        final Path ribbon1 = Path();
        ribbon1.moveTo(
          center.dx + 42 * math.cos(ribbonAngle),
          center.dy + 42 * math.sin(ribbonAngle),
        );
        ribbon1.quadraticBezierTo(
          center.dx + 16 * math.cos(ribbonAngle + 1.8),
          center.dy + 16 * math.sin(ribbonAngle + 1.8),
          center.dx + 42 * math.cos(ribbonAngle + math.pi),
          center.dy + 42 * math.sin(ribbonAngle + math.pi),
        );

        final ribbonPaint1 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.0 * ribbonProgress
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: ribbonAngle,
            endAngle: ribbonAngle + (2 * math.pi),
            colors: [
              _profiles[0].highlight.withValues(alpha: 0.45 * ribbonProgress),
              _profiles[2].highlight.withValues(alpha: 0.45 * ribbonProgress),
              _profiles[3].highlight.withValues(alpha: 0.40 * ribbonProgress),
              _profiles[0].highlight.withValues(alpha: 0.45 * ribbonProgress),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 46.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 * ribbonProgress);

        canvas.drawPath(ribbon1, ribbonPaint1);
      }

      // 3. SPECULAR GLASS GLARE OVERLAY
      final glarePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.70,
          colors: [
            Colors.white.withValues(alpha: 0.35 * morphProgress),
            Colors.white.withValues(alpha: 0.08 * morphProgress),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: 54.0));
      canvas.drawCircle(center, 52.0, glarePaint);
    }

    // 4. THE 5 EQUALIZER NODES (SMOOTHLY FADE OUT DURING THINKING FLUID STATE)
    final double nodeOpacity = (1.0 - (morphProgress * 1.4)).clamp(0.0, 1.0);
    if (nodeOpacity > 0.01) {
      for (int i = 0; i < nodeCount; i++) {
        final double lineX = center.dx + (i - 2) * lineSpacing;
        final double lineY = center.dy;
        final currentCenter = Offset(lineX, lineY);

        final double targetHeight = barHeights[i];
        final Color nodeColor = isMuted
            ? const Color(0xFF94A3B8).withValues(alpha: nodeOpacity)
            : _defaultIndigo.withValues(alpha: nodeOpacity);

        final rRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: currentCenter,
            width: barWidth,
            height: targetHeight.clamp(barWidth, 60.0),
          ),
          const Radius.circular(999),
        );

        final nodePaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rRect, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceNodesMorphPainter oldDelegate) {
    if (oldDelegate.morphProgress != morphProgress ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.isThinking != isThinking ||
        oldDelegate.isMuted != isMuted) {
      return true;
    }
    if (oldDelegate.barHeights.length != barHeights.length) return true;
    for (int i = 0; i < barHeights.length; i++) {
      if ((oldDelegate.barHeights[i] - barHeights[i]).abs() > 0.1) {
        return true;
      }
    }
    return false;
  }
}

/// CustomPainter that renders radial frequency audio equalizer bars around the orb perimeter,
/// matching the exact visual style from the reference video (istockphoto-2265409964).
/// When silent, all radial bars shrink to zero / tiny baseline dots.
class RadialFrequencyBarsPainter extends CustomPainter {
  final double animationProgress;
  final double soundLevel;
  final bool isAiSpeaking;
  final bool isMuted;

  RadialFrequencyBarsPainter({
    required this.animationProgress,
    required this.soundLevel,
    required this.isAiSpeaking,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isMuted || !isAiSpeaking) return;

    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 89.0; // Starts right at outer perimeter of the 174px orb
    const totalPoints = 72; // High resolution points around 360 degrees for silky curves

    final double masterIntensity = (soundLevel * 1.15).clamp(0.0, 1.0);
    if (masterIntensity <= 0.01) return;

    final points = <Offset>[];
    final innerEchoPoints = <Offset>[];

    for (int i = 0; i < totalPoints; i++) {
      final double theta = (i / totalPoints) * 2 * math.pi;

      final double harmonicCluster1 = math.sin(theta * 2.0 - 0.5);
      final double harmonicCluster2 = math.cos(theta * 3.0 + 1.2);
      final double clusterFactor = ((harmonicCluster1 * 0.7 + harmonicCluster2 * 0.3).abs()).clamp(0.0, 1.0);

      final double freqJitter = ((math.sin((i * 7.7) + (animationProgress * 2 * math.pi * 5.0)) + 1.0) / 2.0);

      final double spikeFactor = math.pow(clusterFactor, 2.2).toDouble();
      final double dynamicHeight = (masterIntensity * 42.0 * (0.25 + (spikeFactor * 0.75))) * (0.6 + freqJitter * 0.4);

      final double barLength = 2.0 + dynamicHeight;
      final double currentRadius = baseRadius + barLength;

      final double endX = center.dx + currentRadius * math.cos(theta);
      final double endY = center.dy + currentRadius * math.sin(theta);
      points.add(Offset(endX, endY));

      // Subtle inner harmonic wave for depth
      final double innerRadius = baseRadius + (barLength * 0.5);
      final double innerX = center.dx + innerRadius * math.cos(theta);
      final double innerY = center.dy + innerRadius * math.sin(theta);
      innerEchoPoints.add(Offset(innerX, innerY));
    }

    // 1. Build Outer Wavy Path (Smooth closed quadratic bezier)
    final outerPath = Path();
    final n = points.length;
    final firstMid = Offset(
      (points[n - 1].dx + points[0].dx) / 2,
      (points[n - 1].dy + points[0].dy) / 2,
    );
    outerPath.moveTo(firstMid.dx, firstMid.dy);

    for (int i = 0; i < n; i++) {
      final next = points[(i + 1) % n];
      final mid = Offset(
        (points[i].dx + next.dx) / 2,
        (points[i].dy + next.dy) / 2,
      );
      outerPath.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    outerPath.close();

    // 2. Build Inner Echo Wavy Path
    final innerPath = Path();
    final innerFirstMid = Offset(
      (innerEchoPoints[n - 1].dx + innerEchoPoints[0].dx) / 2,
      (innerEchoPoints[n - 1].dy + innerEchoPoints[0].dy) / 2,
    );
    innerPath.moveTo(innerFirstMid.dx, innerFirstMid.dy);

    for (int i = 0; i < n; i++) {
      final next = innerEchoPoints[(i + 1) % n];
      final mid = Offset(
        (innerEchoPoints[i].dx + next.dx) / 2,
        (innerEchoPoints[i].dy + next.dy) / 2,
      );
      innerPath.quadraticBezierTo(innerEchoPoints[i].dx, innerEchoPoints[i].dy, mid.dx, mid.dy);
    }
    innerPath.close();

    final bounds = Rect.fromCircle(center: center, radius: baseRadius + 48.0);

    // Render soft glowing backdrop for the wavy perimeter
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = const Color(0xFFA855F7).withValues(alpha: (0.35 * masterIntensity).clamp(0.0, 0.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawPath(outerPath, glowPaint);

    // Render inner echo wave
    final echoPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFC084FC).withValues(alpha: (0.35 * masterIntensity).clamp(0.0, 0.5));
    canvas.drawPath(innerPath, echoPaint);

    // Render crisp primary wavy outer line with sweeping gradient
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.4
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFA855F7), // Purple
          Color(0xFFE879F9), // Fuchsia / Magenta
          Color(0xFF818CF8), // Indigo / Violet
          Color(0xFFA855F7), // Purple loop
        ],
      ).createShader(bounds);

    canvas.drawPath(outerPath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant RadialFrequencyBarsPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.soundLevel != soundLevel ||
        oldDelegate.isAiSpeaking != isAiSpeaking ||
        oldDelegate.isMuted != isMuted;
  }
}

import 'package:flutter/material.dart';

class _RippleBurst {
  final Offset origin;
  final AnimationController controller;

  const _RippleBurst({required this.origin, required this.controller});
}

/// Optional calm tap ripple overlay inside the breathing canvas.
/// Uses a bounded ripple pool and `IgnorePointer` so controls remain unobstructed.
class BreathingTouchRipple extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const BreathingTouchRipple({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<BreathingTouchRipple> createState() => _BreathingTouchRippleState();
}

class _BreathingTouchRippleState extends State<BreathingTouchRipple>
    with TickerProviderStateMixin {
  static const int _maxRipples = 4;
  final List<_RippleBurst> _ripples = [];

  @override
  void dispose() {
    for (final ripple in _ripples) {
      ripple.controller.dispose();
    }
    _ripples.clear();
    super.dispose();
  }

  void _spawnRipple(Offset localPosition) {
    if (!widget.enabled || !mounted) return;
    if (_ripples.length >= _maxRipples) {
      final oldest = _ripples.removeAt(0);
      oldest.controller.dispose();
    }

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    final burst = _RippleBurst(origin: localPosition, controller: controller);

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _ripples.remove(burst);
        });
        controller.dispose();
      }
    });

    setState(() {
      _ripples.add(burst);
    });
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _spawnRipple(event.localPosition),
          child: widget.child,
        ),
        if (widget.enabled && _ripples.isNotEmpty)
          IgnorePointer(
            child: CustomPaint(
              painter: _TouchRipplePainter(
                ripples: List.unmodifiable(_ripples),
                repaintListenable: Listenable.merge(
                  _ripples.map((r) => r.controller).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TouchRipplePainter extends CustomPainter {
  final List<_RippleBurst> ripples;

  _TouchRipplePainter({
    required this.ripples,
    required Listenable repaintListenable,
  }) : super(repaint: repaintListenable);

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final t = Curves.easeOutCubic.transform(ripple.controller.value);
      final radius = 14.0 + 76.0 * t;
      final alpha = (1.0 - t) * 0.26;
      if (alpha <= 0.01) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFD9C8FF).withValues(alpha: alpha);
      canvas.drawCircle(ripple.origin, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchRipplePainter oldDelegate) {
    return oldDelegate.ripples != ripples;
  }
}

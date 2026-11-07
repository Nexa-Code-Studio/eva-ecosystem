import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/tutorial_step.dart';
import 'branded_guidance_card.dart';

/// An interactive, branded spotlight overlay for Eva AI.
/// Renders a dimmed, calming backdrop with an exact cutout around the target widget,
/// soft ambient halo ring, and a dynamically positioned [BrandedGuidanceCard].
///
/// Uses standard declarative Flutter layers:
/// 1. Fullscreen modal backdrop capturing taps outside the target.
/// 2. Direct tap target over the cutout hole invoking [onTargetTap].
/// 3. Dynamically positioned guidance card with action cues and skip option.
class InteractiveSpotlightOverlay extends StatefulWidget {
  final GlobalKey? targetKey;
  final Rect? targetRect;
  final TutorialContent content;
  final VoidCallback onSkip;
  final VoidCallback? onTargetTap;
  final VoidCallback? onNext;
  final double cutoutPadding;

  const InteractiveSpotlightOverlay({
    super.key,
    this.targetKey,
    this.targetRect,
    required this.content,
    required this.onSkip,
    this.onTargetTap,
    this.onNext,
    this.cutoutPadding = 8.0,
  });

  @override
  State<InteractiveSpotlightOverlay> createState() =>
      _InteractiveSpotlightOverlayState();
}

class _InteractiveSpotlightOverlayState extends State<InteractiveSpotlightOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _haloController;
  Rect? _measuredTargetRect;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scheduleMeasurement();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final disableAnimations =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (disableAnimations) {
          _fadeController.value = 1.0;
        } else {
          _fadeController.forward();
          _haloController.repeat(reverse: true);
        }
      }
    });
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateTargetMeasurement();
      // Retry in subsequent frame if target is still mounting or laying out or measured invalid
      if ((_measuredTargetRect == null || _measuredTargetRect!.top < 0) &&
          widget.targetKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateTargetMeasurement();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.targetRect != widget.targetRect) {
      _scheduleMeasurement();
    }
  }

  void _updateTargetMeasurement() {
    if (!mounted) return;

    if (widget.targetRect != null) {
      if (_measuredTargetRect != widget.targetRect) {
        setState(() {
          _measuredTargetRect = widget.targetRect;
        });
      }
      return;
    }

    if (widget.targetKey == null) return;

    final targetContext = widget.targetKey!.currentContext;
    if (targetContext == null) return;

    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.attached) {
      final overlayBox = context.findRenderObject() as RenderBox?;
      final Offset offset;
      if (overlayBox != null && overlayBox.attached) {
        offset = overlayBox.globalToLocal(renderBox.localToGlobal(Offset.zero));
      } else {
        offset = renderBox.localToGlobal(Offset.zero);
      }

      final rect = offset & renderBox.size;

      if (rect.top >= 0 && _measuredTargetRect != rect) {
        setState(() {
          _measuredTargetRect = rect;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((_measuredTargetRect == null || _measuredTargetRect!.top < 0) &&
        widget.targetKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateTargetMeasurement();
      });
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Use measured rect if available, or compute fallback for center button on frame 0
    final effectiveTargetRect = _measuredTargetRect ??
        widget.targetRect ??
        (widget.content.shape == SpotlightShape.circle
            ? Rect.fromCircle(
                center: Offset(screenSize.width / 2, screenSize.height - 59),
                radius: 29,
              )
            : null);

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeController, _haloController]),
      builder: (context, _) {
        final opacity = _fadeController.value;
        final haloValue = _haloController.value;

        if (opacity <= 0.0) return const SizedBox.shrink();

        return Opacity(
          opacity: opacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Fullscreen Dimmed Backdrop (Absorbs taps outside target hole)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onTap: () {
                    // Absorbs taps on dimmed area so background buttons cannot be accidentally clicked
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SpotlightCutoutPainter(
                      targetRect: effectiveTargetRect,
                      shape: widget.content.shape,
                      padding: widget.cutoutPadding,
                      haloOpacity: 0.35 + (0.30 * haloValue),
                    ),
                  ),
                ),
              ),

              // 2. Direct Tap Target for the Highlighted Control (Optional explicit handler)
              if (widget.onTargetTap != null && effectiveTargetRect != null)
                Positioned.fromRect(
                  rect: effectiveTargetRect.inflate(widget.cutoutPadding),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: widget.onTargetTap,
                  ),
                ),

              // 3. Dynamically Positioned Guidance Card
              if (effectiveTargetRect != null)
                _buildPositionedCard(effectiveTargetRect),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionedCard(Rect targetRect) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    const double cardMaxWidth = 360.0;
    final double cardWidth = math.min(screenSize.width - 32.0, cardMaxWidth);

    // Calculate vertical placement
    final double spaceAbove = targetRect.top - safePadding.top;
    final double spaceBelow =
        screenSize.height - safePadding.bottom - targetRect.bottom;

    // Prefer placing card on the side with more space
    final bool placeAbove = spaceAbove >= spaceBelow || spaceAbove >= 220;

    // Horizontal placement: Center card relative to target, clamped to screen safe bounds
    final double targetCenterX = targetRect.center.dx;
    double cardLeft = targetCenterX - (cardWidth / 2);
    final double minLeft = safePadding.left + 16.0;
    final double maxLeft = screenSize.width - safePadding.right - 16.0 - cardWidth;
    cardLeft = cardLeft.clamp(minLeft, math.max(minLeft, maxLeft));

    // Pointer offset relative to card center
    final double cardCenterX = cardLeft + (cardWidth / 2);
    final double pointerOffset = (targetCenterX - cardCenterX).clamp(
      -(cardWidth / 2) + 28.0,
      (cardWidth / 2) - 28.0,
    );

    const double gapToCutout = 10.0;

    return Positioned(
      left: cardLeft,
      width: cardWidth,
      top: placeAbove ? null : targetRect.bottom + widget.cutoutPadding + gapToCutout,
      bottom: placeAbove
          ? (screenSize.height - targetRect.top) + widget.cutoutPadding + gapToCutout
          : null,
      child: SafeArea(
        top: !placeAbove,
        bottom: placeAbove,
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: BrandedGuidanceCard(
            title: widget.content.title,
            description: widget.content.description,
            actionHint: widget.content.actionHint,
            badgeText: widget.content.badgeText,
            pointerDirection:
                placeAbove ? PointerDirection.down : PointerDirection.up,
            pointerHorizontalOffset: pointerOffset,
            isInteractiveTarget: widget.content.isInteractiveTarget,
            onSkip: widget.onSkip,
            onNext: widget.onNext,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the dimmed backdrop, cutout, and ambient halo glow ring.
class _SpotlightCutoutPainter extends CustomPainter {
  final Rect? targetRect;
  final SpotlightShape shape;
  final double padding;
  final double haloOpacity;

  _SpotlightCutoutPainter({
    required this.targetRect,
    required this.shape,
    required this.padding,
    required this.haloOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null) {
      // If no target, simply paint dim overlay
      canvas.drawPath(
        screenPath,
        Paint()..color = const Color(0xFF0F1123).withValues(alpha: 0.72),
      );
      return;
    }

    final Path holePath = Path();
    if (shape == SpotlightShape.circle) {
      final center = targetRect!.center;
      final radius =
          (math.max(targetRect!.width, targetRect!.height) / 2) + padding;
      holePath.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      final rect = targetRect!.inflate(padding);
      holePath.addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      );
    }

    // Cutout difference path
    final cutoutPath = Path.combine(PathOperation.difference, screenPath, holePath);

    // 1. Draw dimmed backdrop
    canvas.drawPath(
      cutoutPath,
      Paint()
        ..color = const Color(0xFF0F1123).withValues(alpha: 0.72)
        ..style = PaintingStyle.fill,
    );

    // 2. Draw subtle ambient halo ring around hole
    final haloGlowPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: haloOpacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(holePath, haloGlowPaint);

    // 3. Draw clean crisp highlight border on hole edge
    final borderPaint = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: haloOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(holePath, borderPaint);
  }

  @override
  bool? hitTest(Offset position) {
    if (targetRect == null) return true;
    final holeRect = shape == SpotlightShape.circle
        ? Rect.fromCircle(
            center: targetRect!.center,
            radius: (math.max(targetRect!.width, targetRect!.height) / 2) + padding,
          )
        : targetRect!.inflate(padding);

    if (holeRect.contains(position)) {
      return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant _SpotlightCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.shape != shape ||
        oldDelegate.padding != padding ||
        oldDelegate.haloOpacity != haloOpacity;
  }
}

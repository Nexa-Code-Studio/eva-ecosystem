import 'dart:async';
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
  final GlobalKey? secondaryTargetKey;
  final Rect? secondaryTargetRect;
  final TutorialContent content;
  final VoidCallback onSkip;
  final VoidCallback? onTargetTap;
  final VoidCallback? onNext;
  final double cutoutPadding;

  const InteractiveSpotlightOverlay({
    super.key,
    this.targetKey,
    this.targetRect,
    this.secondaryTargetKey,
    this.secondaryTargetRect,
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
  Rect? _measuredSecondaryTargetRect;
  Timer? _pollingTimer;

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
    _pollingTimer?.cancel();

    void measure() {
      if (!mounted) return;
      _updateTargetMeasurement();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      measure();
      if ((_measuredTargetRect == null || _measuredTargetRect!.top < 0) &&
          widget.targetKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => measure());
      }
    });

    int attempts = 0;
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      attempts++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateTargetMeasurement();
      // Keep tracking for up to 20 frames (1s) to accommodate page scroll and layout changes
      if (attempts >= 20) {
        timer.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.targetRect != widget.targetRect ||
        oldWidget.secondaryTargetKey != widget.secondaryTargetKey ||
        oldWidget.secondaryTargetRect != widget.secondaryTargetRect) {
      _measuredTargetRect = null;
      _measuredSecondaryTargetRect = null;
      _scheduleMeasurement();
    }
  }

  Rect? _measureKey(GlobalKey? key) {
    if (key == null) return null;

    final targetContext = key.currentContext;
    if (targetContext == null) return null;

    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.attached && renderBox.hasSize) {
      final size = renderBox.size;
      if (size.width <= 0 || size.height <= 0) return null;

      final overlayBox = context.findRenderObject() as RenderBox?;
      final Offset offset;
      if (overlayBox != null && overlayBox.attached) {
        offset = overlayBox.globalToLocal(renderBox.localToGlobal(Offset.zero));
      } else {
        offset = renderBox.localToGlobal(Offset.zero);
      }

      final mediaQuery = MediaQuery.of(context);
      final screenSize = mediaQuery.size;

      final rect = offset & size;

      // Validate that target widget has rendered dimensions and is within screen boundaries
      if (rect.right <= 0 ||
          rect.left >= screenSize.width ||
          rect.bottom <= 0 ||
          rect.top >= screenSize.height) {
        return null;
      }

      return rect;
    }
    return null;
  }

  void _updateTargetMeasurement() {
    if (!mounted) return;

    final primary = widget.targetRect ?? _measureKey(widget.targetKey);
    final secondary =
        widget.secondaryTargetRect ?? _measureKey(widget.secondaryTargetKey);

    if (_measuredTargetRect != primary ||
        _measuredSecondaryTargetRect != secondary) {
      setState(() {
        _measuredTargetRect = primary;
        _measuredSecondaryTargetRect = secondary;
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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

    final effectiveSecondaryRect =
        _measuredSecondaryTargetRect ?? widget.secondaryTargetRect;

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
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Absorbs taps on dimmed area so background buttons cannot be accidentally clicked
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SpotlightCutoutPainter(
                      targetRect: effectiveTargetRect,
                      secondaryTargetRect: effectiveSecondaryRect,
                      shape: widget.content.shape,
                      padding: widget.cutoutPadding,
                      haloOpacity: 0.35 + (0.30 * haloValue),
                    ),
                  ),
                ),
              ),

              // 2. Direct Tap Target for the Highlighted Control(s)
              if (widget.onTargetTap != null) ...[
                if (effectiveTargetRect != null)
                  Positioned.fromRect(
                    rect: effectiveTargetRect.inflate(widget.cutoutPadding),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: widget.onTargetTap,
                    ),
                  ),
                if (effectiveSecondaryRect != null)
                  Positioned.fromRect(
                    rect: effectiveSecondaryRect.inflate(widget.cutoutPadding),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: widget.onTargetTap,
                    ),
                  ),
              ],

              // 3. Dynamically Positioned Guidance Card (Always rendered!)
              _buildPositionedCard(effectiveTargetRect),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionedCard(Rect? targetRect) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    const double cardMaxWidth = 360.0;
    final double cardWidth = math.min(screenSize.width - 32.0, cardMaxWidth);
    final double minLeft = safePadding.left + 16.0;

    if (targetRect == null) {
      // Safe fallback when target is still mounting or asynchronous data is loading:
      // Always render card safely at bottom so user is NEVER blocked by a black screen!
      final double cardLeft = ((screenSize.width - cardWidth) / 2).clamp(minLeft, screenSize.width - cardWidth);
      return Positioned(
        left: cardLeft,
        width: cardWidth,
        bottom: math.max(safePadding.bottom + 80.0, 100.0),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: BrandedGuidanceCard(
              title: widget.content.title,
              description: widget.content.description,
              actionHint: widget.content.actionHint,
              badgeText: widget.content.badgeText,
              pointerDirection: PointerDirection.none,
              isInteractiveTarget: widget.content.isInteractiveTarget,
              nextButtonLabel: widget.content.nextButtonLabel,
              onSkip: widget.onSkip,
              onNext: widget.onNext,
            ),
          ),
        ),
      );
    }

    // Calculate vertical placement
    final double spaceAbove = targetRect.top - safePadding.top;
    final double spaceBelow =
        screenSize.height - safePadding.bottom - targetRect.bottom;

    // Prefer placing card below target; only place above if not enough space below AND more space above
    final bool placeAbove = (spaceBelow < 280 && spaceAbove > spaceBelow);

    // Horizontal placement: Center card relative to target, clamped to screen safe bounds
    final double targetCenterX = targetRect.center.dx;
    double cardLeft = targetCenterX - (cardWidth / 2);
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
        bottom: true,
        minimum: const EdgeInsets.only(left: 4, right: 4, bottom: 20),
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
            nextButtonLabel: widget.content.nextButtonLabel,
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
  final Rect? secondaryTargetRect;
  final SpotlightShape shape;
  final double padding;
  final double haloOpacity;

  _SpotlightCutoutPainter({
    required this.targetRect,
    this.secondaryTargetRect,
    required this.shape,
    required this.padding,
    required this.haloOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect == null && secondaryTargetRect == null) {
      // While measuring or waiting for target to mount, paint a subtle translucent dim
      // instead of solid black, so the user clearly sees the screen loading underneath
      canvas.drawPath(
        screenPath,
        Paint()..color = const Color(0xFF0F1123).withValues(alpha: 0.35),
      );
      return;
    }

    final Path holePath = Path();

    if (targetRect != null) {
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
    }

    if (secondaryTargetRect != null) {
      final rect = secondaryTargetRect!.inflate(padding);
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

    // 2. Draw subtle ambient halo ring around hole(s)
    final haloGlowPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: haloOpacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(holePath, haloGlowPaint);

    // 3. Draw clean crisp highlight border on hole edge(s)
    final borderPaint = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: haloOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(holePath, borderPaint);
  }

  @override
  bool? hitTest(Offset position) {
    if (targetRect == null && secondaryTargetRect == null) return true;

    if (targetRect != null) {
      final holeRect = shape == SpotlightShape.circle
          ? Rect.fromCircle(
              center: targetRect!.center,
              radius: (math.max(targetRect!.width, targetRect!.height) / 2) + padding,
            )
          : targetRect!.inflate(padding);

      if (holeRect.contains(position)) {
        return false;
      }
    }

    if (secondaryTargetRect != null) {
      final secondaryHoleRect = secondaryTargetRect!.inflate(padding);
      if (secondaryHoleRect.contains(position)) {
        return false;
      }
    }

    return true;
  }

  @override
  bool shouldRepaint(covariant _SpotlightCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.secondaryTargetRect != secondaryTargetRect ||
        oldDelegate.shape != shape ||
        oldDelegate.padding != padding ||
        oldDelegate.haloOpacity != haloOpacity;
  }
}

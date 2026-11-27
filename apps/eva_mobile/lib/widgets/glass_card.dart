import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature container following DESIGN.md:
/// - Default `GlassCard` for focal glass plates (1-2 accent elements per screen).
/// - `GlassCard.surface` for routine list cards without stacked glass blur/opacity.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 24.0,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.onTap,
    this.enableBlur = false,
  });

  /// Clean solid surface card for standard list items and secondary sections.
  const GlassCard.surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 20.0,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.borderSoft,
    this.width,
    this.height,
    this.onTap,
  }) : enableBlur = false;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = BorderRadius.circular(borderRadius);
    final cardDecoration = BoxDecoration(
      color: backgroundColor ?? AppColors.glassBackground,
      borderRadius: effectiveRadius,
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: 1.2,
      ),
      boxShadow: const [
        BoxShadow(
          color: AppColors.glassShadow,
          blurRadius: 24,
          spreadRadius: 0,
          offset: Offset(0, 8),
        ),
      ],
    );

    Widget buildInner(Widget innerChild) {
      if (onTap == null) return innerChild;
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: innerChild,
        ),
      );
    }

    Widget cardContent;

    if (enableBlur) {
      cardContent = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            height: height,
            decoration: cardDecoration,
            child: buildInner(
              Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ),
      );
    } else {
      cardContent = Container(
        width: width,
        height: height,
        decoration: cardDecoration,
        child: buildInner(
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: cardContent);
    }

    return cardContent;
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? customBorder;
  final bool useBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20.0,
    this.onTap,
    this.backgroundColor,
    this.customBorder,
    this.useBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceBox = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? (useBlur ? AppColors.glassBackground : AppColors.surface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: customBorder ??
            Border.all(
              color: useBlur ? AppColors.glassBorder : AppColors.cardBorder,
              width: 1.0,
            ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );

    if (!useBlur) {
      return surfaceBox;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: surfaceBox,
      ),
    );
  }
}

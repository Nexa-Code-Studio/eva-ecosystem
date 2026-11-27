import 'package:flutter/material.dart';

import 'package:eva_mobile/theme/app_colors.dart';

/// Standardized Circular Frosted Back Button for Eva Mobile (>= 44px touch target).
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isDark;
  final IconData icon;
  final double iconSize;
  final double size;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.isDark = false,
    this.icon = Icons.arrow_back_rounded,
    this.iconSize = 20.0,
    this.size = 44.0,
    this.tooltip = 'Kembali',
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  /// Factory constructor optimized for dark backgrounds and gradients (e.g. VoiceCallScreen).
  const AppBackButton.dark({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back_rounded,
    this.iconSize = 20.0,
    this.size = 44.0,
    this.tooltip = 'Kembali',
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  }) : isDark = true;

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.9));
    final effectiveBorderColor = borderColor ??
        (isDark ? Colors.white.withValues(alpha: 0.25) : AppColors.borderSoft);
    final effectiveIconColor =
        iconColor ?? (isDark ? Colors.white : AppColors.textPrimary);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        shape: BoxShape.circle,
        border: Border.all(color: effectiveBorderColor),
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize, color: effectiveIconColor),
        color: effectiveIconColor,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: size / 2,
        tooltip: tooltip,
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}

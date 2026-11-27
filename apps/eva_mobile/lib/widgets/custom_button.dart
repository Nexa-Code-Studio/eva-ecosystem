import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Primary custom button with accessible >= 44px height, configurable radius,
/// loading state, and outline style.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutline;
  final bool isLoading;
  final IconData? suffixIcon;
  final IconData? prefixIcon;
  final double height;
  final double? width;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isOutline = false,
    this.isLoading = false,
    this.suffixIcon,
    this.prefixIcon,
    this.height = 52.0,
    this.width,
    this.borderRadius = 24.0,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height < 44.0 ? 44.0 : height;
    final effectiveBgColor =
        backgroundColor ?? (isOutline ? Colors.transparent : AppColors.primary);
    final effectiveFgColor =
        textColor ?? (isOutline ? AppColors.primary : Colors.white);

    return SizedBox(
      width: width ?? double.infinity,
      height: effectiveHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBgColor,
          foregroundColor: effectiveFgColor,
          disabledBackgroundColor: isOutline
              ? AppColors.surfaceLow
              : AppColors.primary.withValues(alpha: 0.55),
          disabledForegroundColor: isOutline
              ? AppColors.textSecondary.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.9),
          elevation: isOutline ? 0 : 2,
          shadowColor: AppColors.glassShadow,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: isOutline
                ? BorderSide(
                    color: backgroundColor ?? AppColors.primary,
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveFgColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: 20, color: effectiveFgColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: effectiveFgColor,
                      ),
                    ),
                  ),
                  if (suffixIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(suffixIcon, size: 20, color: effectiveFgColor),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Full-pill primary CTA button delegating to [CustomButton] to avoid logic duplication.
class CustomPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutline;
  final bool isLoading;
  final IconData? suffixIcon;
  final double height;

  const CustomPillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutline = false,
    this.isLoading = false,
    this.suffixIcon,
    this.height = 54.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isOutline: isOutline,
      isLoading: isLoading,
      suffixIcon: suffixIcon,
      height: height,
      borderRadius: 999.0,
    );
  }
}

class SocialPillButton extends StatelessWidget {
  final String type; // 'google' or 'apple'
  final VoidCallback onPressed;

  const SocialPillButton({
    super.key,
    required this.type,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isGoogle = type == 'google';
    final label = isGoogle ? 'Google' : 'Apple';
    final iconData = isGoogle ? Icons.g_mobiledata : Icons.apple;

    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.borderSoft, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, color: AppColors.textPrimary, size: isGoogle ? 28 : 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

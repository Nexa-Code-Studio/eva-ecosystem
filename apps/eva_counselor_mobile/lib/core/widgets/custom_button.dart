import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ButtonVariant { primary, secondary, outline, danger }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double height;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.height = 50.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case ButtonVariant.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case ButtonVariant.secondary:
        bg = AppColors.primaryContainer;
        fg = AppColors.primary;
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.primary;
        border = Border.all(color: AppColors.primary, width: 1.5);
        break;
      case ButtonVariant.danger:
        bg = AppColors.error;
        fg = Colors.white;
        break;
    }

    final disabled = onPressed == null || isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: disabled ? bg.withOpacity(0.5) : bg,
        borderRadius: BorderRadius.circular(16.0),
        border: border,
        boxShadow: variant == ButtonVariant.primary && !disabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: disabled ? null : onPressed,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: fg, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTypography.headingSmall.copyWith(
                          color: fg,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

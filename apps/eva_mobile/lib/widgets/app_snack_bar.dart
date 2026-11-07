import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Semantic variants for application-wide snackbars.
enum SnackBarVariant {
  primary,
  success,
  warning,
  danger,
}

/// Standardized, stylish floating SnackBar utility for Eva Mobile.
class AppSnackBar {
  const AppSnackBar._();

  /// Resolve background color based on variant.
  static Color getBackgroundColor(SnackBarVariant variant) {
    switch (variant) {
      case SnackBarVariant.primary:
        return AppColors.primary;
      case SnackBarVariant.success:
        return const Color(0xFF10B981); // Emerald
      case SnackBarVariant.warning:
        return const Color(0xFFF59E0B); // Amber
      case SnackBarVariant.danger:
        return const Color(0xFFDC2626); // Crimson
    }
  }

  /// Resolve default leading icon based on variant.
  static IconData getDefaultIcon(SnackBarVariant variant) {
    switch (variant) {
      case SnackBarVariant.primary:
        return Icons.auto_awesome_rounded;
      case SnackBarVariant.success:
        return Icons.check_circle_outline_rounded;
      case SnackBarVariant.warning:
        return Icons.warning_amber_rounded;
      case SnackBarVariant.danger:
        return Icons.error_outline_rounded;
    }
  }

  /// Builds a standardized floating [SnackBar] widget.
  static SnackBar create({
    required String message,
    SnackBarVariant variant = SnackBarVariant.primary,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Widget? leading,
  }) {
    return SnackBar(
      content: Row(
        children: [
          leading ??
              Icon(
                icon ?? getDefaultIcon(variant),
                color: Colors.white,
                size: 18,
              ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: getBackgroundColor(variant),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: duration,
      action: action,
    );
  }

  /// Shows the SnackBar on the given [BuildContext].
  static void show(
    BuildContext context, {
    required String message,
    SnackBarVariant variant = SnackBarVariant.primary,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Widget? leading,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      create(
        message: message,
        variant: variant,
        icon: icon,
        duration: duration,
        action: action,
        leading: leading,
      ),
    );
  }

  /// Shows the SnackBar on a pre-captured [ScaffoldMessengerState] (useful across async gaps).
  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    SnackBarVariant variant = SnackBarVariant.primary,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Widget? leading,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      create(
        message: message,
        variant: variant,
        icon: icon,
        duration: duration,
        action: action,
        leading: leading,
      ),
    );
  }

  /// Quick helper for Success notification (Emerald green).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      variant: SnackBarVariant.success,
      duration: duration,
      icon: icon,
      action: action,
    );
  }

  /// Quick helper for Warning notification (Amber).
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      variant: SnackBarVariant.warning,
      duration: duration,
      icon: icon,
      action: action,
    );
  }

  /// Quick helper for Error/Danger notification (Crimson red).
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      variant: SnackBarVariant.danger,
      duration: duration,
      icon: icon,
      action: action,
    );
  }

  /// Quick helper for Primary notification (Periwinkle).
  static void showPrimary(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    SnackBarAction? action,
    Widget? leading,
  }) {
    show(
      context,
      message: message,
      variant: SnackBarVariant.primary,
      duration: duration,
      icon: icon,
      action: action,
      leading: leading,
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shared loading, empty, and error state presenter with actionable recovery.
class AppAsyncStateView extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const AppAsyncStateView._({
    super.key,
    required this.iconWidget,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  factory AppAsyncStateView.loading({
    Key? key,
    String title = 'Memuat data...',
    String message = 'Mohon tunggu sebentar.',
    bool compact = false,
  }) {
    return AppAsyncStateView._(
      key: key,
      compact: compact,
      iconWidget: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
      title: title,
      message: message,
    );
  }

  factory AppAsyncStateView.error({
    Key? key,
    String title = 'Gagal memuat data',
    String message = 'Terjadi gangguan saat mengambil data. Silakan coba lagi.',
    String actionLabel = 'Muat Ulang',
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return AppAsyncStateView._(
      key: key,
      compact: compact,
      iconWidget: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.highRiskBg,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          color: AppColors.highRiskRed,
          size: 22,
        ),
      ),
      title: title,
      message: message,
      actionLabel: onRetry != null ? actionLabel : null,
      onAction: onRetry,
    );
  }

  factory AppAsyncStateView.empty({
    Key? key,
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
  }) {
    return AppAsyncStateView._(
      key: key,
      compact: compact,
      iconWidget: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 22,
        ),
      ),
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 20 : 28,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headingSmall.copyWith(fontSize: 14.5),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(fontSize: 12.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(actionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

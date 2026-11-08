import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.verified([String label = 'Terverifikasi']) {
    return StatusBadge(
      label: label,
      backgroundColor: AppColors.verifiedBg,
      textColor: AppColors.verifiedGreen,
      icon: Icons.verified_rounded,
    );
  }

  factory StatusBadge.pending([String label = 'Menunggu Verifikasi']) {
    return StatusBadge(
      label: label,
      backgroundColor: AppColors.pendingBg,
      textColor: AppColors.pendingAmber,
      icon: Icons.hourglass_top_rounded,
    );
  }

  factory StatusBadge.highRisk([String label = 'Perhatian Khusus']) {
    return StatusBadge(
      label: label,
      backgroundColor: AppColors.highRiskBg,
      textColor: AppColors.highRiskRed,
      icon: Icons.warning_amber_rounded,
    );
  }

  factory StatusBadge.consentGranted([String label = 'Izin Akses Diberikan']) {
    return StatusBadge(
      label: label,
      backgroundColor: AppColors.primaryContainer,
      textColor: AppColors.primary,
      icon: Icons.lock_open_rounded,
    );
  }

  factory StatusBadge.consentLocked([String label = 'Akses Terkunci']) {
    return StatusBadge(
      label: label,
      backgroundColor: Colors.black.withValues(alpha: 0.06),
      textColor: AppColors.textSecondary,
      icon: Icons.lock_outline_rounded,
    );
  }

  factory StatusBadge.volunteer([String label = 'Relawan Teman Sebaya']) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFE0F7F6),
      textColor: const Color(0xFF00796B),
      icon: Icons.volunteer_activism_rounded,
    );
  }

  factory StatusBadge.proIndependent([String label = 'Psikolog Mandiri']) {
    return StatusBadge(
      label: label,
      backgroundColor: AppColors.primaryContainer,
      textColor: AppColors.primary,
      icon: Icons.verified_user_rounded,
    );
  }

  factory StatusBadge.proPartner([String label = 'Psikolog Mitra']) {
    return StatusBadge(
      label: label,
      backgroundColor: const Color(0xFFF3E8FF),
      textColor: const Color(0xFF7E22CE),
      icon: Icons.apartment_rounded,
    );
  }

  factory StatusBadge.coins(int coins) {
    return StatusBadge(
      label: '$coins Koin',
      backgroundColor: const Color(0xFFFFF7ED),
      textColor: const Color(0xFFC2410C),
      icon: Icons.monetization_on_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

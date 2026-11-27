import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';

class SessionDurationStepper extends StatelessWidget {
  final int sessionCount;
  final int coinsPerSession;
  final ValueChanged<int> onChanged;
  final int minSessions;
  final int maxSessions;

  const SessionDurationStepper({
    super.key,
    required this.sessionCount,
    required this.coinsPerSession,
    required this.onChanged,
    this.minSessions = 1,
    this.maxSessions = 4,
  });

  @override
  Widget build(BuildContext context) {
    final totalMinutes = sessionCount * 30;
    final totalCoins = sessionCount * coinsPerSession;

    final canDecrease = sessionCount > minSessions;
    final canIncrease = sessionCount < maxSessions;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Info Sesi & Durasi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$sessionCount Sesi ($totalMinutes Menit)',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  coinsPerSession > 0
                      ? 'Total Biaya: $totalCoins Koin EVA ($coinsPerSession/sesi)'
                      : 'Konsultasi Gratis (Didanai Komunitas)',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: coinsPerSession > 0 ? AppColors.primary : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Right: Counter Stepper [-] [N] [+]
          Row(
            children: [
              _buildStepButton(
                icon: Icons.remove,
                isEnabled: canDecrease,
                tooltip: 'Kurangi Sesi',
                onTap: canDecrease ? () => onChanged(sessionCount - 1) : null,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                child: Text(
                  '$sessionCount',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStepButton(
                icon: Icons.add,
                isEnabled: canIncrease,
                tooltip: 'Tambah Sesi',
                onTap: canIncrease ? () => onChanged(sessionCount + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required bool isEnabled,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      enabled: isEnabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled ? AppColors.borderSubtle : AppColors.borderSoft,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

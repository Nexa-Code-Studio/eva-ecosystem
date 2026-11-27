import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/custom_button.dart';

/// Confirmation bottom sheet shown before starting a paid AI voice call session.
Future<bool> showAiCallStartConfirmSheet(
  BuildContext context, {
  required int coinBalance,
  required int coinsPerMinute,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mulai Telepon AI EVA?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sesi telepon AI memakai $coinsPerMinute Koin per menit dan diperpanjang otomatis tiap menit selama saldo mencukupi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFFFB300),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Saldo Koin Kamu',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$coinBalance Koin',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomPillButton(
                text: 'Mulai Telepon ($coinsPerMinute Koin/mnt)',
                suffixIcon: Icons.mic_rounded,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Bottom sheet shown when user lacks sufficient EVA Coins to start an AI voice call.
Future<void> showAiCallInsufficientCoinSheet(
  BuildContext context, {
  required int coinBalance,
  required int requiredCoins,
  required VoidCallback onTopUp,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFF8E1),
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFB300),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Saldo Koin Tidak Cukup',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Telepon AI membutuhkan minimal $requiredCoins Koin per menit. Saldo kamu saat ini $coinBalance Koin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              CustomPillButton(
                text: 'Isi Koin Sekarang',
                suffixIcon: Icons.add_circle_outline_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  onTopUp();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  'Tutup',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

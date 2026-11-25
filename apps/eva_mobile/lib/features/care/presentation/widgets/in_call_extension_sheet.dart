import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../domain/entities/extension_availability_entity.dart';

class InCallExtensionBanner extends StatelessWidget {
  final int remainingSeconds;
  final bool isChecking;
  final VoidCallback onExtendTap;
  final VoidCallback onDismiss;

  const InCallExtensionBanner({
    super.key,
    required this.remainingSeconds,
    required this.isChecking,
    required this.onExtendTap,
    required this.onDismiss,
  });

  String _formatRemaining(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_time_rounded,
              color: AppColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sisa waktu ${_formatRemaining(remainingSeconds)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Butuh waktu lebih? Tambah +30 menit tanpa putus',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const Key('in_call_extend_button'),
            onPressed: isChecking ? null : onExtendTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Tambah Sesi (+30 Menit)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
            padding: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(),
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }
}

class InCallExtensionConfirmDialog extends StatelessWidget {
  final int requiredCoins;
  final int currentBalance;
  final VoidCallback onConfirm;
  final VoidCallback onTopUp;

  const InCallExtensionConfirmDialog({
    super.key,
    required this.requiredCoins,
    required this.currentBalance,
    required this.onConfirm,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    final hasEnoughCoins = currentBalance >= requiredCoins;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Tambah Sesi (+30 Menit)',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jadwal 30 menit berikutnya tersedia. Sesi akan langsung diperpanjang menjadi 60 menit tanpa memutus video call.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Biaya Perpanjangan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$requiredCoins Koin EVA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo Koin Kamu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$currentBalance Koin EVA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: hasEnoughCoins
                            ? AppColors.successDark
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!hasEnoughCoins) ...[
            const SizedBox(height: 10),
            Text(
              'Saldo koin belum mencukupi untuk perpanjangan sesi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (hasEnoughCoins)
          ElevatedButton(
            key: const Key('confirm_extend_session_btn'),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Konfirmasi & Perpanjang',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          )
        else
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onTopUp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Top Up Koin',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class InCallExtensionBusySheet extends StatelessWidget {
  final ExtensionAvailabilityEntity availability;
  final VoidCallback onScheduleNext;

  const InCallExtensionBusySheet({
    super.key,
    required this.availability,
    required this.onScheduleNext,
  });

  String _formatSlot(ExtensionSlotOption slot) {
    final localStart = slot.startTime.toLocal();
    final localEnd = slot.endTime.toLocal();
    final sh = localStart.hour.toString().padLeft(2, '0');
    final sm = localStart.minute.toString().padLeft(2, '0');
    final eh = localEnd.hour.toString().padLeft(2, '0');
    final em = localEnd.minute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mohon maaf, psikolog memiliki janji konsultasi lain setelah ini',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (availability.reason != null && availability.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              availability.reason!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (availability.nextAvailableSlots.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Slot kosong berikutnya hari ini:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availability.nextAvailableSlots
                  .map(
                    (slot) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatSlot(slot),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('schedule_next_session_btn'),
              onPressed: () {
                Navigator.pop(context);
                onScheduleNext();
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                'Jadwalkan Sesi Berikutnya',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

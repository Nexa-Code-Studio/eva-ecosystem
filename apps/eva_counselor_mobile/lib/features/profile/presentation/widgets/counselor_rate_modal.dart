import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';

class CounselorRateModal {
  static String formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  static void show({
    required BuildContext context,
    required PsychologistUserEntity? user,
    required Function(int coins) onSave,
  }) {
    int currentCoins = user?.coinsPerSession ?? 150;
    final coinsList = [50, 100, 150, 200, 250, 300, 500];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Atur Tarif Koin per Sesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pasien membayar sesi konsultasi dengan Koin. 1 Koin = Rp 1.000.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: coinsList.map((c) {
                  final isSelected = currentCoins == c;
                  return GestureDetector(
                    onTap: () => setModalState(() => currentCoins = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFC2410C) : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFC2410C) : const Color(0xFFECEFF8),
                        ),
                      ),
                      child: Text(
                        '$c Koin (≈ Rp ${formatNumber(c * 1000)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Simpan Tarif Koin',
                onPressed: () {
                  onSave(currentCoins);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Tarif Koin Berhasil Disimpan',
                    message: 'Tarif sesi konsultasi kini $currentCoins Koin (≈ Rp ${formatNumber(currentCoins * 1000)}).',
                    type: ToastType.success,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';

class CounselorDriveBackupModal {
  static void show({
    required BuildContext context,
    required PsychologistUserEntity? user,
    required String initialFrequency,
    required bool initialWifiOnly,
    required Function(String frequency, bool wifiOnly) onSave,
  }) {
    String tempFreq = initialFrequency;
    bool tempWifi = initialWifiOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: AppColors.verifiedGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Cadangan Google Drive',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Rekam medis terenkripsi dicadangkan ke Google Drive pribadi Anda:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          size: 18, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Integrasi cloud OAuth Google Drive saat ini dalam tahap uji coba terbatas. Rekam medis lokal Anda tetap aman terlindungi dengan enkripsi AES-256.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E40AF),
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Frekuensi Pencadangan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Harian', 'Mingguan', 'Manual'].map((f) {
                    final isSelected = tempFreq == f;
                    return ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      selectedColor: AppColors.primaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setModalState(() => tempFreq = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cadangkan Hanya Melalui Wi-Fi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Hindari penggunaan kuota seluler untuk pencadangan',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: tempWifi,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setModalState(() => tempWifi = val),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Simpan Preferensi',
                  onPressed: () {
                    onSave(tempFreq, tempWifi);
                    Navigator.pop(ctx);
                    TopToast.show(
                      context,
                      title: 'Preferensi Cadangan Disimpan',
                      message:
                          'Jadwal cadangan otomatis Google Drive diatur ke $tempFreq.',
                      type: ToastType.success,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

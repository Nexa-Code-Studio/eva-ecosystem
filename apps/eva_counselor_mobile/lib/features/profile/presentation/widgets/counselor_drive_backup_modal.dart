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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pengaturan Cadangan Google Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Rekam medis terenkripsi dicadangkan ke Google Drive pribadi Anda:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Frekuensi: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  ...['Harian', 'Mingguan', 'Manual'].map((f) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: tempFreq == f,
                          onSelected: (_) => setModalState(() => tempFreq = f),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cadangkan Hanya Melalui Wi-Fi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hindari penggunaan kuota seluler untuk pencadangan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: tempWifi,
                activeColor: AppColors.primary,
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
                    message: 'Jadwal cadangan otomatis Google Drive diatur ke $tempFreq.',
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

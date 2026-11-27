import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../providers/privacy_settings_provider.dart';

class CounselorSecurityModal {
  static void show(BuildContext context, [WidgetRef? ref]) {
    final currentPrivacy = ref?.read(privacySettingsProvider) ?? const PrivacySettingsState();
    bool maskPatient = currentPrivacy.isPatientNameMasked;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
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
                  const Text('Keamanan & Privasi Klinis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Perlindungan data pasien sesuai standar kerahasiaan medis & HIPAA:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Masking Nama Pasien di Notifikasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sembunyikan nama terang pasien pada notifikasi layar kunci', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: maskPatient,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setModalState(() => maskPatient = val),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (ref != null) {
                    ref.read(privacySettingsProvider.notifier).setMaskPatientName(maskPatient);
                  }
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Keamanan Diperbarui',
                    message: 'Pengaturan keamanan rekam medis & masking notifikasi berhasil disimpan.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

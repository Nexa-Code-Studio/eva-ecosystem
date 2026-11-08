import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';

class CounselorSecurityModal {
  static void show(BuildContext context) {
    bool biometric = true;
    bool twoFactor = true;
    bool maskPatient = true;

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
                title: const Text('Kunci Biometrik (Face ID / Sidik Jari)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Wajib autentikasi sebelum membuka rekam medis pasien', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: biometric,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => biometric = val),
              ),
              const Divider(height: 1, color: Color(0xFFF0F2F8)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verifikasi 2 Langkah (2FA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Kode OTP saat login di perangkat baru', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: twoFactor,
                activeColor: AppColors.primary,
                onChanged: (val) => setModalState(() => twoFactor = val),
              ),
              const Divider(height: 1, color: Color(0xFFF0F2F8)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Masking Nama Pasien di Notifikasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sembunyikan nama terang pasien pada notifikasi layar kunci', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                value: maskPatient,
                activeColor: AppColors.primary,
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
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Keamanan Diperbarui',
                    message: 'Pengaturan keamanan rekam medis berhasil disimpan.',
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

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';

class CounselorStrCredentialsModal {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kredensial SIPP & STR Psikolog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Kredensial klinis resmi Anda yang terverifikasi di Kementerian Kesehatan & HIMPSI:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.verifiedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.verifiedGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Surat Tanda Registrasi (STR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.verifiedGreen)),
                      Icon(Icons.verified_rounded, color: AppColors.verifiedGreen, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Nomor: 4192-PSI-2024', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('Penerbit: KTKI (Konsil Tenaga Kesehatan Indonesia)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  const Text('Masa Berlaku: 18 Oktober 2029 (Aktif)', style: TextStyle(fontSize: 11, color: AppColors.verifiedGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Surat Izin Praktik Psikologi (SIPP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                  SizedBox(height: 6),
                  Text('Nomor: 503/SIPP/DKS/2023', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Wilayah Layanan: Nasional (Telekonsultasi)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  SizedBox(height: 2),
                  Text('Keanggotaan HIMPSI: Aktif (#HM-9214)', style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D9E4)),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                TopToast.show(
                  context,
                  title: 'Perpanjangan Kredensial',
                  message: 'Upload pembaruan STR/SIPP melalui portal web admin psikolog.',
                  type: ToastType.info,
                );
              },
              child: const Text('Perbarui Dokumen Kredensial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

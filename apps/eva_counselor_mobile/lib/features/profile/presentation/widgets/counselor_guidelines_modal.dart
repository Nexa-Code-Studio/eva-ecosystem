import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CounselorGuidelinesModal {
  static void showProfessional(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                const Text('Panduan Etik & SOP HIMPSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Standar Operasional Prosedur Layanan Telekonseling EVA:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _ethicItem('1. Kerahasiaan & Batas Etik', 'Data rekam medis SOAP terenkripsi end-to-end dan hanya dapat diakses psikolog penanggung jawab.'),
            const SizedBox(height: 8),
            _ethicItem('2. Protokol De-eskalasi Krisis', 'Jika skor DASS-21 atau deteksi Eva AI menunjukkan risiko self-harm, psikolog wajib mengaktifkan hotline darurat.'),
            const SizedBox(height: 8),
            _ethicItem('3. Dokumentasi SOAP Tepat Waktu', 'Psikolog diharapkan mereview dan memverifikasi draft auto-SOAP Eva AI maksimal 24 jam setelah sesi selesai.'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _ethicItem(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}

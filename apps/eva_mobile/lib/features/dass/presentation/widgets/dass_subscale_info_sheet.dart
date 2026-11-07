import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';

/// Modal bottom sheets presenting DASS-21 subscale indicator explanations and clinical psychologist referral.
class DassSubscaleInfoSheet {
  static void show({
    required BuildContext context,
    required String label,
    required int score,
    required String severityIndo,
    required String scaleType,
    required Color scoreColor,
  }) {
    String definition = '';
    String tip = '';

    if (scaleType == 'depression') {
      definition =
          'Subskala Depresi mengukur tingkat suasana hati disforik, hilangnya motivasi/inisiatif, anhedonia (kesulitan merasakan hal positif), dan perasaan ketidakberhargaan.';
      tip =
          'Coba lakukan aktivitas kecil yang kamu sukai, luapkan pikiran melalui percakapan bersama EVA, atau jalan santai menghirup udara segar.';
    } else if (scaleType == 'anxiety') {
      definition =
          'Subskala Kecemasan mengukur stimulasi otonomik (otot tegang, detak jantung kencang), cemas situasional, dan ketakutan akan kehilangan kendali.';
      tip =
          'Lakukan teknik pernapasan 4-7-8 atau relaksasi otot bertahap untuk menurunkan stimulasi fisik berlebih.';
    } else {
      definition =
          'Subskala Stres mengukur ketegangan syaraf non-spesifik, reaksi berlebihan pada masalah harian, kegelisahan, dan ketidakmampuan untuk bersantai.';
      tip =
          'Ambil jeda istirahat dari pekerjaan/tugas, hindari multitasking berlebih, dan nikmati minuman hangat.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$score / 42 Poin',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Tingkat Keparahan: ',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  severityIndo,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEADBFF)),
            const SizedBox(height: 14),
            Text(
              'PENJELASAN INDIKATOR:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              definition,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              'REKOMENDASI MANDIRI:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Text(
                tip,
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showPsychologistReferral({
    required BuildContext context,
    required String label,
    required int score,
    required String scaleType,
    required VoidCallback onOpenWhatsapp,
  }) {
    String detailExplanation = '';

    if (scaleType == 'depression') {
      detailExplanation =
          'Sistem mencatat tingkat Depresi pengguna pada kategori Sangat Berat (Extremely Severe). Kondisi ini dicirikan oleh anhedonia total (kehilangan kemampuan merasakan hal positif), perasaan tidak berharga mendalam, serta keletihan fisik dan emosional yang signifikan.\n\n'
          '⚠️ Catatan Penting: Eva AI adalah pendamping mandiri dan bukan pengganti diagnosis atau terapi medis klinis. Kamu sangat disarankan untuk berbicara langsung dengan Psikolog Klinis atau Psikiater.';
    } else if (scaleType == 'anxiety') {
      detailExplanation =
          'Sistem mencatat tingkat Kecemasan pengguna pada kategori Sangat Berat (Extremely Severe). Kondisi ini ditandai dengan serangan panik intens, detak jantung kencang tanpa alasan fisik, guncangan rasa takut akut, atau kekhawatiran melumpuhkan harian.\n\n'
          '⚠️ Catatan Penting: Gejala kecemasan akut membutuhkan penanganan profesional medis. Sangat disarankan untuk segera menemui Psikolog Klinis atau Psikiater terdekat.';
    } else {
      detailExplanation =
          'Sistem mencatat tingkat Stres pengguna pada kategori Sangat Berat (Extremely Severe). Kondisi ini mengindikasikan burnout ekstrem, ketegangan saraf kronis, kelelahan energi berat, serta keputusasaan dalam menangani tekanan harian.\n\n'
          '⚠️ Catatan Penting: Beban stres kronis dapat berdampak pada kesehatan fisik. Disarankan untuk mengambil jeda penuh dan melakukan sesi konseling bersama psikolog profesional.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SANGAT BERAT (EXTREMELY SEVERE)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD32F2F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Indikasi $label: $score / 42 Poin',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PENJELASAN KLINIS & REKOMENDASI:',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detailExplanation,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onOpenWhatsapp();
                },
                icon: const Icon(Icons.chat_outlined, size: 20),
                label: Text(
                  'Konsultasi via WhatsApp Psikolog / Krisis',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Tutup Penjelasan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showGuideDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Panduan Skala DASS-21',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'DASS-21 (Depression Anxiety Stress Scales) mengukur 3 indikator psikologis harian (0–42 poin per subskala) dari transkrip percakapanmu bersama Eva AI.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'KATEGORI WARNA & TINGKAT KEPARAHAN:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildLegendRow('Normal', 'Kondisi emosi stabil & terkendali.', const Color(0xFF2E7D32)),
              _buildLegendRow('Ringan (Mild)', 'Fluktuasi emosi ringan harian.', const Color(0xFFFBC02D)),
              _buildLegendRow('Sedang (Moderate)', 'Mulai mengganggu kenyamanan & butuh jeda istirahat.', const Color(0xFFF57C00)),
              _buildLegendRow('Berat (Severe)', 'Beban emosional terasa berat & perlu perhatian khusus.', const Color(0xFFE65100)),
              _buildLegendRow('Sangat Berat (Extremely Severe)', 'Indikasi krisis — sangat disarankan konsultasi ke psikolog/psikiater.', const Color(0xFFD32F2F)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Saya Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildLegendRow(String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

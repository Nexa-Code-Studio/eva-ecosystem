import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";
import "package:url_launcher/url_launcher.dart";

import "package:eva_mobile/theme/app_colors.dart";
import "package:eva_mobile/widgets/app_snack_bar.dart";
import "package:eva_mobile/widgets/glass_card.dart";
import "../../../dass/presentation/providers/dass_provider.dart";

class MonitoringDassCard extends ConsumerWidget {
  final String selectedPeriod;

  const MonitoringDassCard({
    super.key,
    required this.selectedPeriod,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dassState = ref.watch(dassAssessmentNotifierProvider);

    return dassState.assessment.when(
      data: (assessment) {
        final bool hasValidAssessment = assessment.id != null &&
            assessment.status != "unassessed" &&
            assessment.status.isNotEmpty &&
            (assessment.verifiedByUser || assessment.status == "auto_extracted");

        final String subtitleText = hasValidAssessment
            ? (assessment.verifiedByUser
                ? "Skor DASS-21 telah diverifikasi ✓"
                : "Tersintesis otomatis • Ketuk untuk meninjau")
            : "Belum ada evaluasi hari ini";

        final int? stressScore = hasValidAssessment ? assessment.stressScore : null;
        final String stressSeverity = hasValidAssessment ? assessment.stressSeverity : "unassessed";

        final int? anxietyScore = hasValidAssessment ? assessment.anxietyScore : null;
        final String anxietySeverity = hasValidAssessment ? assessment.anxietySeverity : "unassessed";

        final int? depressionScore = hasValidAssessment ? assessment.depressionScore : null;
        final String depressionSeverity = hasValidAssessment ? assessment.depressionSeverity : "unassessed";

        return _buildDASSLauncherCardContainer(
          context: context,
          ref: ref,
          selectedPeriod: selectedPeriod,
          subtitleText: subtitleText,
          hasValidAssessment: hasValidAssessment,
          stressScore: stressScore,
          stressSeverity: stressSeverity,
          anxietyScore: anxietyScore,
          anxietySeverity: anxietySeverity,
          depressionScore: depressionScore,
          depressionSeverity: depressionSeverity,
        );
      },
      loading: () => _buildDASSLauncherCardContainer(
        context: context,
        ref: ref,
        selectedPeriod: selectedPeriod,
        subtitleText: "Memuat data evaluasi DASS-21...",
        hasValidAssessment: false,
        stressScore: null,
        stressSeverity: "unassessed",
        anxietyScore: null,
        anxietySeverity: "unassessed",
        depressionScore: null,
        depressionSeverity: "unassessed",
      ),
      error: (_, _) => _buildDASSLauncherCardContainer(
        context: context,
        ref: ref,
        selectedPeriod: selectedPeriod,
        subtitleText: "Belum ada evaluasi hari ini",
        hasValidAssessment: false,
        stressScore: null,
        stressSeverity: "unassessed",
        anxietyScore: null,
        anxietySeverity: "unassessed",
        depressionScore: null,
        depressionSeverity: "unassessed",
      ),
    );
  }

  Widget _buildDASSLauncherCardContainer({
    required BuildContext context,
    required WidgetRef ref,
    required String selectedPeriod,
    required String subtitleText,
    required bool hasValidAssessment,
    required int? stressScore,
    required String stressSeverity,
    required int? anxietyScore,
    required String anxietySeverity,
    required int? depressionScore,
    required String depressionSeverity,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F4FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFF20667B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'LEMBAR EVALUASI DASS-21',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _showDassInfoDialog(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F0FE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Mini Subscale Summary Pills
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _buildSubscaleMiniChip(
                    context,
                    'Stres',
                    stressScore,
                    stressSeverity,
                    'stress',
                  ),
                  const SizedBox(width: 8),
                  _buildSubscaleMiniChip(
                    context,
                    'Kecemasan',
                    anxietyScore,
                    anxietySeverity,
                    'anxiety',
                  ),
                  const SizedBox(width: 8),
                  _buildSubscaleMiniChip(
                    context,
                    'Depresi',
                    depressionScore,
                    depressionSeverity,
                    'depression',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Open Full Assessment Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    '/dass_assessment',
                    arguments: {'period': selectedPeriod},
                  );
                  ref.invalidate(dassAssessmentNotifierProvider);
                },
                icon: Icon(
                  hasValidAssessment
                      ? Icons.assignment_turned_in_outlined
                      : Icons.edit_note_rounded,
                  size: 18,
                ),
                label: Text(
                  hasValidAssessment
                      ? (selectedPeriod == 'today'
                          ? 'Tinjau Asesmen Hari Ini'
                          : 'Buka Riwayat Asesmen')
                      : 'Mulai Evaluasi DASS-21',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIndonesianSeverity(String scaleType, int score, String rawSeverity) {
    final s = rawSeverity.toLowerCase();
    if (s.contains('extremely') || s.contains('sangat berat')) return 'Sangat Berat';
    if (s.contains('severe') || s.contains('berat')) return 'Berat';
    if (s.contains('moderate') || s.contains('sedang')) return 'Sedang';
    if (s.contains('mild') || s.contains('ringan')) return 'Ringan';
    if (s.contains('normal')) return 'Normal';

    if (scaleType == 'depression') {
      if (score >= 28) return 'Sangat Berat';
      if (score >= 21) return 'Berat';
      if (score >= 14) return 'Sedang';
      if (score >= 10) return 'Ringan';
      return 'Normal';
    } else if (scaleType == 'anxiety') {
      if (score >= 20) return 'Sangat Berat';
      if (score >= 15) return 'Berat';
      if (score >= 10) return 'Sedang';
      if (score >= 8) return 'Ringan';
      return 'Normal';
    } else {
      if (score >= 34) return 'Sangat Berat';
      if (score >= 26) return 'Berat';
      if (score >= 19) return 'Sedang';
      if (score >= 15) return 'Ringan';
      return 'Normal';
    }
  }

  Color _getScoreColor(String severityIndo) {
    switch (severityIndo) {
      case 'Sangat Berat':
        return const Color(0xFFD32F2F);
      case 'Berat':
        return const Color(0xFFE65100);
      case 'Sedang':
        return const Color(0xFFF57C00);
      case 'Ringan':
        return const Color(0xFFFBC02D);
      case 'Normal':
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Widget _buildSubscaleMiniChip(
    BuildContext context,
    String label,
    int? score,
    String rawSeverity,
    String scaleType,
  ) {
    if (score == null) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _showDassInfoDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '-',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                    Text(
                      '/42',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Belum Ada',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final severityIndo = _getIndonesianSeverity(scaleType, score, rawSeverity);
    final scoreColor = _getScoreColor(severityIndo);
    final bool isExtremelySevere = severityIndo == 'Sangat Berat';

    final Color bgColor = isExtremelySevere
        ? const Color(0xFFD32F2F)
        : scoreColor.withValues(alpha: 0.08);

    final Color labelColor = isExtremelySevere ? Colors.white70 : scoreColor;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isExtremelySevere) {
            _showPsychologistReferralModal(context, label, score, scaleType);
          } else {
            _showSubscaleInfoModal(context, label, score, severityIndo, scaleType);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExtremelySevere
                  ? const Color(0xFFB71C1C)
                  : scoreColor.withValues(alpha: 0.25),
              width: isExtremelySevere ? 1.5 : 1,
            ),
            boxShadow: isExtremelySevere
                ? [
                    BoxShadow(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isExtremelySevere) ...[
                    const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isExtremelySevere ? Colors.white : scoreColor,
                    ),
                  ),
                  Text(
                    '/42',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isExtremelySevere ? Colors.white70 : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isExtremelySevere
                      ? Colors.white.withValues(alpha: 0.2)
                      : scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severityIndo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isExtremelySevere ? Colors.white : scoreColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDassInfoDialog(BuildContext context) {
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

  Widget _buildLegendRow(String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscaleInfoModal(
    BuildContext context,
    String label,
    int score,
    String severityIndo,
    String scaleType,
  ) {
    final scoreColor = _getScoreColor(severityIndo);
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

  void _showPsychologistReferralModal(
    BuildContext context,
    String label,
    int score,
    String scaleType,
  ) {
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
                  _openWhatsappEmergency(context);
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


  static const String _whatsappEmergencyUrl =
      'https://api.whatsapp.com/send/?phone=6281380073120&text=halo%20kak%2C%20saya%20ingin%20bercerita%20mengenai...&type=phone_number&app_absent=0';

  Future<void> _openWhatsappEmergency(BuildContext context) async {
    final uri = Uri.parse(_whatsappEmergencyUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            'Tidak dapat membuka WhatsApp Konseling Krisis',
          );
        }
      }
    }
  }

}

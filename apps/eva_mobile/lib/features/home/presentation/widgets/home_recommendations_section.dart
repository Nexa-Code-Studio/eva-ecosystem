import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_snack_bar.dart';
import 'home_crisis_banner.dart';

/// Section displaying personalized therapeutic CBT & mindfulness activities for the day.
class HomeRecommendationsSection extends StatelessWidget {
  final Map<String, dynamic> activeRec;
  final String conditionLabel;
  final String severityLevel;
  final bool isCrisis;
  final String crisisGuidance;
  final String crisisHotline;
  final bool isDone;
  final VoidCallback onSeeAll;
  final VoidCallback onSupportTap;
  final VoidCallback onOpenDetail;
  final ValueChanged<String> onToggleComplete;

  const HomeRecommendationsSection({
    super.key,
    required this.activeRec,
    required this.conditionLabel,
    required this.severityLevel,
    required this.isCrisis,
    required this.crisisGuidance,
    required this.crisisHotline,
    required this.isDone,
    required this.onSeeAll,
    required this.onSupportTap,
    required this.onOpenDetail,
    required this.onToggleComplete,
  });

  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'sangat berat':
      case 'extremely severe':
        return const Color(0xFFDC2626);
      case 'berat':
      case 'severe':
        return const Color(0xFFEA580C);
      case 'sedang':
      case 'moderate':
        return const Color(0xFFD97706);
      case 'ringan':
      case 'mild':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF10B981);
    }
  }

  static String normalizeCategory(String cat) {
    if (cat.toUpperCase() == 'CBT') return 'Teknik Kognitif (CBT)';
    if (cat.toUpperCase() == 'MINDFULNESS') return 'Latihan Mindfulness';
    if (cat.toUpperCase() == 'BREATHING') return 'Pernapasan Terarah';
    if (cat.toUpperCase() == 'REFLEKSI') return 'Jurnal Refleksi Diri';
    return cat;
  }

  @override
  Widget build(BuildContext context) {
    final id = activeRec['id']?.toString() ?? '1';
    final rawCategory = activeRec['category']?.toString() ?? 'Self-Care';
    final category = normalizeCategory(rawCategory);
    final duration = activeRec['duration']?.toString() ?? '5 menit';
    final title = activeRec['title']?.toString() ?? 'Latihan Relaksasi';
    final description = activeRec['description']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Aktivitas Pilihan Hari Ini',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    'Lihat Semua',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          conditionLabel.isNotEmpty
              ? conditionLabel
              : 'Disesuaikan dengan kondisi emosionalmu hari ini',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Crisis Alert Banner (if applicable)
        if (isCrisis)
          HomeCrisisBanner(
            crisisGuidance: crisisGuidance,
            crisisHotline: crisisHotline,
            onSupportTap: onSupportTap,
          ),

        // Sleek Recommendation Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4F46E5),
                Color(0xFF6366F1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Row: Category • Duration + Severity Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$category  •  $duration'.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (severityLevel != 'Normal')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: getSeverityColor(severityLevel).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: getSeverityColor(severityLevel).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Level: $severityLevel',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Action Buttons: Mulai Latihan (CTA) + Tandai Selesai
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenDetail,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_filled,
                                size: 18,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isDone ? 'Buka Panduan' : 'Mulai Latihan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        if (isDone) {
                          AppSnackBar.showPrimary(
                            context,
                            'Kamu sudah menyelesaikan latihan ini hari ini! Kerja bagus, istirahatlah sejenak dan lanjutkan kembali besok 🌿',
                            icon: Icons.info_outline,
                          );
                          return;
                        }
                        onToggleComplete(id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDone ? Icons.check_circle : Icons.check_circle_outline,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isDone ? 'Selesai' : 'Tandai',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

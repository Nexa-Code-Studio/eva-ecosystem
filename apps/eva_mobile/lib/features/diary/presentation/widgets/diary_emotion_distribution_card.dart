import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

/// Helper to parse color objects or hex string fallback.
Color parseEmotionColor(dynamic colorVal, Color fallback) {
  if (colorVal is Color) return colorVal;
  if (colorVal is String && colorVal.startsWith('#')) {
    final hex = colorVal.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
  }
  return fallback;
}

/// Card rendering the 7-emotion distribution parameters with animated percentage progress bars.
class DiaryEmotionDistributionCard extends StatelessWidget {
  final List<Map<String, dynamic>> activeEmotions;
  final bool isSingleSession;
  final String selectedSessionId;

  const DiaryEmotionDistributionCard({
    super.key,
    required this.activeEmotions,
    required this.isSingleSession,
    required this.selectedSessionId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ANALISIS 7 PARAMETER EMOSI',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEADBFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isSingleSession
                    ? 'SESI INI'
                    : (selectedSessionId == 'all' ? 'KUMULATIF' : 'SESI SPESIFIK'),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: activeEmotions.map((emo) {
              final double pct =
                  ((emo['percent'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
              final int pctInt = (pct * 100).round();
              final Color emoColor = parseEmotionColor(emo['color'], AppColors.primary);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              emo['emoji']?.toString() ?? '✨',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              emo['label']?.toString() ?? 'Emosi',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$pctInt%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE2E4F0),
                        valueColor: AlwaysStoppedAnimation<Color>(emoColor),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

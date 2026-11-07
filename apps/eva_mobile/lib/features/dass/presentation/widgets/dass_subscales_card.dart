import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive_layout_helper.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';
import '../../domain/entities/dass_assessment_entity.dart';
import 'bouncing_button.dart';

/// Card rendering summary scores for the 3 DASS-21 subscales (Stress, Anxiety, Depression).
class DassSubscalesCard extends StatelessWidget {
  final DASSAssessmentEntity assessment;
  final Map<int, int> stagedScores;
  final VoidCallback onInfoTap;
  final void Function(String label, int score, String severityIndo, String scaleType) onSubscaleTap;
  final void Function(String label, int score, String scaleType) onExtremelySevereTap;

  const DassSubscalesCard({
    super.key,
    required this.assessment,
    required this.stagedScores,
    required this.onInfoTap,
    required this.onSubscaleTap,
    required this.onExtremelySevereTap,
  });

  static String getIndonesianSeverity(String scale, int score) {
    if (scale == 'depression') {
      if (score >= 28) return 'Sangat Berat';
      if (score >= 21) return 'Berat';
      if (score >= 14) return 'Sedang';
      if (score >= 10) return 'Ringan';
      return 'Normal';
    } else if (scale == 'anxiety') {
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

  static Color getScoreColor(String severityIndo) {
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

  @override
  Widget build(BuildContext context) {
    int strRaw = 0, anxRaw = 0, depRaw = 0;

    for (final item in assessment.items) {
      final s = stagedScores[item.itemId] ?? item.score;
      if (item.scale == 'stress') strRaw += s;
      if (item.scale == 'anxiety') anxRaw += s;
      if (item.scale == 'depression') depRaw += s;
    }

    final int stressScore = strRaw * 2;
    final int anxietyScore = anxRaw * 2;
    final int depressionScore = depRaw * 2;

    final stressSev = getIndonesianSeverity('stress', stressScore);
    final anxietySev = getIndonesianSeverity('anxiety', anxietyScore);
    final depressionSev = getIndonesianSeverity('depression', depressionScore);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Skor 3 Dimensi DASS-21',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: context.responsiveFont(14),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F0FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _buildSubscaleTile(
                  context,
                  'Stres',
                  stressScore,
                  stressSev,
                  'stress',
                ),
                const SizedBox(width: 8),
                _buildSubscaleTile(
                  context,
                  'Kecemasan',
                  anxietyScore,
                  anxietySev,
                  'anxiety',
                ),
                const SizedBox(width: 8),
                _buildSubscaleTile(
                  context,
                  'Depresi',
                  depressionScore,
                  depressionSev,
                  'depression',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscaleTile(
    BuildContext context,
    String label,
    int score,
    String severityIndo,
    String scaleType,
  ) {
    final scoreColor = getScoreColor(severityIndo);
    final bool isExtremelySevere = severityIndo == 'Sangat Berat';

    final Color bgColor = isExtremelySevere
        ? const Color(0xFFD32F2F)
        : scoreColor.withValues(alpha: 0.08);

    final Color labelColor = isExtremelySevere ? Colors.white70 : scoreColor;

    return Expanded(
      child: BouncingButton(
        onTap: () {
          if (isExtremelySevere) {
            onExtremelySevereTap(label, score, scaleType);
          } else {
            onSubscaleTap(label, score, severityIndo, scaleType);
          }
        },
        scaleFactor: 0.94,
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
}

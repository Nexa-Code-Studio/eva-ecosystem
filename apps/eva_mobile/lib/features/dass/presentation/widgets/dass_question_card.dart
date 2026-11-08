import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';
import '../../domain/entities/dass_assessment_entity.dart';
import 'bouncing_button.dart';
import 'dass_ai_analysis_accordion.dart';

/// Card displaying an individual DASS-21 question with 4-point Likert buttons and explainable AI insights.
class DassQuestionCard extends StatelessWidget {
  final DASSItemEntity item;
  final int currentScore;
  final bool isEditable;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onScoreChanged;
  final VoidCallback onUndoAI;

  const DassQuestionCard({
    super.key,
    required this.item,
    required this.currentScore,
    required this.isEditable,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onScoreChanged,
    required this.onUndoAI,
  });

  static Color getScaleColor(String scale) {
    switch (scale) {
      case 'stress':
        return const Color(0xFFF57C00);
      case 'anxiety':
        return const Color(0xFF7C3AED);
      case 'depression':
      default:
        return const Color(0xFF2563EB);
    }
  }

  static String getScaleLabel(String scale) {
    switch (scale) {
      case 'stress':
        return 'Stres';
      case 'anxiety':
        return 'Kecemasan';
      case 'depression':
      default:
        return 'Depresi';
    }
  }

  static Color getConfidenceColor(double conf) {
    if (conf >= 0.8) return const Color(0xFF16A34A);
    if (conf >= 0.5) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  static Color getConfidenceBg(double conf) {
    if (conf >= 0.8) return const Color(0xFFF0FDF4);
    if (conf >= 0.5) return const Color(0xFFFFFBEB);
    return const Color(0xFFFEF2F2);
  }

  static String getConfidenceLabel(double conf) {
    if (conf >= 0.8) return 'Tinggi';
    if (conf >= 0.5) return 'Sedang';
    return 'Rendah';
  }

  @override
  Widget build(BuildContext context) {
    final scaleColor = getScaleColor(item.scale);
    final scaleLabel = getScaleLabel(item.scale);
    final isAnsweredByAI = item.confidence > 0 ||
        (item.evidence != null && item.evidence!.trim().isNotEmpty) ||
        (item.reason != null && item.reason!.trim().isNotEmpty);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Number & Subscale Tag
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scaleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item ${item.itemId} • $scaleLabel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scaleColor,
                  ),
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (item.isUserEdited || (isEditable && item.score != currentScore))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Telah Dikoreksi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  if (isEditable && item.score != currentScore && isAnsweredByAI)
                    GestureDetector(
                      onTap: onUndoAI,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.undo_rounded, size: 10, color: Color(0xFF4B5563)),
                            const SizedBox(width: 3),
                            Text(
                              'Saran AI (${item.score})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isAnsweredByAI) _buildAIAnalysisIconButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Question Text
          Text(
            item.questionText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
              height: 1.35,
            ),
          ),

          // Explainable AI Accordion (Evidence, Confidence, Reason)
          if (isAnsweredByAI) _buildAIAnalysisSection(),

          const SizedBox(height: 12),

          // Likert Selector Options (0 - 3)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _buildLikertButton(0, '0: Tdk Ada', currentScore == 0),
                const SizedBox(width: 6),
                _buildLikertButton(1, '1: Kadang', currentScore == 1),
                const SizedBox(width: 6),
                _buildLikertButton(2, '2: Sering', currentScore == 2),
                const SizedBox(width: 6),
                _buildLikertButton(3, '3: Selalu', currentScore == 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisIconButton() {
    final conf = item.confidence;
    final confColor = getConfidenceColor(conf);
    final confBg = getConfidenceBg(conf);
    final confPercent = (conf * 100).round();

    return Tooltip(
      message: isExpanded
          ? 'Tutup Analisis AI'
          : (conf > 0 ? 'Analisis Eva ($confPercent% Yakin)' : 'Lihat Analisis Eva'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggleExpand,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isExpanded ? confBg : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(
                color: isExpanded ? confColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: isExpanded ? confColor : const Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIAnalysisSection() {
    final hasEvidence = item.evidence != null && item.evidence!.trim().isNotEmpty;
    final hasReason = item.reason != null && item.reason!.trim().isNotEmpty;
    final conf = item.confidence;
    final confPercent = (conf * 100).round();
    final confColor = getConfidenceColor(conf);
    final confBg = getConfidenceBg(conf);
    final confLabel = getConfidenceLabel(conf);

    return DassAIAnalysisAccordion(
      isExpanded: isExpanded,
      item: item,
      confBg: confBg,
      confColor: confColor,
      confPercent: confPercent,
      confLabel: confLabel,
      hasEvidence: hasEvidence,
      hasReason: hasReason,
    );
  }

  Widget _buildLikertButton(int score, String label, bool isSelected) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: BouncingButton(
          onTap: isEditable ? () => onScoreChanged(score) : null,
          scaleFactor: 0.92,
          child: AnimatedScale(
            scale: isSelected ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isEditable ? Colors.white : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isEditable ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB)),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isEditable ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF)),
                  ),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

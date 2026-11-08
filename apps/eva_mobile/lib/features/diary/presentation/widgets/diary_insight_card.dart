import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';
import '../../../../widgets/staggered_entrance.dart';
import 'summary_skeleton_loader.dart';

/// Card presenting AI-synthesized cumulative insights or standalone session summary.
class DiaryInsightCard extends StatelessWidget {
  final bool isSingleSession;
  final int sessionCount;
  final String? lastSessionTime;
  final bool isLoadingSkeleton;
  final bool isStreaming;
  final bool streamError;
  final String? streamedSummary;
  final String? summaryText;
  final VoidCallback? onRetry;

  const DiaryInsightCard({
    super.key,
    required this.isSingleSession,
    required this.sessionCount,
    this.lastSessionTime,
    this.isLoadingSkeleton = false,
    this.isStreaming = false,
    this.streamError = false,
    this.streamedSummary,
    this.summaryText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StaggeredEntrance(
      index: 2,
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSingleSession ? 'RINGKASAN PERCAKAPAN' : 'WAWASAN AI KUMULATIF',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        isSingleSession
                            ? '✨ Ringkasan cerdas percakapan sesi suara bersama EVA'
                            : '✨ Diperbarui setelah Sesi #$sessionCount (${lastSessionTime ?? 'Hari ini'})',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isSingleSession && isLoadingSkeleton)
              const SummarySkeletonLoader()
            else if (isSingleSession && isStreaming)
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: streamedSummary ?? ''),
                    const TextSpan(
                      text: ' ▋',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (isSingleSession &&
                streamError &&
                (streamedSummary == null || streamedSummary!.isEmpty))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan percakapan belum berhasil dimuat.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (onRetry != null)
                    InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '✨ Generate Ringkasan',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              Text(
                summaryText ??
                    'Analisis AI menunjukkan kondisi emosional kamu hari ini cukup stabil.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

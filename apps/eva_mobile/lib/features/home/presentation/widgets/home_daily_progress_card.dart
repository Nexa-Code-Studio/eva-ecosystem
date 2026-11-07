import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive_layout_helper.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

/// Card displaying the 3 evidence-based daily self-care habit routines with segmented progress bars.
class HomeDailyProgressCard extends StatelessWidget {
  final int completedCount;
  final bool isConversationDone;
  final bool isDiaryDone;
  final bool isExerciseDone;
  final int todayConversationsCount;
  final VoidCallback onTapConversation;
  final VoidCallback onTapDiary;
  final VoidCallback onTapExercise;

  const HomeDailyProgressCard({
    super.key,
    required this.completedCount,
    required this.isConversationDone,
    required this.isDiaryDone,
    required this.isExerciseDone,
    required this.todayConversationsCount,
    required this.onTapConversation,
    required this.onTapDiary,
    required this.onTapExercise,
  });

  @override
  Widget build(BuildContext context) {
    final progressFraction = (completedCount / 3.0).clamp(0.0, 1.0);

    String progressMotivation;
    if (completedCount == 3) {
      progressMotivation =
          'Luar biasa! Semua target perawatan dirimu tercapai hari ini 🌟';
    } else if (completedCount == 2) {
      progressMotivation =
          'Tinggal 1 langkah lagi untuk melengkapi rutinitas terapeutikmu.';
    } else if (completedCount == 1) {
      progressMotivation =
          'Kemajuan yang sangat baik! Terus jaga ritme emosionalmu.';
    } else {
      progressMotivation =
          'Mulai harimu dengan satu langkah kecil penuh perhatian bersama EVA.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: completedCount == 3
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      completedCount == 3 ? Icons.stars_rounded : Icons.spa_rounded,
                      size: 16,
                      color: completedCount == 3
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Perawatan Diri',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: context.responsiveFont(15),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: completedCount == 3
                    ? const Color(0xFFD1FAE5)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: completedCount == 3
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (completedCount == 3) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: Color(0xFF047857),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '$completedCount/3 Selesai',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: completedCount == 3
                          ? const Color(0xFF047857)
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Premium Progress Container
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented 3-Step Progress Bars
              Row(
                children: [
                  Expanded(
                    child: _buildSegmentBar(isActive: isConversationDone),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSegmentBar(isActive: isDiaryDone),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildSegmentBar(isActive: isExerciseDone),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Motivation & Percentage Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: completedCount == 3
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completedCount == 3
                        ? const Color(0xFF86EFAC).withValues(alpha: 0.5)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      completedCount == 3
                          ? Icons.emoji_events_rounded
                          : Icons.auto_awesome,
                      size: 16,
                      color: completedCount == 3
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        progressMotivation,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: completedCount == 3
                              ? const Color(0xFF065F46)
                              : AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: completedCount == 3
                            ? const Color(0xFF10B981)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(progressFraction * 100).round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Routine 1: Sesi Curhat / Dialog Emosi
              _buildProgressCheckItem(
                title: 'Sesi Curhat Bersama Eva',
                subtitle: isConversationDone
                    ? '$todayConversationsCount sesi dialog telah tercatat hari ini'
                    : 'Ekspresikan perasaanmu lewat suara atau teks',
                icon: Icons.chat_bubble_outline_rounded,
                isCompleted: isConversationDone,
                onTap: onTapConversation,
              ),
              const SizedBox(height: 8),

              // Routine 2: Refleksi Jurnal AI
              _buildProgressCheckItem(
                title: 'Refleksi Jurnal Harian',
                subtitle: isDiaryDone
                    ? 'Jurnal & analisis emosi telah disintesis'
                    : 'Baca rangkuman & pola emosimu hari ini',
                icon: Icons.menu_book_rounded,
                isCompleted: isDiaryDone,
                onTap: onTapDiary,
              ),
              const SizedBox(height: 8),

              // Routine 3: Latihan Koping Terpandu
              _buildProgressCheckItem(
                title: 'Latihan Relaksasi & Koping',
                subtitle: isExerciseDone
                    ? '1 latihan koping mandiri telah diselesaikan'
                    : 'Coba 1 teknik pernapasan atau mindfulness',
                icon: Icons.spa_rounded,
                isCompleted: isExerciseDone,
                onTap: onTapExercise,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBar({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildProgressCheckItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primaryContainer.withValues(alpha: 0.35)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? AppColors.primary : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 18,
                color: isCompleted ? AppColors.primary : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

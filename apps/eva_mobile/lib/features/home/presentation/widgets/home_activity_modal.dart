import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/routes/app_route_transitions.dart";
import "../../../../theme/app_colors.dart";
import "../../../coping/exercises/breathing/breathing.dart";
import "../../../coping/shared/domain/coping_session_result.dart";

/// Modal bottom sheet content for home screen with rationale, steps, and coping launch
class HomeActivityModalContent extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String conditionReason;
  final bool isCompleted;
  final VoidCallback onComplete;

  const HomeActivityModalContent({
    super.key,
    required this.activity,
    required this.conditionReason,
    required this.isCompleted,
    required this.onComplete,
  });

  Future<void> _openGuidedBreathing(BuildContext context) async {
    final result = await Navigator.of(context).push<CopingSessionResult>(
      AppRouteTransitions.modalSlideUpRoute<CopingSessionResult>(
        page: const BreathingExperiencePage(),
      ),
    );
    if (!context.mounted) return;
    if (result != null && result.isCompleted && !isCompleted) {
      onComplete();
    }
  }

  String _normalizeCategory(String? raw) {
    final cat = (raw ?? '').toLowerCase();
    if (cat.contains('mindful') ||
        cat.contains('napas') ||
        cat.contains('breath')) {
      return 'Mindfulness';
    }
    if (cat.contains('cbt') ||
        cat.contains('kognitif') ||
        cat.contains('problem')) {
      return 'CBT';
    }
    if (cat.contains('refleksi') ||
        cat.contains('syukur') ||
        cat.contains('self-care')) {
      return 'Refleksi';
    }
    if (cat.contains('fisik') ||
        cat.contains('gerak') ||
        cat.contains('somatis') ||
        cat.contains('aktivasi') ||
        cat.contains('jalan')) {
      return 'Fisik & Gerak';
    }
    return raw?.isNotEmpty == true ? raw! : 'Self-Care';
  }

  @override
  Widget build(BuildContext context) {
    final title = activity['title']?.toString() ?? 'Latihan Relaksasi';
    final rawCat = activity['category']?.toString() ?? 'Self-Care';
    final category = _normalizeCategory(rawCat);
    final duration = activity['duration']?.toString() ?? '5 menit';
    final difficulty = activity['difficulty']?.toString() ?? 'Pemula';
    final description = activity['description']?.toString() ?? '';
    final rationale = activity['rationale']?.toString() ?? '';
    final rawInstructions = activity['instructions'];
    List<String> instructions = rawInstructions is List
        ? List<String>.from(rawInstructions.map((e) => e.toString()))
        : <String>[];

    if (instructions.isEmpty) {
      instructions = [
        'Cari posisi duduk yang santai dan nyaman.',
        'Tarik napas dalam perlahan dan hembuskan perlahan.',
        'Lakukan langkah latihan ini secara tenang selama $duration.',
        'Rasakan perubahan sensasi rileks di tubuhmu setelah selesai.',
      ];
    }

    final displayRationale = rationale.isNotEmpty ? rationale : conditionReason;

    final isBreathingActivity =
        title.toLowerCase().contains('napas') ||
        title.toLowerCase().contains('breath') ||
        category.toLowerCase() == 'mindfulness';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header tags & close button (X)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  $duration  •  $difficulty',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayRationale.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kenapa Latihan Ini Membantu?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  displayRationale,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (isBreathingActivity) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryContainer,
                            AppColors.surfaceLow,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.air_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pemandu Napas Layar Penuh',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ikuti lingkaran dan visual napas tenang 4 detik tarik / 4 detik hembus.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _openGuidedBreathing(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(88, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Mulai Sesi',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    'Langkah-Langkah yang Perlu Dilakukan:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: instructions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              instructions[idx],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onComplete,
              icon: Icon(
                isCompleted ? Icons.check_circle : Icons.check,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                isCompleted
                    ? 'Sudah Diselesaikan Hari Ini'
                    : 'Saya Sudah Melakukan Latihan Ini',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? AppColors.successDark
                    : AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

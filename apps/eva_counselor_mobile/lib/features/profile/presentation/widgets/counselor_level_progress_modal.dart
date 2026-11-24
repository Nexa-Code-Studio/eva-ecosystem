import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/counselor_level_metrics_provider.dart';
import 'counselor_rate_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CounselorLevelProgressModal {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CounselorLevelProgressSheet(),
    );
  }
}

class _CounselorLevelProgressSheet extends ConsumerWidget {
  const _CounselorLevelProgressSheet();

  IconData _getIconData(String iconKey) {
    switch (iconKey.toLowerCase()) {
      case 'shield':
        return Icons.verified_user_rounded;
      case 'star':
        return Icons.stars_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(counselorLevelMetricsProvider);
    final user = ref.watch(authStateProvider).value;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: metricsAsync.when(
        loading: () => const SizedBox(
          height: 250,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'Gagal memuat status level: $err',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
        data: (metrics) {
          if (metrics == null) {
            return const SizedBox(
              height: 200,
              child: Center(child: Text('Data level belum tersedia.')),
            );
          }

          final next = metrics.nextLevel;
          final isMaxLevel = next == null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconData(metrics.badgeIcon),
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level ${metrics.levelTier}: ${metrics.levelName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Jenjang Reputasi Psikolog Mandiri',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Active Tier Status & Benefit Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tarif Sesi Berlaku',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Rp${metrics.activeSessionPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bagi Hasil Bersih Konselor',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Rp${metrics.netCounselorEarning.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} (${(100 - metrics.platformFeePercentage).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Next Level Progression or Max Level Banner
              if (!isMaxLevel) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Target ${next.levelName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${(metrics.progressFraction * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: metrics.progressFraction,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Target checklist items
                      _buildChecklistRow(
                        title: 'Jumlah Sesi Selesai',
                        current: '${metrics.totalCompletedSessions} sesi',
                        target: '${next.targetSessions} sesi',
                        isAchieved: metrics.totalCompletedSessions >=
                            next.targetSessions,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistRow(
                        title: 'Rata-rata Rating Kepuasan',
                        current: '${metrics.averageRating.toStringAsFixed(1)} ⭐',
                        target: 'Min. ${next.targetRating.toStringAsFixed(1)} ⭐',
                        isAchieved: metrics.averageRating >= next.targetRating,
                      ),
                      const SizedBox(height: 10),
                      _buildChecklistRow(
                        title: 'Akumulasi Jam Terbang',
                        current:
                            '${metrics.totalConsultationHours.toStringAsFixed(1)} jam',
                        target: '${next.targetHours.toStringAsFixed(1)} jam',
                        isAchieved: metrics.totalConsultationHours >=
                            next.targetHours,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.stars_rounded,
                          color: Color(0xFF16A34A), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level Tertinggi Tercapai! 👑',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Anda memiliki hak istimewa untuk menetapkan tarif konsultasi mandiri.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 4. Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    CounselorRateModal.show(
                      context: context,
                      user: user,
                      onSave: (_) {},
                    );
                  },
                  child: Text(
                    metrics.allowCustomPrice
                        ? 'Atur Tarif Sesi Mandiri'
                        : 'Lihat Ketentuan Tarif & Bagi Hasil',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChecklistRow({
    required String title,
    required String current,
    required String target,
    required bool isAchieved,
  }) {
    return Row(
      children: [
        Icon(
          isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: isAchieved ? const Color(0xFF16A34A) : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'Saat ini: $current • Target: $target',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

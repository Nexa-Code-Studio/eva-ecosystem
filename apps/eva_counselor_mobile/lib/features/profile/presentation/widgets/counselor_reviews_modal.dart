import 'package:flutter/material.dart';
import '../../../../core/widgets/app_async_state_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/counselor_level_metrics_provider.dart';

class CounselorReviewsModal {
  static void show(BuildContext context, {int totalSessions = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CounselorReviewsSheet(),
    );
  }
}

class _CounselorReviewsSheet extends ConsumerWidget {
  const _CounselorReviewsSheet();

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(counselorReviewsProvider(null));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E4EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ulasan & Penilaian Pasien',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: reviewsAsync.when(
                loading: () => AppAsyncStateView.loading(
                  title: 'Memuat ulasan pasien...',
                  message: 'Mengambil penilaian dan komentar sesi.',
                  compact: true,
                ),
                error: (err, _) => AppAsyncStateView.error(
                  title: 'Gagal memuat ulasan',
                  message: 'Ulasan pasien belum dapat dimuat saat ini.',
                  onRetry: () => ref.invalidate(counselorReviewsProvider(null)),
                  compact: true,
                ),
                data: (reviewsList) {
                  final reviews = reviewsList.items;
                  final hasReviews = reviews.isNotEmpty;

                  if (!hasReviews) {
                    return ListView(
                      controller: scrollController,
                      children: [
                        const SizedBox(height: 48),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7)
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_outline_rounded,
                                    size: 40, color: Color(0xFFD97706)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum Ada Ulasan Pasien',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Ulasan dan rating kepuasan pasien per sesi akan tampil di sini secara live setelah Anda menyelesaikan sesi telekonseling.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    controller: scrollController,
                    children: [
                      // Header Aggregate Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FD),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              children: [
                                Text(
                                  reviewsList.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < reviewsList.averageRating.floor()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: AppColors.warning,
                                      size: 16,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${reviewsList.total} Ulasan',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Container(
                                width: 1,
                                height: 50,
                                color: const Color(0xFFE2E5F0)),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Setiap ulasan terikat pada satu sesi konsultasi nyata dan langsung tercatat di database live.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List of Reviews
                      ...reviews.map((r) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFECEFF8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            AppColors.primaryContainer,
                                        child: Text(
                                          r.patientName.isNotEmpty
                                              ? r.patientName[0].toUpperCase()
                                              : 'P',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        r.patientName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: AppColors.warning, size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        r.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (r.label != null && r.label!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.label!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  Text(
                                    _formatDate(r.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              if (r.reviewText != null &&
                                  r.reviewText!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  r.reviewText!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                      height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

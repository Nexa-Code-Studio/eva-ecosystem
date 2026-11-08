import "package:flutter/material.dart";

import "../../../../widgets/glass_card.dart";
import "../../../../widgets/skeleton_shimmer.dart";

class RecommendationSkeletonLoader extends StatelessWidget {
  const RecommendationSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmerHost(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Condition Header Card Skeleton
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SkeletonCircle(size: 38),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLine(width: 140, height: 16),
                          SizedBox(height: 6),
                          SkeletonLine(width: 90, height: 12),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SkeletonLine(width: double.infinity, height: 13),
                  const SizedBox(height: 8),
                  const SkeletonLine(width: 220, height: 13),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Featured Activity Skeleton
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 110, height: 22, borderRadius: 8),
                  SizedBox(height: 14),
                  SkeletonLine(width: 200, height: 18),
                  SizedBox(height: 10),
                  SkeletonLine(width: double.infinity, height: 13),
                  SizedBox(height: 6),
                  SkeletonLine(width: 260, height: 13),
                  SizedBox(height: 16),
                  SkeletonBox(width: double.infinity, height: 44, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Activity List Skeletons
            ...List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SkeletonCircle(size: 42),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLine(width: 150, height: 15),
                            SizedBox(height: 8),
                            SkeletonLine(width: 100, height: 12),
                          ],
                        ),
                      ),
                      const SkeletonBox(width: 28, height: 28, borderRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

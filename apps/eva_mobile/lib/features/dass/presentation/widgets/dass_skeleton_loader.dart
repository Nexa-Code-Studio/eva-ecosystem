import 'package:flutter/material.dart';

import '../../../../widgets/glass_card.dart';
import '../../../../widgets/skeleton_shimmer.dart';

/// Shimmer skeleton loader for the DASS-21 Assessment Screen.
class DassSkeletonLoader extends StatelessWidget {
  const DassSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmerHost(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Three Score Summary Cards (Depresi, Kecemasan, Stres)
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == 2 ? 0 : 4,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Column(
                        children: const [
                          SkeletonCircle(size: 32),
                          SizedBox(height: 8),
                          SkeletonLine(width: 50, height: 12),
                          SizedBox(height: 6),
                          SkeletonLine(width: 40, height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Main Clinical Insight Card Skeleton
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SkeletonCircle(size: 40),
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
                  const SkeletonLine(width: 240, height: 13),
                  const SizedBox(height: 16),
                  const SkeletonBox(width: double.infinity, height: 40, borderRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Question Item Preview Skeletons
            ...List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 28, height: 28, borderRadius: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLine(width: 160, height: 14),
                            SizedBox(height: 6),
                            SkeletonLine(width: 110, height: 11),
                          ],
                        ),
                      ),
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

import 'package:flutter/material.dart';

import '../../../../widgets/glass_card.dart';
import '../../../../widgets/skeleton_shimmer.dart';

/// Shimmer skeleton loader for Emergency Contacts list.
class EmergencyContactsSkeletonLoader extends StatelessWidget {
  const EmergencyContactsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmerHost(
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SkeletonBox(width: 44, height: 44, borderRadius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLine(width: 140, height: 16),
                            SizedBox(height: 6),
                            SkeletonLine(width: 90, height: 12),
                          ],
                        ),
                      ),
                      const SkeletonBox(width: 60, height: 22, borderRadius: 6),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      SkeletonBox(width: 130, height: 28, borderRadius: 8),
                      Spacer(),
                      SkeletonCircle(size: 32),
                      SizedBox(width: 8),
                      SkeletonCircle(size: 32),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

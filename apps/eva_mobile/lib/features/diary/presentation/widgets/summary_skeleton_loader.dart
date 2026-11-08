import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Shimmer skeleton loader for AI Diary summary content.
class SummarySkeletonLoader extends StatefulWidget {
  const SummarySkeletonLoader({super.key});

  @override
  State<SummarySkeletonLoader> createState() => _SummarySkeletonLoaderState();
}

class _SummarySkeletonLoaderState extends State<SummarySkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _animation.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity * 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: MediaQuery.of(context).size.width * 0.78,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity * 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: MediaQuery.of(context).size.width * 0.52,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: opacity * 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        );
      },
    );
  }
}

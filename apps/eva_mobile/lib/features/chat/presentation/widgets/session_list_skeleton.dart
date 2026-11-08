import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

class SessionListSkeleton extends StatefulWidget {
  const SessionListSkeleton({super.key});

  @override
  State<SessionListSkeleton> createState() => _SessionListSkeletonState();
}

class _SessionListSkeletonState extends State<SessionListSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const List<double> _titleWidthFactors = [
    0.65,
    0.50,
    0.72,
    0.58,
    0.62,
    0.54,
    0.68,
    0.48,
    0.70,
    0.56,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
          children: List.generate(10, (index) {
            final titleWidth = _titleWidthFactors[index % _titleWidthFactors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: opacity * 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: titleWidth,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(alpha: opacity * 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.35,
                            child: Container(
                              height: 11,
                              decoration: BoxDecoration(
                                color: AppColors.textLight.withValues(alpha: opacity * 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.textLight.withValues(alpha: opacity * 0.14),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

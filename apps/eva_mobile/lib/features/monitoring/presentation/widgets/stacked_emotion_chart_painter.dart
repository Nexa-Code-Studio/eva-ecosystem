import 'dart:math';
import 'package:flutter/material.dart';

/// Custom Painter for 7-Emotion Vertical Stacked Bar Chart
class StackedEmotionChartPainter extends CustomPainter {
  final List<List<double>> chartData;
  final List<Color> emotionColors;

  StackedEmotionChartPainter({
    required this.chartData,
    required this.emotionColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    final int barCount = chartData.length;
    final double availableWidth = size.width;
    const double maxBarWidth = 28.0;
    final double barWidth = min(maxBarWidth, (availableWidth / barCount) * 0.45);

    for (int i = 0; i < barCount; i++) {
      final segments = chartData[i];
      final double centerX = (i + 0.5) * (availableWidth / barCount);
      final double barLeft = centerX - (barWidth / 2);
      double currentBottom = size.height;

      final double totalRatio = segments.fold(0.0, (sum, val) => sum + val);
      if (totalRatio <= 0) {
        // Draw subtle baseline indicator for empty bar slot
        final baseRect = Rect.fromLTRB(barLeft, size.height - 3, barLeft + barWidth, size.height);
        final basePaint = Paint()
          ..color = const Color(0xFFD8DCE8)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(2)), basePaint);
        continue;
      }

      for (int j = 0; j < segments.length; j++) {
        final double ratio = segments[j];
        if (ratio <= 0) continue;

        final double segHeight = (size.height - 4) * (ratio / totalRatio);
        final double top = currentBottom - segHeight;

        final rect = Rect.fromLTRB(barLeft, top, barLeft + barWidth, currentBottom);
        final paint = Paint()
          ..color = emotionColors[j % emotionColors.length]
          ..style = PaintingStyle.fill;

        final RRect rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(j == 0 ? 6 : 0),
          topRight: Radius.circular(j == 0 ? 6 : 0),
          bottomLeft: Radius.circular(j == segments.length - 1 ? 6 : 0),
          bottomRight: Radius.circular(j == segments.length - 1 ? 6 : 0),
        );

        canvas.drawRRect(rrect, paint);
        currentBottom = top;
      }
    }
  }

  @override
  bool shouldRepaint(covariant StackedEmotionChartPainter oldDelegate) {
    return oldDelegate.chartData != chartData;
  }
}

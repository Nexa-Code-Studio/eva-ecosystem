import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/counselor_timeline_entity.dart';

class PsychologistAvailabilityTimelineBar extends StatelessWidget {
  final CounselorTimelineEntity timeline;
  final TimeOfDay? selectedStartTime;
  final int durationMinutes;
  final ValueChanged<TimeOfDay> onTimeSelected;
  final CollisionResult collision;

  /// Optional override for current time cutoff (defaults to TimeOfDay.now() when timeline.date is today).
  final TimeOfDay? minSelectableTime;

  const PsychologistAvailabilityTimelineBar({
    super.key,
    required this.timeline,
    required this.selectedStartTime,
    required this.durationMinutes,
    required this.onTimeSelected,
    required this.collision,
    this.minSelectableTime,
  });

  static const Color _availableBarColor = Color(0xFFD1FAE5);
  static const Color _unavailableBarColor = Color(0xFF8886A4);

  int _effectiveMinStartMinutes() {
    final opHours = timeline.operatingHours;
    if (minSelectableTime != null) {
      final minMin = minSelectableTime!.hour * 60 + minSelectableTime!.minute;
      return minMin.clamp(opHours.startMinutes, opHours.endMinutes);
    }

    final now = DateTime.now();
    final isToday = timeline.date.year == now.year &&
        timeline.date.month == now.month &&
        timeline.date.day == now.day;
    if (!isToday) return opHours.startMinutes;

    final minBooking = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 2));
    if (minBooking.year != now.year ||
        minBooking.month != now.month ||
        minBooking.day != now.day) {
      return opHours.endMinutes;
    }

    final minMin = minBooking.hour * 60 + minBooking.minute;
    return minMin.clamp(opHours.startMinutes, opHours.endMinutes);
  }

  /// Merges past hours and all blocked ranges into contiguous unavailable intervals
  /// so adjacent or overlapping blocks render as a single seamless bar segment.
  List<({int start, int end})> _mergedUnavailableIntervals(
    OperatingHoursEntity opHours,
    int effectiveMinStart,
  ) {
    final intervals = <({int start, int end})>[];

    if (effectiveMinStart > opHours.startMinutes) {
      intervals.add((start: opHours.startMinutes, end: effectiveMinStart));
    }

    for (final blocked in timeline.blockedRanges) {
      final s = blocked.startMinutes.clamp(opHours.startMinutes, opHours.endMinutes);
      final e = blocked.endMinutes.clamp(opHours.startMinutes, opHours.endMinutes);
      if (e > s) {
        intervals.add((start: s, end: e));
      }
    }

    if (intervals.isEmpty) return const [];

    intervals.sort((a, b) => a.start.compareTo(b.start));

    final merged = <({int start, int end})>[intervals.first];
    for (int i = 1; i < intervals.length; i++) {
      final current = intervals[i];
      final last = merged.last;
      if (current.start <= last.end) {
        merged[merged.length - 1] = (
          start: last.start,
          end: current.end > last.end ? current.end : last.end,
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  void _handleTapOrDrag(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    final opHours = timeline.operatingHours;
    final totalSpan = opHours.totalSpanMinutes;
    if (totalSpan <= 0) return;

    final effectiveMinStart = _effectiveMinStartMinutes();
    final maxStartMinutes =
        (opHours.endMinutes - durationMinutes).clamp(opHours.startMinutes, opHours.endMinutes);

    // Seluruh jam operasional hari ini telah lewat atau tidak cukup untuk durasi sesi.
    if (effectiveMinStart > maxStartMinutes) return;

    final fraction = (localX / totalWidth).clamp(0.0, 1.0);
    final rawMinutes = opHours.startMinutes + (fraction * totalSpan).round();
    final selectedMinutes = rawMinutes.clamp(effectiveMinStart, maxStartMinutes);

    onTimeSelected(
      TimeOfDay(
        hour: selectedMinutes ~/ 60,
        minute: selectedMinutes % 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opHours = timeline.operatingHours;
    final totalSpan = opHours.totalSpanMinutes;
    final effectiveMinStart = _effectiveMinStartMinutes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar: Jam Buka & Jam Tutup
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Buka: ${opHours.startFormatted}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Tutup: ${opHours.endFormatted}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Interactive Timeline Progress Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final ratio = totalSpan > 0 ? width / totalSpan : 0.0;

            final unavailableIntervals =
                _mergedUnavailableIntervals(opHours, effectiveMinStart);

            // Kalkulasi posisi seleksi pengguna
            double? selLeft;
            double? selWidth;
            String? selRangeText;

            if (selectedStartTime != null && ratio > 0) {
              final selStartMin = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
              final selEndMin = selStartMin + durationMinutes;

              selLeft = ((selStartMin - opHours.startMinutes) * ratio).clamp(0.0, width);
              selWidth = (durationMinutes * ratio).clamp(0.0, width - selLeft);

              final endHour = (selEndMin ~/ 60).toString().padLeft(2, '0');
              final endMinute = (selEndMin % 60).toString().padLeft(2, '0');
              final startHour = selectedStartTime!.hour.toString().padLeft(2, '0');
              final startMinute = selectedStartTime!.minute.toString().padLeft(2, '0');
              selRangeText = '$startHour:$startMinute - $endHour:$endMinute';
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleTapOrDrag(details.localPosition.dx, width),
              onHorizontalDragUpdate: (details) => _handleTapOrDrag(details.localPosition.dx, width),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Bar Box (44px touch target)
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _availableBarColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(color: _availableBarColor),
                          ),

                          // Merged past hours & blocked ranges rendered seamlessly as one block
                          ...unavailableIntervals.map((interval) {
                            final left =
                                ((interval.start - opHours.startMinutes) * ratio)
                                    .clamp(0.0, width);
                            final right =
                                ((interval.end - opHours.startMinutes) * ratio)
                                    .clamp(0.0, width);
                            final segW = (right - left).clamp(0.0, width - left);
                            if (segW <= 0) return const SizedBox.shrink();

                            return Positioned(
                              left: left,
                              width: segW,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                key: const Key('timeline_unavailable_segment'),
                                color: _unavailableBarColor,
                              ),
                            );
                          }),

                          // Render Selected Range Overlay
                          if (selLeft != null && selWidth != null && selWidth > 0)
                            Positioned(
                              left: selLeft,
                              width: selWidth,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: collision.hasClash
                                      ? AppColors.error
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    collision.hasClash ? Icons.close_rounded : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Info Pilihan Waktu
                  if (selRangeText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pilihan: $selRangeText ($durationMinutes Menit)',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: collision.hasClash ? AppColors.error : AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Geser atau ketuk bar',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // Collision Warning Banner
        if (collision.hasClash && collision.reason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.errorDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    collision.reason!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.errorDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Simplified Color Legends: Tersedia & Tidak Tersedia only
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _buildLegendItem('Tersedia', AppColors.successDark),
            _buildLegendItem('Tidak Tersedia', _unavailableBarColor),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

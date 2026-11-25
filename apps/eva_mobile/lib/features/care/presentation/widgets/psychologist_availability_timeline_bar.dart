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

  const PsychologistAvailabilityTimelineBar({
    super.key,
    required this.timeline,
    required this.selectedStartTime,
    required this.durationMinutes,
    required this.onTimeSelected,
    required this.collision,
  });

  void _handleTapOrDrag(double localX, double totalWidth) {
    if (totalWidth <= 0) return;
    final totalSpan = timeline.operatingHours.totalSpanMinutes;
    if (totalSpan <= 0) return;

    final fraction = (localX / totalWidth).clamp(0.0, 1.0);
    final rawMinutes = timeline.operatingHours.startMinutes + (fraction * totalSpan).round();

    final maxStartMinutes =
        (timeline.operatingHours.endMinutes - durationMinutes)
            .clamp(timeline.operatingHours.startMinutes, timeline.operatingHours.endMinutes);
    final selectedMinutes = rawMinutes.clamp(
      timeline.operatingHours.startMinutes,
      maxStartMinutes,
    );

    final selected = TimeOfDay(
      hour: selectedMinutes ~/ 60,
      minute: selectedMinutes % 60,
    );

    onTimeSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final opHours = timeline.operatingHours;
    final totalSpan = opHours.totalSpanMinutes;

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
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
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
                  // Timeline Bar Box
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18), // Available green background
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        children: [
                          // Base green subtle pattern
                          Positioned.fill(
                            child: Container(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
                          ),

                          // Render Blocked Ranges (Break, Booked, Buffer)
                          ...timeline.blockedRanges.map((blocked) {
                            final bStart = blocked.startMinutes - opHours.startMinutes;
                            final bSpan = blocked.endMinutes - blocked.startMinutes;
                            if (bSpan <= 0) return const SizedBox.shrink();

                            final left = (bStart * ratio).clamp(0.0, width);
                            final segW = (bSpan * ratio).clamp(0.0, width - left);

                            Color segColor;
                            switch (blocked.type) {
                              case BlockedRangeType.breakTime:
                                segColor = const Color(0xFFF59E0B); // Amber / Orange
                                break;
                              case BlockedRangeType.booked:
                                segColor = const Color(0xFFEF4444); // Red
                                break;
                              case BlockedRangeType.buffer:
                                segColor = const Color(0xFF94A3B8); // Slate
                                break;
                            }

                            return Positioned(
                              left: left,
                              width: segW,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: segColor.withValues(alpha: 0.88),
                                  border: Border.symmetric(
                                    vertical: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
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
                                      ? const Color(0xFFDC2626) // Vivid red error
                                      : AppColors.primary, // Brand blue
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (collision.hasClash ? Colors.red : AppColors.primary)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
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

                  // Pill Info Pilihan Waktu
                  if (selRangeText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pilihan: $selRangeText ($durationMinutes Menit)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: collision.hasClash ? AppColors.error : AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Geser / tap untuk ubah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
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

        // Collision Warning Banner (Jika Menabrak Slot Lain / Istirahat)
        if (collision.hasClash && collision.reason != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    collision.reason!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Color Legends
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _buildLegendItem('Tersedia', const Color(0xFF10B981)),
            _buildLegendItem('Istirahat', const Color(0xFFF59E0B)),
            _buildLegendItem('Terisi', const Color(0xFFEF4444)),
            _buildLegendItem('Jeda Sesi', const Color(0xFF94A3B8)),
            _buildLegendItem('Pilihan Anda', AppColors.primary),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'counselor_duration_buffer_modal.dart';
import 'counselor_working_hours_modal.dart';

class CounselorProfileScheduleCard extends StatefulWidget {
  final List<String> days;
  final Set<String> activeDays;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String workingHours;
  final int sessionDuration;
  final int bufferTime;
  final bool isVacationMode;
  final Function(Set<String> activeDays) onDaysChanged;
  final Function(TimeOfDay start, TimeOfDay end) onHoursChanged;
  final Function(int duration, int buffer) onDurationBufferChanged;
  final ValueChanged<bool> onVacationModeChanged;

  const CounselorProfileScheduleCard({
    super.key,
    required this.days,
    required this.activeDays,
    required this.startTime,
    required this.endTime,
    required this.workingHours,
    required this.sessionDuration,
    required this.bufferTime,
    required this.isVacationMode,
    required this.onDaysChanged,
    required this.onHoursChanged,
    required this.onDurationBufferChanged,
    required this.onVacationModeChanged,
  });

  @override
  State<CounselorProfileScheduleCard> createState() => _CounselorProfileScheduleCardState();
}

class _CounselorProfileScheduleCardState extends State<CounselorProfileScheduleCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hari Praktik Aktif:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.days.map((day) {
              final isActive = widget.activeDays.contains(day);
              return GestureDetector(
                onTap: () {
                  final newDays = Set<String>.from(widget.activeDays);
                  if (isActive) {
                    if (newDays.length > 1) newDays.remove(day);
                  } else {
                    newDays.add(day);
                  }
                  widget.onDaysChanged(newDays);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : const Color(0xFFF7F8FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? AppColors.primary : const Color(0xFFECEFF8),
                      width: 1.2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        day,
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.textPrimary,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24, color: Color(0xFFF0F2F8)),
          InkWell(
            onTap: () => CounselorWorkingHoursModal.show(
              context: context,
              initialStart: widget.startTime,
              initialEnd: widget.endTime,
              onSave: widget.onHoursChanged,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Jam Operasional Praktik', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.workingHours,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => CounselorDurationBufferModal.show(
                    context: context,
                    initialDuration: widget.sessionDuration,
                    initialBuffer: widget.bufferTime,
                    onSave: widget.onDurationBufferChanged,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Durasi Sesi', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${widget.sessionDuration} Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => CounselorDurationBufferModal.show(
                    context: context,
                    initialDuration: widget.sessionDuration,
                    initialBuffer: widget.bufferTime,
                    onSave: widget.onDurationBufferChanged,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jeda Buffer', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${widget.bufferTime} Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF0F2F8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode Libur Sementara (Cuti)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(height: 2),
                  Text('Tutup sementara pemesanan slot jadwal baru', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
              Switch.adaptive(
                value: widget.isVacationMode,
                activeColor: AppColors.warning,
                onChanged: widget.onVacationModeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

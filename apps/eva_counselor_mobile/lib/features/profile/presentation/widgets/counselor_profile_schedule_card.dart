import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
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

  // Online & Offline Practice enhancements
  final PsychologistUserEntity? user;
  final Function(bool isOnline, bool isOffline)? onPracticeModesChanged;
  final VoidCallback? onEditOfflineAddress;
  final Function(List<String> days, String start, String end)? onOfflineScheduleChanged;

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
    this.user,
    this.onPracticeModesChanged,
    this.onEditOfflineAddress,
    this.onOfflineScheduleChanged,
  });

  @override
  State<CounselorProfileScheduleCard> createState() => _CounselorProfileScheduleCardState();
}

class _CounselorProfileScheduleCardState extends State<CounselorProfileScheduleCard> {
  void _showOfflineScheduleDialog() {
    final user = widget.user;
    if (user == null || user.isVolunteer || user.isPartner) return;

    final currentDays = Set<String>.from(user.offlineScheduleDays);
    String startTime = user.offlineStartTime;
    String endTime = user.offlineEndTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Jadwal Praktik Tatap Muka', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih hari dan rentang jam ketersediaan Anda di tempat praktik offline.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text('Hari Praktik Offline Aktif:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.days.map((d) {
                  final isSelected = currentDays.contains(d);
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        if (isSelected) {
                          if (currentDays.length > 1) currentDays.remove(d);
                        } else {
                          currentDays.add(d);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Jam Praktik Offline:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (picked != null) {
                          setModalState(() {
                            startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mulai', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('$startTime WIB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 16, minute: 0),
                        );
                        if (picked != null) {
                          setModalState(() {
                            endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selesai', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('$endTime WIB', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  widget.onOfflineScheduleChanged?.call(currentDays.toList(), startTime, endTime);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Jadwal Offline Diperbarui! 📅',
                    message: 'Slot jadwal tatap muka Anda telah disimpan.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Jadwal Offline', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isOnlineActive = user?.isOnlinePracticeEnabled ?? true;
    final isOfflineActive = user?.isOfflinePracticeEnabled ?? false;
    final isVolunteer = user?.isVolunteer == true;
    final isPartner = user?.isPartner == true;

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
          // 1. Mode Konseling: Volunteer Info Card VS Mode Layanan Switchers
          if (isVolunteer) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.volunteer_activism_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Relawan Teman Sebaya • Khusus Daring',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Layanan aktif untuk telekonseling curhat non-klinis via video call & chat aplikasi.',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'Mode Layanan Praktik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Option A: Telekonseling Online
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOnlineActive ? const Color(0xFFF0F4FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOnlineActive ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isOnlineActive ? AppColors.primary : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telekonseling Online',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Video call & chat aplikasi',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: isOnlineActive,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      if (!val && !isOfflineActive) {
                        TopToast.show(
                          context,
                          title: 'Minimal 1 Mode Aktif',
                          message: 'Anda harus mengaktifkan minimal salah satu mode praktik (Online atau Offline).',
                          type: ToastType.warning,
                        );
                        return;
                      }
                      widget.onPracticeModesChanged?.call(val, isOfflineActive);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Option B: Praktik Tatap Muka (Offline) - Opsional
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOfflineActive ? const Color(0xFFF5F3FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOfflineActive ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isOfflineActive ? AppColors.primary : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Flexible(
                              child: Text(
                                'Praktik Tatap Muka',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'Opsional',
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPartner
                              ? 'Dikelola ${user?.partnerName ?? "Mitra"} di Web'
                              : 'Offline di tempat praktik mandiri',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPartner) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'Web Mitra',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ] else ...[
                    Switch.adaptive(
                      value: isOfflineActive,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        if (!val && !isOnlineActive) {
                          TopToast.show(
                            context,
                            title: 'Minimal 1 Mode Aktif',
                            message: 'Anda harus mengaktifkan minimal salah satu mode praktik (Online atau Offline).',
                            type: ToastType.warning,
                          );
                          return;
                        }
                        widget.onPracticeModesChanged?.call(isOnlineActive, val);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // 2. Jadwal Hari & Jam Online
          if (isOnlineActive) ...[
            const Divider(height: 20, color: Color(0xFFF0F2F8)),
            const Text('Hari Praktik Online Aktif:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? AppColors.primary : const Color(0xFFECEFF8),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: isActive ? Colors.white : AppColors.textPrimary,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
                        Text('Jam Operasional Online', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
            const SizedBox(height: 12),
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
                              Text('${widget.sessionDuration} Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                              Text('${widget.bufferTime} Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
          ],

          // 3. Alamat & Jadwal Praktik Tatap Muka (Offline)
          if (isOfflineActive && !isVolunteer) ...[
            const Divider(height: 24, color: Color(0xFFF0F2F8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Alamat Praktik Tatap Muka',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (!isPartner)
                  InkWell(
                    onTap: widget.onEditOfflineAddress,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text('Ubah Alamat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          SizedBox(width: 2),
                          Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Diatur Mitra di Web', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user?.offlinePlaceName ?? (isPartner ? 'Klinik Mitra Sehati' : 'Biro Psikologi Mandiri Anindya'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${user?.offlineAddress ?? "Jl. Menteng Raya No. 42"}, ${user?.offlineCity ?? "Jakarta"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  if (user?.offlineNotes != null && user!.offlineNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.offlineNotes!,
                            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isPartner) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'ℹ️ Alamat praktik offline dan kuota ruangan dikelola oleh administrator mitra di web portal.',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF6B7280)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Hari & Jam Offline
            InkWell(
              onTap: isPartner ? null : _showOfflineScheduleDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Offline: ${(user?.offlineScheduleDays ?? const ["Sel", "Kam", "Sab"]).join(", ")}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${user?.offlineStartTime ?? "10:00"}-${user?.offlineEndTime ?? "16:00"}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        if (!isPartner) ...[
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

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
                activeThumbColor: AppColors.warning,
                onChanged: widget.onVacationModeChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

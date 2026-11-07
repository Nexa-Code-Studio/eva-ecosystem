import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';

class CounselorWorkingHoursModal {
  static String formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Future<void> show({
    required BuildContext context,
    required TimeOfDay initialStart,
    required TimeOfDay initialEnd,
    required Function(TimeOfDay start, TimeOfDay end) onSave,
  }) async {
    TimeOfDay tempStart = initialStart;
    TimeOfDay tempEnd = initialEnd;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
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
                  const Text('Ubah Jam Operasional Praktik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih jam mulai dan jam selesai praktik secara manual dengan tombol di bawah:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: tempStart,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => tempStart = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jam Mulai Praktik', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${formatTimeOfDay(tempStart)} WIB',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, color: AppColors.textLight, size: 18),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: tempEnd,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => tempEnd = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jam Selesai Praktik', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${formatTimeOfDay(tempEnd)} WIB',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Atau Pilih Preset Cepat:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('09:00 - 17:00 (Standar)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 9, minute: 0);
                      tempEnd = const TimeOfDay(hour: 17, minute: 0);
                    });
                  }),
                  _presetChip('08:00 - 16:00 (Pagi)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 8, minute: 0);
                      tempEnd = const TimeOfDay(hour: 16, minute: 0);
                    });
                  }),
                  _presetChip('13:00 - 21:00 (Sore)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 13, minute: 0);
                      tempEnd = const TimeOfDay(hour: 21, minute: 0);
                    });
                  }),
                  _presetChip('18:00 - 22:00 (Malam)', () {
                    setModalState(() {
                      tempStart = const TimeOfDay(hour: 18, minute: 0);
                      tempEnd = const TimeOfDay(hour: 22, minute: 0);
                    });
                  }),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  onSave(tempStart, tempEnd);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Jam Praktik Diperbarui',
                    message: 'Jam operasional berhasil disetel ke ${formatTimeOfDay(tempStart)} - ${formatTimeOfDay(tempEnd)} WIB',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Jam Operasional', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ),
    );
  }
}

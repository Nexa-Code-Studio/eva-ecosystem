import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';

class CounselorDurationBufferModal {
  static Future<void> show({
    required BuildContext context,
    required int initialDuration,
    required int initialBuffer,
    required Function(int duration, int buffer) onSave,
  }) async {
    const int lockedDuration = 30; // Sesi Paten Eva: 30 Menit
    int tempBuffer = initialBuffer;

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
                  const Text('Durasi Sesi & Jeda Istirahat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Durasi telekonseling standar platform dan waktu jeda antar sesi:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Locked 30-min Duration Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timer_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '30 Menit / Sesi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '(Paten Platform Eva)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Durasi setiap sesi dikunci 30 menit. Pasien dapat menambah sesi dinamis saat konsultasi aktif.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Buffer Time Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jeda Istirahat Antar Sesi (Buffer):',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove,
                              size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer >= 5) {
                              setModalState(() => tempBuffer -= 5);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$tempBuffer Menit',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add,
                              size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer < 30) {
                              setModalState(() => tempBuffer += 5);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0, 5, 10, 15, 20, 30].map((buf) {
                  final isSelected = tempBuffer == buf;
                  return GestureDetector(
                    onTap: () => setModalState(() => tempBuffer = buf),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '$buf Menit${buf == 10 ? " (Disarankan)" : ""}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  onSave(lockedDuration, tempBuffer);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Jeda Buffer Disimpan! ⏱️',
                    message:
                        'Durasi sesi 30 menit dengan jeda buffer $tempBuffer menit antar sesi berhasil diperbarui.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Pengaturan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

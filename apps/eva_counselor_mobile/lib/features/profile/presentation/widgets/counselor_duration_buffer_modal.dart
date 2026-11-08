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
    int tempDuration = initialDuration;
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
                  const Text('Durasi Sesi & Jeda Istirahat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tentukan durasi panggilan konsultasi dan waktu istirahat antar pasien secara fleksibel:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Durasi Konseling:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDuration > 15) {
                              setModalState(() => tempDuration -= 5);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$tempDuration Menit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempDuration < 180) {
                              setModalState(() => tempDuration += 5);
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
                children: [30, 45, 50, 60, 75, 90].map((dur) {
                  final isSelected = tempDuration == dur;
                  return GestureDetector(
                    onTap: () => setModalState(() => tempDuration = dur),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '$dur Mnt${dur == 50 ? " (Standar)" : ""}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jeda Istirahat (Buffer Time):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
                          icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer > 0) {
                              setModalState(() => tempBuffer -= 5);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '$tempBuffer Menit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (tempBuffer < 60) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF7F8FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFECEFF8),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        buf == 0 ? 'Tanpa Jeda' : '$buf Mnt${buf == 15 ? " (Disarankan)" : ""}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total slot waktu: ${tempDuration + tempBuffer} menit ($tempDuration mnt telekonseling + $tempBuffer mnt review SOAP).',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
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
                  onSave(tempDuration, tempBuffer);
                  Navigator.pop(ctx);
                  TopToast.show(
                    context,
                    title: 'Durasi Sesi Diperbarui',
                    message: 'Sesi ditetapkan ke $tempDuration menit dengan jeda istirahat $tempBuffer menit.',
                    type: ToastType.success,
                  );
                },
                child: const Text('Simpan Durasi Sesi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

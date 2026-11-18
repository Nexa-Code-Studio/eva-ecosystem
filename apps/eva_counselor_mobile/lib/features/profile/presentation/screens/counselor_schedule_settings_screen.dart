import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/counselor_duration_buffer_modal.dart';
import '../widgets/counselor_working_hours_modal.dart';

class CounselorScheduleSettingsScreen extends ConsumerStatefulWidget {
  const CounselorScheduleSettingsScreen({super.key});

  @override
  ConsumerState<CounselorScheduleSettingsScreen> createState() =>
      _CounselorScheduleSettingsScreenState();
}

class _CounselorScheduleSettingsScreenState
    extends ConsumerState<CounselorScheduleSettingsScreen> {
  final List<String> _allDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  late Set<String> _onlineDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  static const int _sessionDuration = 30; // Sesi Paten Eva: 30 Menit
  late int _bufferTime;
  late bool _isVacationMode;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _onlineDays = {'Sen', 'Sel', 'Rab', 'Kam', 'Jum'};
    _startTime = const TimeOfDay(hour: 9, minute: 0);
    _endTime = const TimeOfDay(hour: 17, minute: 0);
    _bufferTime = 10;
    _isVacationMode = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        _isVacationMode = !user.isOnline;
      }
      _isInitialized = true;
    }
  }

  String get _onlineHoursDisplay {
    final sH = _startTime.hour.toString().padLeft(2, '0');
    final sM = _startTime.minute.toString().padLeft(2, '0');
    final eH = _endTime.hour.toString().padLeft(2, '0');
    final eM = _endTime.minute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM WIB';
  }

  void _handleSave() {
    ref.read(authStateProvider.notifier).updateSessionSettings(
          sessionDurationMinutes: _sessionDuration,
          coinsPerSession: 0,
        );

    ref.read(authStateProvider.notifier).updateAvailability(!_isVacationMode);

    TopToast.show(
      context,
      title: 'Jadwal Berhasil Disimpan! 📅',
      message:
          'Jadwal telekonseling ($_sessionDuration mnt + buffer $_bufferTime mnt) telah diperbarui.',
      type: ToastType.success,
    );
    Navigator.pop(context);
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Jadwal Praktik Telekonseling',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. INFO STANDAR PLATFORM
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Layanan 100% Telekonseling Online',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Seluruh sesi konsultasi dilakukan melalui video call aman berdurasi paten 30 menit. Tidak ada jadwal tatap muka/offline.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. HARI & JAM OPERASIONAL
              _buildSectionTitle('Hari & Jam Praktik Online', Icons.calendar_month_rounded),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hari Praktik Daring Aktif:',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allDays.map((day) {
                        final isSelected = _onlineDays.contains(day);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                if (_onlineDays.length > 1) {
                                  _onlineDays.remove(day);
                                }
                              } else {
                                _onlineDays.add(day);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                              day,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24, color: Color(0xFFF0F2F8)),
                    const Text(
                      'Rentang Jam Operasional Telekonseling:',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => CounselorWorkingHoursModal.show(
                        context: context,
                        initialStart: _startTime,
                        initialEnd: _endTime,
                        onSave: (s, e) => setState(() {
                          _startTime = s;
                          _endTime = e;
                        }),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  _onlineHoursDisplay,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ],
                            ),
                            const Text(
                              'Ubah Jam ⚙️',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Durasi & Buffer
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => CounselorDurationBufferModal.show(
                              context: context,
                              initialDuration: _sessionDuration,
                              initialBuffer: _bufferTime,
                              onSave: (d, b) => setState(() {
                                _bufferTime = b;
                              }),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Durasi Sesi',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                      SizedBox(height: 2),
                                      Text('30 Menit (Paten)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5)),
                                    ],
                                  ),
                                  Icon(Icons.lock_outline,
                                      size: 14, color: AppColors.textSecondary),
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
                              initialDuration: _sessionDuration,
                              initialBuffer: _bufferTime,
                              onSave: (d, b) => setState(() {
                                _bufferTime = b;
                              }),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Jeda Buffer',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 2),
                                      Text('$_bufferTime Menit',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5)),
                                    ],
                                  ),
                                  const Icon(Icons.tune_rounded,
                                      size: 14, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. MODE LIBUR SEMENTARA
              _buildSectionTitle('Ketersediaan Layanan', Icons.beach_access_rounded),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isVacationMode
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pause_circle_outline_rounded,
                        color: _isVacationMode
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Libur Sementara (Cuti)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tutup sementara pemesanan slot jadwal baru tanpa mengubah jadwal rutin',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _isVacationMode,
                      activeTrackColor: AppColors.warning,
                      onChanged: (val) => setState(() => _isVacationMode = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. TOMBOL SIMPAN
              CustomButton(
                label: 'Simpan Perubahan Jadwal',
                onPressed: _handleSave,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

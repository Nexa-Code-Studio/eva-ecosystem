import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/schedule_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/counselor_duration_buffer_modal.dart';

class DayBreakItemModel {
  TimeOfDay start;
  TimeOfDay end;
  String label;

  DayBreakItemModel({
    required this.start,
    required this.end,
    this.label = 'Istirahat',
  });

  Map<String, dynamic> toJson() => {
        'start':
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
        'end':
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        'label': label,
      };
}

class DayConfigModel {
  bool isActive;
  TimeOfDay openTime;
  TimeOfDay closeTime;
  List<DayBreakItemModel> breaks;

  DayConfigModel({
    required this.isActive,
    required this.openTime,
    required this.closeTime,
    required this.breaks,
  });

  Map<String, dynamic> toJson() => {
        'is_active': isActive,
        'operating_hours': {
          'start':
              '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}',
          'end':
              '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}',
        },
        'breaks': breaks.map((b) => b.toJson()).toList(),
      };
}

class CounselorScheduleSettingsScreen extends ConsumerStatefulWidget {
  const CounselorScheduleSettingsScreen({super.key});

  @override
  ConsumerState<CounselorScheduleSettingsScreen> createState() =>
      _CounselorScheduleSettingsScreenState();
}

class _CounselorScheduleSettingsScreenState
    extends ConsumerState<CounselorScheduleSettingsScreen> {
  final List<String> _dayLabels = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  final List<String> _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  int _selectedDayIndex = 0;
  late List<DayConfigModel> _days;
  static const int _sessionDuration = 30; // Durasi Paten Eva: 30 Menit
  late int _bufferTime;
  bool _isVacationMode = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bufferTime = 10;
    _days = [
      // Senin
      DayConfigModel(
        isActive: true,
        openTime: const TimeOfDay(hour: 8, minute: 0),
        closeTime: const TimeOfDay(hour: 17, minute: 0),
        breaks: [
          DayBreakItemModel(
            start: const TimeOfDay(hour: 12, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
            label: 'Istirahat Siang',
          ),
        ],
      ),
      // Selasa
      DayConfigModel(
        isActive: true,
        openTime: const TimeOfDay(hour: 8, minute: 0),
        closeTime: const TimeOfDay(hour: 17, minute: 0),
        breaks: [
          DayBreakItemModel(
            start: const TimeOfDay(hour: 12, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
            label: 'Istirahat Siang',
          ),
        ],
      ),
      // Rabu
      DayConfigModel(
        isActive: true,
        openTime: const TimeOfDay(hour: 8, minute: 0),
        closeTime: const TimeOfDay(hour: 17, minute: 0),
        breaks: [
          DayBreakItemModel(
            start: const TimeOfDay(hour: 12, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
            label: 'Istirahat Siang',
          ),
        ],
      ),
      // Kamis
      DayConfigModel(
        isActive: true,
        openTime: const TimeOfDay(hour: 8, minute: 0),
        closeTime: const TimeOfDay(hour: 17, minute: 0),
        breaks: [
          DayBreakItemModel(
            start: const TimeOfDay(hour: 12, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
            label: 'Istirahat Siang',
          ),
        ],
      ),
      // Jumat (Multi Istirahat: Shalat Jumat + Istirahat Sore)
      DayConfigModel(
        isActive: true,
        openTime: const TimeOfDay(hour: 8, minute: 0),
        closeTime: const TimeOfDay(hour: 17, minute: 0),
        breaks: [
          DayBreakItemModel(
            start: const TimeOfDay(hour: 11, minute: 30),
            end: const TimeOfDay(hour: 13, minute: 0),
            label: 'Shalat Jumat & Istirahat',
          ),
          DayBreakItemModel(
            start: const TimeOfDay(hour: 15, minute: 30),
            end: const TimeOfDay(hour: 16, minute: 0),
            label: 'Istirahat Sore',
          ),
        ],
      ),
      // Sabtu (Libur)
      DayConfigModel(
        isActive: false,
        openTime: const TimeOfDay(hour: 9, minute: 0),
        closeTime: const TimeOfDay(hour: 14, minute: 0),
        breaks: [],
      ),
      // Minggu (Libur)
      DayConfigModel(
        isActive: false,
        openTime: const TimeOfDay(hour: 9, minute: 0),
        closeTime: const TimeOfDay(hour: 14, minute: 0),
        breaks: [],
      ),
    ];
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _addBreakToCurrentDay() {
    setState(() {
      _days[_selectedDayIndex].breaks.add(
            DayBreakItemModel(
              start: const TimeOfDay(hour: 12, minute: 0),
              end: const TimeOfDay(hour: 13, minute: 0),
              label: 'Istirahat Tambahan',
            ),
          );
    });
  }

  void _removeBreakFromCurrentDay(int breakIdx) {
    setState(() {
      _days[_selectedDayIndex].breaks.removeAt(breakIdx);
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    final scheduleConfigMap = <String, dynamic>{};
    for (int i = 0; i < _dayKeys.length; i++) {
      scheduleConfigMap[_dayKeys[i]] = _days[i].toJson();
    }

    try {
      if (!AppConfig.useMockData) {
        await ApiClient().put(
          ApiEndpoints.scheduleConfig,
          body: {
            'schedule_config': scheduleConfigMap,
            'buffer_time_minutes': _bufferTime,
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to save schedule_config remotely: $e');
    }

    ScheduleStorage.markConfigured();

    final curBreaks = _days[_selectedDayIndex].breaks;
    final bStart = curBreaks.isNotEmpty ? _formatTime(curBreaks.first.start) : '12:00';
    final bEnd = curBreaks.isNotEmpty ? _formatTime(curBreaks.first.end) : '13:00';

    ref.read(authStateProvider.notifier).updateSessionSettings(
          sessionDurationMinutes: _sessionDuration,
          coinsPerSession: 0,
          breakStartTime: bStart,
          breakEndTime: bEnd,
        );

    ref.read(authStateProvider.notifier).updateAvailability(!_isVacationMode);

    if (!mounted) return;
    setState(() => _isSaving = false);

    TopToast.show(
      context,
      title: 'Jadwal Praktik Berhasil Disimpan! 📅',
      message:
          'Pengaturan multi-istirahat dan jam operasional harian berhasil diperbarui di server.',
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
    final currentDay = _days[_selectedDayIndex];
    final currentDayName = _dayLabels[_selectedDayIndex];

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
          'Jadwal & Multi Jam Istirahat',
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
              // 1. INFO STANDAR TELEKONSELING
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
                            'Layanan 100% Telekonseling Daring',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Atur jam kerja dan jeda istirahat harian spesifik per hari. Slot booking pasien otomatis terkunci saat jam istirahat berlangsung.',
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

              // 2. TAB SELECTOR HARI (SENIN S/D MINGGU)
              _buildSectionTitle('Pilih Hari Praktik', Icons.calendar_month_rounded),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_dayLabels.length, (idx) {
                    final isSelected = idx == _selectedDayIndex;
                    final dayCfg = _days[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_dayLabels[idx]),
                            if (!dayCfg.isActive) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.block_rounded, size: 11, color: AppColors.textSecondary),
                            ],
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (_) => setState(() => _selectedDayIndex = idx),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),

              // 3. KARTU JADWAL HARI TERPILIH
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOGGLE STATUS BUKA / LIBUR HARI INI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: currentDay.isActive
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                currentDay.isActive
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.do_not_disturb_on_total_silence_rounded,
                                size: 16,
                                color: currentDay.isActive
                                    ? AppColors.verifiedGreen
                                    : AppColors.highRiskRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Praktik Hari $currentDayName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: currentDay.isActive,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) => setState(() => currentDay.isActive = val),
                        ),
                      ],
                    ),

                    if (!currentDay.isActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Jadwal hari ini dinonaktifkan (Libur). Pasien tidak dapat memesan sesi telekonseling.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Divider(height: 24, color: Color(0xFFF0F2F8)),

                      // JAM BUKA - JAM TUTUP OPERASIONAL
                      const Text(
                        'Jam Operasional Praktik:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: currentDay.openTime,
                                );
                                if (picked != null) {
                                  setState(() => currentDay.openTime = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Jam Buka', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTime(currentDay.openTime),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: currentDay.closeTime,
                                );
                                if (picked != null) {
                                  setState(() => currentDay.closeTime = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Jam Tutup', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTime(currentDay.closeTime),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // BUILDER MULTI JAM ISTIRAHAT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.coffee_rounded, size: 16, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Multi Jam Istirahat:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                            label: const Text(
                              '+ Tambah Istirahat',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            onPressed: _addBreakToCurrentDay,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (currentDay.breaks.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Tidak ada jam istirahat untuk hari ini. Jadwal buka terus menerus.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        )
                      else
                        ...currentDay.breaks.asMap().entries.map((entry) {
                          final bIdx = entry.key;
                          final brk = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '#${bIdx + 1} ${brk.label}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          size: 18, color: AppColors.highRiskRed),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeBreakFromCurrentDay(bIdx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: brk.start,
                                          );
                                          if (picked != null) {
                                            setState(() => brk.start = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Mulai: ${_formatTime(brk.start)}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              const Icon(Icons.schedule, size: 13, color: Color(0xFFB45309)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: brk.end,
                                          );
                                          if (picked != null) {
                                            setState(() => brk.end = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Selesai: ${_formatTime(brk.end)}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              const Icon(Icons.schedule, size: 13, color: Color(0xFFB45309)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. DURASI SESI & BUFFER JEDA
              _buildSectionTitle('Durasi Sesi & Jeda Buffer', Icons.tune_rounded),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durasi Sesi', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                SizedBox(height: 2),
                                Text('30 Menit (Paten)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ],
                            ),
                            Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                          ],
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
                          onSave: (d, b) => setState(() => _bufferTime = b),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Jeda Buffer', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('$_bufferTime Menit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
              ),
              const SizedBox(height: 16),

              // 5. MODE CUTI / LIBUR SEMENTARA
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
                        color: _isVacationMode ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pause_circle_outline_rounded,
                        color: _isVacationMode ? AppColors.warning : AppColors.textSecondary,
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tutup sementara pemesanan slot jadwal baru tanpa mengubah jadwal rutin harian',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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

              // 6. TOMBOL SIMPAN
              CustomButton(
                label: 'Simpan Jadwal Praktik',
                isLoading: _isSaving,
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

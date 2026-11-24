import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';

class CounselorFullScheduleScreen extends ConsumerStatefulWidget {
  const CounselorFullScheduleScreen({super.key});

  @override
  ConsumerState<CounselorFullScheduleScreen> createState() =>
      _CounselorFullScheduleScreenState();
}

class _CounselorFullScheduleScreenState
    extends ConsumerState<CounselorFullScheduleScreen> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  final List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final List<String> _weekdays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final patientsAsync = ref.watch(patientsListProvider);

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final firstWeekday = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    ).weekday; // 1 = Mon, 7 = Sun

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Semua Jadwal Praktik',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientsListProvider);
            await ref.read(patientsListProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MONTH SELECTOR CARD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                      onPressed: _prevMonth,
                      splashRadius: 20,
                    ),
                    Text(
                      '${_months[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                      onPressed: _nextMonth,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // FULL CALENDAR MONTH GRID CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // WEEKDAY HEADERS
                    Row(
                      children: _weekdays.map((day) {
                        final isSun = day == 'Min';
                        return Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSun ? AppColors.highRiskRed : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 10),

                    // GRID OF DAYS
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 6,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: (firstWeekday - 1) + daysInMonth,
                      itemBuilder: (context, index) {
                        if (index < firstWeekday - 1) {
                          return const SizedBox.shrink();
                        }
                        final dayNumber = index - (firstWeekday - 1) + 1;
                        final cellDate = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month,
                          dayNumber,
                        );
                        final isSelected = _isSameDay(cellDate, _selectedDate);
                        final isToday = _isSameDay(cellDate, now);
                        final isSunday = cellDate.weekday == 7;

                        // Dynamic session check from real patients data (no hardcoded dates)
                        final patientsList = patientsAsync.value ?? [];
                        final hasSession = patientsList.any((p) {
                          if (_isSameDay(cellDate, p.lastSessionDate) && p.totalCompletedSessions > 0) {
                            return true;
                          }
                          if (_isSameDay(cellDate, now) && p.upcomingSchedule != null) {
                            return true;
                          }
                          return false;
                        });

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDate = cellDate);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isToday
                                      ? AppColors.primaryContainer.withValues(alpha: 0.6)
                                      : (isSunday ? const Color(0xFFFFF1F2) : Colors.transparent)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isToday ? AppColors.primary : Colors.transparent),
                                width: isToday ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isSunday ? AppColors.highRiskRed : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (hasSession)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : AppColors.verifiedGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  const SizedBox(height: 5),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // SELECTED DAY DETAIL CARD
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jadwal: ${_selectedDate.day} ${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Istirahat: ${user?.breakStartTime ?? '12:00'} - ${user?.breakEndTime ?? '13:00'}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // SESSION CARDS FOR SELECTED DAY
              patientsAsync.when(
                data: (patients) {
                  final daySessions = <Map<String, dynamic>>[];
                  for (final p in patients) {
                    // Sesi Terjadwal (Upcoming)
                    if (_isSameDay(_selectedDate, now) && p.upcomingSchedule != null) {
                      daySessions.add({
                        'patient': p,
                        'isCompleted': false,
                        'time': p.upcomingSchedule?.timeRange ?? p.upcomingSchedule?.formattedTime ?? '10:00 - 10:30 WIB',
                        'statusText': p.upcomingSchedule?.statusText ?? 'Terjadwal',
                      });
                    }
                    // Sesi Selesai (Completed, e.g. Samsul)
                    if (_isSameDay(_selectedDate, p.lastSessionDate) && p.totalCompletedSessions > 0) {
                      final hour = p.lastSessionDate.hour.toString().padLeft(2, '0');
                      final minute = p.lastSessionDate.minute.toString().padLeft(2, '0');
                      daySessions.add({
                        'patient': p,
                        'isCompleted': true,
                        'time': 'Selesai ($hour:$minute WIB)',
                        'statusText': 'Selesai',
                      });
                    }
                  }

                  if (daySessions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.event_available_rounded, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Tidak ada sesi telekonseling',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Belum ada pasien yang booking pada tanggal ini.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: daySessions.map((item) {
                      final patient = item['patient'] as PatientEntity;
                      final isCompleted = item['isCompleted'] == true;
                      final timeLabel = item['time'] as String;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: patient.isHighRisk
                                  ? AppColors.highRiskBg
                                  : (isCompleted
                                      ? const Color(0xFFECFDF5)
                                      : AppColors.primaryContainer),
                              child: Text(
                                patient.name.substring(0, 1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: patient.isHighRisk
                                      ? AppColors.highRiskRed
                                      : (isCompleted
                                          ? const Color(0xFF10B981)
                                          : AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          patient.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFFECFDF5)
                                              : AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isCompleted ? 'Selesai' : 'Terjadwal',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isCompleted
                                                ? const Color(0xFF10B981)
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pukul $timeLabel • 30 Menit',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCompleted
                                    ? const Color(0xFFF1F5F9)
                                    : AppColors.primary,
                                foregroundColor: isCompleted
                                    ? AppColors.textPrimary
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  '/counselor-patient-detail',
                                  arguments: patient.id,
                                );
                              },
                              child: Text(
                                isCompleted ? 'Lihat Rekam' : 'Buka Rekam',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
}
}

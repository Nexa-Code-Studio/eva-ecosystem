import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/schedule_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/app_async_state_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finances/presentation/providers/finance_provider.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../profile/domain/entities/counselor_schedule_config_entity.dart';
import '../../../profile/presentation/providers/counselor_level_metrics_provider.dart';
import '../../../profile/presentation/screens/counselor_schedule_settings_screen.dart';
import '../providers/counselor_nav_provider.dart';
import '../providers/counselor_notification_provider.dart';

class CounselorHomeScreen extends ConsumerStatefulWidget {
  const CounselorHomeScreen({super.key});

  @override
  ConsumerState<CounselorHomeScreen> createState() => _CounselorHomeScreenState();
}

class _CounselorHomeScreenState extends ConsumerState<CounselorHomeScreen> {
  int _selectedCalendarIndex = 0;
  late List<Map<String, dynamic>> _calendarDays;
  late String _monthYearLabel;
  bool _isSchedulePersistentlyConfigured = true;

  @override
  void initState() {
    super.initState();
    _initDynamicCalendar();
    _checkPersistedSchedule();
  }

  Future<void> _checkPersistedSchedule() async {
    final isConfigured = await ScheduleStorage.isConfigured();
    if (mounted) {
      setState(() => _isSchedulePersistentlyConfigured = isConfigured);
    }
  }

  void _initDynamicCalendar() {
    final now = DateTime.now();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    _monthYearLabel = '${months[now.month - 1]} ${now.year}';

    // Monday as start of current week (ISO 8601: Monday=1, Sunday=7)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    _calendarDays = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final isWeekend = index >= 5;

      final List<Map<String, dynamic>> sessions = [];
      return {
        'day': dayNames[index],
        'date': '${date.day}',
        'fullDate': date,
        'isToday': isToday,
        'hasSession': false,
        'isHighRisk': false,
        'isOffDay': isWeekend,
        'sessions': sessions,
      };
    });

    _selectedCalendarIndex = now.weekday - 1;
  }

  String _formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _shortMonthLabel(int month) {
    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return shortMonths[(month - 1).clamp(0, 11)];
  }

  int _parseTimeToMinutes(String raw, {int fallback = 0}) {
    final parts = raw.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return h * 60 + m;
  }

  String _formatBookingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'confirmed':
      case 'upcoming':
        return 'Terjadwal';
      case 'live':
      case 'in_progress':
        return 'Berlangsung';
      case 'pending_payment':
      case 'pending':
        return 'Menunggu';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }

  Future<void> _openScheduleSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CounselorScheduleSettingsScreen(),
      ),
    );
    if (!mounted) return;
    ref.invalidate(counselorDailyTimelineProvider);
    ref.invalidate(counselorScheduleConfigProvider);
    await _checkPersistedSchedule();
  }

  bool _isWeekdayActive(PsychologistUserEntity? user, DateTime date, int weekdayIndex) {
    final schedule = user?.scheduleConfig;
    if (schedule == null || schedule.isEmpty) {
      return weekdayIndex < 5;
    }
    final key = weekdayKeyFromDate(date);
    final rawDay = schedule[key];
    if (rawDay is Map) {
      return rawDay['is_active'] != false;
    }
    return weekdayIndex < 5;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final patientsAsync = ref.watch(patientsListProvider);
    final patients = patientsAsync.value ?? [];

    for (int i = 0; i < _calendarDays.length; i++) {
      final date = _calendarDays[i]['fullDate'] as DateTime;
      _calendarDays[i]['isOffDay'] = !_isWeekdayActive(user, date, i);
    }

    final selectedDayData = _calendarDays[_selectedCalendarIndex];
    final selectedDate = selectedDayData['fullDate'] as DateTime;
    final selectedDateIso = _formatIsoDate(selectedDate);
    final now = DateTime.now();
    final isSelectedDayToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    final timelineAsync =
        ref.watch(counselorDailyTimelineProvider(selectedDateIso));
    final timeline = timelineAsync.value;

    // Dynamically derive fallback today's sessions from patient list
    final List<Map<String, dynamic>> realTodaySessions = [];
    for (final p in patients) {
      if (p.upcomingSchedule != null) {
        realTodaySessions.add({
          'time': p.upcomingSchedule!.timeRange.isNotEmpty
              ? p.upcomingSchedule!.timeRange
              : (p.upcomingSchedule!.formattedTime.isNotEmpty
                  ? p.upcomingSchedule!.formattedTime
                  : 'Terjadwal Hari Ini'),
          'patientName': '${p.name} (${p.age} Thn)',
          'chiefComplaint': p.chiefComplaint,
          'status': '',
          'isLive': true,
          'patientId': p.id,
          'sessionId': p.upcomingSchedule!.sessionId,
        });
      } else if (p.totalCompletedSessions > 0) {
        realTodaySessions.add({
          'time': 'Selesai',
          'patientName': '${p.name} (${p.age} Thn)',
          'chiefComplaint': p.chiefComplaint,
          'status': 'Selesai',
          'isCompleted': true,
          'patientId': p.id,
          'sessionId': 'session-prev-${p.id}',
        });
      }
    }

    final todayWeekdayIndex = now.weekday - 1;
    if (todayWeekdayIndex >= 0 && todayWeekdayIndex < _calendarDays.length) {
      _calendarDays[todayWeekdayIndex]['hasSession'] =
          realTodaySessions.isNotEmpty ||
              (isSelectedDayToday && (timeline?.bookedSessions.isNotEmpty ?? false));
    }

    final List<Map<String, dynamic>> selectedSessions;
    if (timeline != null) {
      selectedSessions = timeline.bookedSessions
          .map((b) => {
                'time': '${b.start} - ${b.end}',
                'patientName': b.patientName,
                'chiefComplaint':
                    (b.complaints != null && b.complaints!.trim().isNotEmpty)
                        ? b.complaints!.trim()
                        : 'Sesi Konseling (${b.durationMinutes} Menit)',
                'status': _formatBookingStatus(b.status),
                'isLive': b.status == 'live' ||
                    b.status == 'in_progress' ||
                    (isSelectedDayToday &&
                        (b.status == 'scheduled' || b.status == 'confirmed')),
                'isHighRisk': false,
                'patientId': b.patientId,
                'sessionId': b.sessionId,
              })
          .toList();
      selectedDayData['hasSession'] = selectedSessions.isNotEmpty;
    } else if (isSelectedDayToday && realTodaySessions.isNotEmpty) {
      selectedSessions = realTodaySessions;
    } else {
      selectedSessions =
          (selectedDayData['sessions'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
    }

    final isSelectedDayOnline = timeline?.isOnline ?? (user?.isOnline ?? true);
    final isSelectedDayActive =
        timeline?.isActive ?? (selectedDayData['isOffDay'] != true);
    final isSelectedDayOff = !isSelectedDayOnline || !isSelectedDayActive;

    // Unread notifications count
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    // Upcoming consultation patient (real active patient with upcoming session)
    final upcomingPatient = patients.where((p) => p.upcomingSchedule != null).isNotEmpty
        ? patients.firstWhere((p) => p.upcomingSchedule != null)
        : null;
    final highRiskPatients = patients.where((p) => p.isHighRisk).toList();

    // Financial & session metrics (dynamically calculated)
    final financesAsync = ref.watch(financialSummaryProvider);
    final finances = financesAsync.value;
    final activePatientsCount = patients.length;
    final completedSessionsCount =
        patients.fold<int>(0, (sum, p) => sum + p.totalCompletedSessions);
    final balanceAmount = finances?.availableBalance ??
        (user?.coinBalance != null ? (user!.coinBalance * 1000) : 0);
    final balanceFormatted = 'Rp ${balanceAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientsListProvider);
            ref.invalidate(financialSummaryProvider);
            ref.invalidate(counselorScheduleConfigProvider);
            ref.invalidate(counselorDailyTimelineProvider(selectedDateIso));
            await Future.wait([
              ref.read(patientsListProvider.future),
              ref
                  .read(counselorDailyTimelineProvider(selectedDateIso).future)
                  .catchError((_) => CounselorDailyTimelineEntity.empty(selectedDateIso)),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR: Logo Resmi EVA & Notifikasi Halaman
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/images/eva_logo_square.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.psychology_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'EVA',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'COUNSELOR',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Dashboard Konselor Klinis',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/counselor-notifications');
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                        if (unreadNotifs > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                '$unreadNotifs',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. PROFILE & STATUS PILL (SESUAI GAMBAR REFERENSI: BUKAN TOGGLE SWITCH)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: getProfileImageProvider(user?.profilePhotoUrl),
                          child: getProfileImageProvider(user?.profilePhotoUrl) == null
                              ? const Icon(Icons.person, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.verifiedGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Psikolog Mandiri',
                            style: AppTypography.headingSmall.copyWith(fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusBadge.proIndependent('Psikolog Mandiri'),
                              StatusBadge.coins(user?.coinBalance ?? 0),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // STATUS PRAKTIK OTOMATIS (Berdasarkan Jam Operasional & Jam Istirahat Terjadwal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (isSelectedDayOnline && isSelectedDayActive)
                            ? AppColors.verifiedGreen
                            : AppColors.highRiskRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final selectedDayKey = weekdayKeyFromDate(selectedDate);
                          final fallbackDayCfg = user?.scheduleConfig[selectedDayKey];
                          final fallbackBreaks = fallbackDayCfg is Map<String, dynamic>
                              ? (fallbackDayCfg['breaks'] as List<dynamic>? ?? const [])
                                  .whereType<Map<String, dynamic>>()
                                  .map((b) => '${b['start'] ?? '12:00'}-${b['end'] ?? '13:00'}')
                                  .toList()
                              : (user?.todayBreaks
                                      .map((b) =>
                                          '${b['start'] ?? '12:00'}-${b['end'] ?? '13:00'}')
                                      .toList() ??
                                  const <String>[]);
                          final breakRanges = timeline != null
                              ? timeline.blockedRanges
                                  .where((r) => r.type == 'break')
                                  .map((r) => '${r.start}-${r.end}')
                                  .toList()
                              : fallbackBreaks;
                          final String statusText;
                          if (!isSelectedDayOnline) {
                            statusText = 'Mode Cuti • Pemesanan Ditutup';
                          } else if (!isSelectedDayActive) {
                            statusText = 'Hari Libur Praktik (Offline)';
                          } else if (breakRanges.isEmpty) {
                            statusText = 'Aktif • Tanpa Jam Istirahat';
                          } else {
                            statusText =
                                'Aktif • Istirahat ${breakRanges.join(', ')}';
                          }
                          return Text(
                            statusText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _openScheduleSettings,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Ubah',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildDailyTimelineProgressBar(
                user: user,
                timeline: timeline,
                timelineAsync: timelineAsync,
                selectedDate: selectedDate,
                selectedDateIso: selectedDateIso,
              ),
              const SizedBox(height: 16),

              // 3. UPCOMING TELECONSULTATION HERO CARD (Hidden if no session scheduled today)
              if (upcomingPatient != null) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4B53BB),
                        Color(0xFF6B72E5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4B53BB).withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Badges
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      upcomingPatient.upcomingSchedule?.formattedTime ??
                                          'Sesi Konsultasi Terjadwal Hari Ini',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Patient Photo + Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 66,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withValues(alpha: 0.2),
                              image: const DecorationImage(
                                image: NetworkImage(
                                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${upcomingPatient.name} (${upcomingPatient.age} Thn)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  upcomingPatient.chiefComplaint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Durasi 30 Menit • Video Call',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  '/counselor-patient-detail',
                                  arguments: upcomingPatient.id,
                                );
                              },
                              child: const Text(
                                'Rekam Medis',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.videocam_rounded, size: 17),
                              label: const Text(
                                'Masuk Sesi VC',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () async {
                                final sessionId = upcomingPatient.upcomingSchedule?.sessionId;
                                if (sessionId == null || sessionId.isEmpty) return;
                                final finished = await Navigator.of(context).pushNamed(
                                  '/counselor-video-call',
                                  arguments: sessionId,
                                );
                                if (finished == true && context.mounted) {
                                  Navigator.of(context).pushNamed(
                                    '/counselor-patient-detail',
                                    arguments: {
                                      'patientId': upcomingPatient.id,
                                      'sessionFinished': true,
                                      'sessionId': sessionId,
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else if (!_isSchedulePersistentlyConfigured && user?.isScheduleConfigured != true && user?.isOnlinePracticeEnabled != true) ...[
                // Onboarding Banner: Setup Practice Schedule
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.edit_calendar_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Atur Jadwal Praktik Anda',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Pasien belum dapat booking sesi sebelum Anda menentukan hari & jam praktik.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.tune_rounded, size: 14),
                                label: const Text(
                                  'Atur Jadwal Sekarang',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _openScheduleSettings,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                // Clean Active Schedule State: No session scheduled today
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.verifiedBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.verifiedGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tidak Ada Sesi Konsultasi Hari Ini',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Jadwal telekonseling Anda aktif. Sesi akan otomatis terisi saat pasien melakukan booking.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 30,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFD0D4E5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                icon: const Icon(Icons.tune_rounded, size: 13, color: AppColors.primary),
                                label: const Text(
                                  'Kelola Jam Praktik',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                onPressed: _openScheduleSettings,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 5. HORIZONTAL SCHEDULE MINI-CALENDAR STRIP (LENGKAP 7 HARI)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Jadwal Praktik • $_monthYearLabel',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                    label: const Text(
                      'Lihat Semua',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/counselor-full-schedule');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _calendarDays.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final item = _calendarDays[idx];
                    final isSelected = _selectedCalendarIndex == idx;
                    final isToday = item['isToday'] == true;
                    final isOffDay = item['isOffDay'] == true;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCalendarIndex = idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isOffDay ? AppColors.highRiskRed : AppColors.primary)
                              : (isOffDay ? AppColors.highRiskBg : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? (isOffDay ? AppColors.highRiskRed : AppColors.primary)
                                : (isOffDay
                                    ? AppColors.highRiskRed.withValues(alpha: 0.3)
                                    : (isToday ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFECEFF8))),
                            width: (isToday || isOffDay) ? 1.4 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: (isOffDay ? AppColors.highRiskRed : AppColors.primary).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['day'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white70
                                    : (isOffDay ? AppColors.highRiskRed : AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['date'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (isOffDay ? AppColors.highRiskRed : AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (isOffDay)
                              Text(
                                'Libur',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.highRiskRed,
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (item['hasSession'] == true)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (item['isHighRisk'] == true)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: const BoxDecoration(
                                        color: AppColors.highRiskRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // 6. DETAIL SLOT JADWAL HARIAN (INTERAKTIF & BISA KLIK MENUJU REKAM PASIEN)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sesi ${selectedDayData['day']}, ${selectedDayData['date']} ${_shortMonthLabel(selectedDate.month)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          !isSelectedDayOnline
                              ? 'Mode Cuti'
                              : (isSelectedDayOff
                                  ? 'Libur Praktik'
                                  : '${selectedSessions.length} Booking'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelectedDayOff ? FontWeight.bold : FontWeight.normal,
                            color: isSelectedDayOff ? AppColors.highRiskRed : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (timelineAsync.isLoading && timeline == null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Memuat jadwal & daftar booking...',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ] else if (timelineAsync.hasError && timeline == null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.highRiskBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.highRiskRed),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Gagal memuat jadwal dari server.',
                                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                counselorDailyTimelineProvider(selectedDateIso),
                              ),
                              child: const Text('Coba Lagi', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isSelectedDayOff) ...[
                      // TAMPILAN JADWAL LIBUR / CUTI (OFFLINE)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.highRiskBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.highRiskRed.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_busy_rounded, color: AppColors.highRiskRed, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    !isSelectedDayOnline
                                        ? 'Mode Cuti Sementara Aktif (Offline)'
                                        : 'Hari Libur Praktik (Offline)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.highRiskRed),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Semua slot konsultasi ditutup pada hari ini. Pasien tidak dapat melakukan reservasi baru.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedSessions.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Tidak ada jadwal konsultasi pada hari ini.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ] else ...[
                      ...selectedSessions.map((session) {
                        final isLive = session['isLive'] == true;
                        final isRisk = session['isHighRisk'] == true;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (session['patientId'] != null) {
                              Navigator.of(context).pushNamed(
                                '/counselor-patient-detail',
                                arguments: session['patientId'],
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLive
                                  ? AppColors.primaryContainer.withValues(alpha: 0.35)
                                  : (isRisk
                                      ? AppColors.highRiskBg.withValues(alpha: 0.6)
                                      : const Color(0xFFF7F8FC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isLive
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : (isRisk ? AppColors.highRiskRed.withValues(alpha: 0.2) : const Color(0xFFECEFF8)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session['time'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                                    ),
                                    if ((session['status'] as String? ?? '').isNotEmpty && !isLive) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        session['status'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isRisk ? AppColors.highRiskRed : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session['patientName'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        session['chiefComplaint'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isLive)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      final sessId = session['sessionId'] as String?;
                                      if (sessId != null && sessId.isNotEmpty) {
                                        Navigator.of(context).pushNamed(
                                          '/counselor-video-call',
                                          arguments: sessId,
                                        );
                                      }
                                    },
                                    child: const Text('Buka VC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                else if (session['patientId'] != null)
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 7. 2x2 METRIC CARDS (Clean, Soft Borders)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.people_outline_rounded, color: AppColors.primary, size: 18),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.verifiedBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  activePatientsCount > 0 ? '+$activePatientsCount' : '0',
                                  style: const TextStyle(
                                    color: AppColors.verifiedGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$activePatientsCount',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('Pasien Aktif', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 18),
                              ),
                              const Text('Bulan ini', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$completedSessionsCount',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('Sesi Selesai', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(counselorBottomNavIndexProvider.notifier).state = 2;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.tertiary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 18),
                                ),
                                const Text('Tarik', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              balanceFormatted,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text('Saldo Praktik', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (highRiskPatients.isNotEmpty) {
                          Navigator.of(context).pushNamed(
                            '/counselor-patient-detail',
                            arguments: highRiskPatients.first.id,
                          );
                        } else {
                          ref.read(counselorBottomNavIndexProvider.notifier).state = 1;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.highRiskBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.highRiskRed.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.crisis_alert_rounded, color: AppColors.highRiskRed, size: 18),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    highRiskPatients.isNotEmpty ? 'Perhatian' : 'Aman',
                                    style: TextStyle(
                                      color: highRiskPatients.isNotEmpty ? AppColors.highRiskRed : AppColors.verifiedGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${highRiskPatients.length} Pasien',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: highRiskPatients.isNotEmpty ? AppColors.highRiskRed : AppColors.verifiedGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              highRiskPatients.isNotEmpty ? 'Peringatan Berisiko' : 'Risiko Terkendali',
                              style: TextStyle(
                                fontSize: 11,
                                color: highRiskPatients.isNotEmpty ? AppColors.highRiskRed : AppColors.verifiedGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 8. RECENT PATIENTS LIST
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar Pasien Konseling', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () {
                      ref.read(counselorBottomNavIndexProvider.notifier).state = 1;
                    },
                    child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              patientsAsync.when(
                data: (patients) {
                  if (patients.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 36, color: AppColors.textLight),
                          SizedBox(height: 8),
                          Text(
                            'Belum Ada Pasien Terdaftar',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pasien yang menjadwalkan sesi telekonsultasi akan otomatis muncul di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: patients.take(3).map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFECEFF8)),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/counselor-patient-detail',
                              arguments: p.id,
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: p.isHighRisk
                                    ? AppColors.highRiskBg
                                    : AppColors.primaryContainer,
                                child: Text(
                                  p.name.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.isHighRisk
                                        ? AppColors.highRiskRed
                                        : AppColors.primary,
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
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (p.upcomingSchedule != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p.upcomingSchedule!.timeRange.isNotEmpty
                                                  ? p.upcomingSchedule!.timeRange
                                                  : 'Terjadwal',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.chiefComplaint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              p.hasConsent
                                  ? StatusBadge.consentGranted('Akses Ada')
                                  : StatusBadge.consentLocked('Terkunci'),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => AppAsyncStateView.loading(
                  title: 'Memuat daftar pasien...',
                  message: 'Mengambil jadwal konsultasi dan status persetujuan pasien.',
                  compact: true,
                ),
                error: (e, _) => AppAsyncStateView.error(
                  title: 'Gagal memuat daftar pasien',
                  message: 'Periksa koneksi Anda lalu coba muat ulang data pasien.',
                  onRetry: () => ref.invalidate(patientsListProvider),
                  compact: true,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 104),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDailyTimelineProgressBar({
    required PsychologistUserEntity? user,
    required CounselorDailyTimelineEntity? timeline,
    required AsyncValue<CounselorDailyTimelineEntity> timelineAsync,
    required DateTime selectedDate,
    required String selectedDateIso,
  }) {
    final selectedDayKey = weekdayKeyFromDate(selectedDate);
    final selectedDayCfg = user?.scheduleConfig[selectedDayKey];
    final opHours = selectedDayCfg is Map<String, dynamic>
        ? selectedDayCfg['operating_hours']
        : user?.todayScheduleConfig?['operating_hours'];
    final fallbackStart =
        opHours is Map ? (opHours['start'] as String? ?? '08:00') : '08:00';
    final fallbackEnd =
        opHours is Map ? (opHours['end'] as String? ?? '17:00') : '17:00';
    final opStart = timeline?.operatingStart ?? fallbackStart;
    final opEnd = timeline?.operatingEnd ?? fallbackEnd;
    final fallbackIsActive = selectedDayCfg is Map<String, dynamic>
        ? (selectedDayCfg['is_active'] as bool? ?? true)
        : (user?.isTodayPracticeActive ?? true);
    final isActive = timeline?.isActive ?? fallbackIsActive;
    final isOnline = timeline?.isOnline ?? user?.isOnline ?? true;

    final startMinutes = _parseTimeToMinutes(opStart, fallback: 8 * 60);
    final endMinutes = _parseTimeToMinutes(opEnd, fallback: 17 * 60);

    final fallbackBreaks = selectedDayCfg is Map<String, dynamic>
        ? (selectedDayCfg['breaks'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((b) => CounselorBlockedRangeEntity(
                  start: b['start']?.toString() ?? '12:00',
                  end: b['end']?.toString() ?? '13:00',
                  type: 'break',
                  label: b['label']?.toString() ?? 'Istirahat',
                ))
            .toList()
        : (user?.todayBreaks ?? const <Map<String, String>>[])
            .map((b) => CounselorBlockedRangeEntity(
                  start: b['start'] ?? '12:00',
                  end: b['end'] ?? '13:00',
                  type: 'break',
                  label: b['label'] ?? 'Istirahat',
                ))
            .toList();

    final breakRanges = timeline != null
        ? timeline.blockedRanges.where((r) => r.type == 'break').toList()
        : fallbackBreaks;
    final bookedRanges = timeline != null
        ? timeline.blockedRanges.where((r) => r.type == 'booked').toList()
        : const <CounselorBlockedRangeEntity>[];

    final segments = <Map<String, dynamic>>[];
    if (isOnline && isActive && endMinutes > startMinutes) {
      final blocks = <Map<String, dynamic>>[
        ...breakRanges.map((b) => {
              'start': _parseTimeToMinutes(b.start, fallback: startMinutes),
              'end': _parseTimeToMinutes(b.end, fallback: startMinutes),
              'type': 'break',
            }),
        ...bookedRanges.map((b) => {
              'start': _parseTimeToMinutes(b.start, fallback: startMinutes),
              'end': _parseTimeToMinutes(b.end, fallback: startMinutes),
              'type': 'booked',
            }),
      ]..sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

      int cursor = startMinutes;
      for (final block in blocks) {
        final bStart = (block['start'] as int).clamp(startMinutes, endMinutes);
        final bEnd = (block['end'] as int).clamp(startMinutes, endMinutes);
        if (bStart > cursor) {
          segments.add({'flex': bStart - cursor, 'type': 'available'});
        }
        if (bEnd > bStart && bEnd > cursor) {
          final effectiveStart = bStart > cursor ? bStart : cursor;
          segments.add({'flex': bEnd - effectiveStart, 'type': block['type']});
          cursor = bEnd;
        }
      }
      if (cursor < endMinutes) {
        segments.add({'flex': endMinutes - cursor, 'type': 'available'});
      }
    }

    final breakLabel = breakRanges.isEmpty
        ? 'Tanpa Istirahat'
        : breakRanges.map((b) => '${b.start}-${b.end}').join(', ');
    final bookedCount = timeline?.bookedSessions.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Timeline Jam Praktik Hari Ini',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOnline && isActive)
                      ? AppColors.primaryContainer
                      : AppColors.highRiskBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  !isOnline
                      ? 'Cuti (Offline)'
                      : (!isActive ? 'Libur Praktik' : '$opStart - $opEnd WIB'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: (isOnline && isActive)
                        ? AppColors.primary
                        : AppColors.highRiskRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: (!isOnline || !isActive || segments.isEmpty)
                  ? Container(
                      color: (!isOnline || !isActive)
                          ? AppColors.highRiskRed.withValues(alpha: 0.35)
                          : const Color(0xFFE2E8F0),
                    )
                  : Row(
                      children: [
                        for (int i = 0; i < segments.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            flex: (segments[i]['flex'] as int).clamp(1, 1440),
                            child: Container(
                              color: segments[i]['type'] == 'booked'
                                  ? const Color(0xFF2563EB)
                                  : (segments[i]['type'] == 'break'
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981).withValues(alpha: 0.72)),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend / Indicators (Wrap prevents RenderFlex overflow on small screens)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendDot(const Color(0xFF2563EB), 'Terbooking ($bookedCount)'),
              _buildLegendDot(const Color(0xFFF59E0B), 'Istirahat ($breakLabel)'),
              _buildLegendDot(const Color(0xFF10B981), 'Tersedia'),
            ],
          ),
          if (timelineAsync.hasError && timeline == null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => ref.invalidate(
                counselorDailyTimelineProvider(selectedDateIso),
              ),
              child: const Text(
                'Gagal menyinkronkan timeline. Ketuk untuk coba lagi.',
                style: TextStyle(fontSize: 10, color: AppColors.highRiskRed),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

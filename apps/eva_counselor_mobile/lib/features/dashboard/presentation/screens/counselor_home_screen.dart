import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../providers/counselor_nav_provider.dart';

class CounselorHomeScreen extends ConsumerStatefulWidget {
  const CounselorHomeScreen({super.key});

  @override
  ConsumerState<CounselorHomeScreen> createState() => _CounselorHomeScreenState();
}

class _CounselorHomeScreenState extends ConsumerState<CounselorHomeScreen> {
  int _selectedCalendarIndex = 0;
  late List<Map<String, dynamic>> _calendarDays;
  late String _monthYearLabel;

  @override
  void initState() {
    super.initState();
    _initDynamicCalendar();
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
        'hasSession': isToday,
        'isHighRisk': false,
        'isOffDay': isWeekend,
        'sessions': sessions,
      };
    });

    _selectedCalendarIndex = now.weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final patientsAsync = ref.watch(patientsListProvider);
    final patients = patientsAsync.value ?? [];

    final selectedDayData = _calendarDays[_selectedCalendarIndex];
    final isSelectedDayToday =
        _selectedCalendarIndex == (DateTime.now().weekday - 1);

    // Dynamically derive today's sessions from real patient data
    final List<Map<String, dynamic>> realTodaySessions = [];
    for (final p in patients) {
      if (p.upcomingSchedule != null) {
        realTodaySessions.add({
          'time': 'Jadwal Aktif (${p.upcomingSchedule!.timeRange})',
          'patientName': '${p.name} (${p.age} Thn)',
          'chiefComplaint': p.chiefComplaint,
          'status': 'Sesi Siap Dimulai (Live)',
          'isLive': true,
          'patientId': p.id,
          'sessionId': p.upcomingSchedule!.sessionId,
        });
      } else if (p.totalCompletedSessions > 0) {
        realTodaySessions.add({
          'time': 'Sesi Selesai Sebelumnya',
          'patientName': '${p.name} (${p.age} Thn)',
          'chiefComplaint': p.chiefComplaint,
          'status': 'Selesai',
          'isCompleted': true,
          'patientId': p.id,
          'sessionId': 'session-prev-${p.id}',
        });
      }
    }

    final selectedSessions = isSelectedDayToday && realTodaySessions.isNotEmpty
        ? realTodaySessions
        : (selectedDayData['sessions'] as List<dynamic>? ?? []);
    final isSelectedDayOff = selectedDayData['isOffDay'] == true;

    // Upcoming consultation patient (real active patient with upcoming session)
    final upcomingPatient = patients.where((p) => p.upcomingSchedule != null).isNotEmpty
        ? patients.firstWhere((p) => p.upcomingSchedule != null)
        : null;
    final highRiskPatients = patients.where((p) => p.isHighRisk).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
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
                          border: Border.all(color: const Color(0xFFECEFF8)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
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
                            border: Border.all(color: const Color(0xFFECEFF8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
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
                            child: const Text(
                              '2',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
                  border: Border.all(color: const Color(0xFFECEFF8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: user?.profilePhotoUrl != null
                              ? NetworkImage(user!.profilePhotoUrl!)
                              : null,
                          child: user?.profilePhotoUrl == null
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
                              StatusBadge.coins(user?.coinBalance ?? 1250),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // STATUS INFO PILL (Online / Menerima Konsultasi - Interactive Toggle)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final currentlyOnline = user?.isOnline ?? true;
                  ref.read(authStateProvider.notifier).updateAvailability(!currentlyOnline);
                  TopToast.show(
                    context,
                    title: !currentlyOnline ? 'Status: Online 🟢' : 'Status: Istirahat ⏸️',
                    message: !currentlyOnline
                        ? 'Anda siap menerima jadwal telekonsultasi 30 menit.'
                        : 'Jadwal Anda dijeda, pasien baru tidak dapat booking sesi.',
                    type: !currentlyOnline ? ToastType.success : ToastType.info,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (user?.isOnline ?? true)
                          ? const Color(0xFFECEFF8)
                          : AppColors.pendingAmber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: (user?.isOnline ?? true)
                                  ? AppColors.verifiedGreen
                                  : AppColors.pendingAmber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (user?.isOnline ?? true)
                                ? 'Online (Menerima Konsultasi)'
                                : 'Istirahat (Sesi Dijeda)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: (user?.isOnline ?? true)
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (user?.isOnline ?? true) ? 'Aktif' : 'Istirahat',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. UPCOMING TELECONSULTATION HERO CARD (Dynamic or Clean Empty State)
              if (upcomingPatient == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak Ada Sesi Telekonsultasi Aktif',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadwal konsultasi baru dari pasien yang terdaftar akan otomatis tampil di sini saat mendekati waktu sesi.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
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
                                final sessionId = upcomingPatient.upcomingSchedule?.sessionId ?? 'session-live-001';
                                final finished = await Navigator.of(context).pushNamed(
                                  '/counselor-video-call',
                                  arguments: sessionId,
                                );
                                if (finished == true && context.mounted) {
                                  Navigator.of(context).pushNamed(
                                    '/counselor-patient-detail',
                                    arguments: upcomingPatient.id,
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

              // 5. HORIZONTAL SCHEDULE MINI-CALENDAR STRIP (LENGKAP 7 HARI, MERAH JIKA LIBUR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jadwal Praktik Mingguan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    _monthYearLabel,
                    style: AppTypography.bodySmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
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
                          'Sesi ${selectedDayData['day']}, ${selectedDayData['date']} Nov',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          isSelectedDayOff ? 'Libur Praktik' : '${selectedSessions.length} Agenda',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelectedDayOff ? FontWeight.bold : FontWeight.normal,
                            color: isSelectedDayOff ? AppColors.highRiskRed : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (isSelectedDayOff) ...[
                      // TAMPILAN JADWAL LIBUR (OFFLINE)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.highRiskBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.highRiskRed.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_busy_rounded, color: AppColors.highRiskRed, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hari Libur Praktik (Offline)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.highRiskRed),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
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
                                    const SizedBox(height: 2),
                                    Text(
                                      session['status'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isLive
                                            ? AppColors.primary
                                            : (isRisk ? AppColors.highRiskRed : AppColors.textSecondary),
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
                                      Navigator.of(context).pushNamed(
                                        '/counselor-video-call',
                                        arguments: 'session-live-001',
                                      );
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
                                child: const Text('+2', style: TextStyle(color: AppColors.verifiedGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text('14', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                          const Text('38', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                            const Text(
                              'Rp 4.250.000',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

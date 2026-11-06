import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../providers/counselor_nav_provider.dart';

class CounselorHomeScreen extends ConsumerStatefulWidget {
  const CounselorHomeScreen({super.key});

  @override
  ConsumerState<CounselorHomeScreen> createState() => _CounselorHomeScreenState();
}

class _CounselorHomeScreenState extends ConsumerState<CounselorHomeScreen> {
  int _selectedCalendarIndex = 1; // 1 = Sel 11 (Hari Ini)
  int _currentBookingIndex = 0;
  late final PageController _bookingPageController = PageController();

  @override
  void dispose() {
    _bookingPageController.dispose();
    super.dispose();
  }

  // MULTIPLE PENDING BOOKINGS
  final List<Map<String, dynamic>> _pendingBookings = [
    {
      'id': 'book-1',
      'patientName': 'Maya Saraswati (22 th)',
      'chiefComplaint': 'Burnout Skripsi & Beban Ekspektasi',
      'requestedSchedule': 'Besok Rabu, 12 Nov • 14:00 - 14:50 WIB',
      'expiresIn': '01:45:00',
    },
    {
      'id': 'book-2',
      'patientName': 'Dimas Setiawan (27 th)',
      'chiefComplaint': 'Kecemasan Karier & Problem Hubungan',
      'requestedSchedule': 'Kamis, 13 Nov • 10:00 - 10:50 WIB',
      'expiresIn': '00:52:30',
    },
    {
      'id': 'book-3',
      'patientName': 'Gita Savira (24 th)',
      'chiefComplaint': 'Insomnia Akut & Serangan Panik',
      'requestedSchedule': 'Jumat, 14 Nov • 16:00 - 16:50 WIB',
      'expiresIn': '01:15:10',
    },
  ];

  // FULL 7-DAY WEEK (Senin s/d Minggu)
  final List<Map<String, dynamic>> _calendarDays = [
    {
      'day': 'Sen',
      'date': '10',
      'hasSession': true,
      'isHighRisk': false,
      'isOffDay': false,
      'sessions': [
        {
          'time': '10:00 - 10:50 WIB',
          'patientName': 'Aditya Nugraha',
          'chiefComplaint': 'Regulasi emosi & relasi sosial',
          'status': 'Selesai',
          'isCompleted': true,
          'patientId': 'patient-003',
        },
      ],
    },
    {
      'day': 'Sel',
      'date': '11',
      'isToday': true,
      'hasSession': true,
      'isHighRisk': true,
      'isOffDay': false,
      'sessions': [
        {
          'time': '10:00 - 10:50 WIB',
          'patientName': 'Rian Pratama (24 Thn)',
          'chiefComplaint': 'Kecemasan akademik & insomnia',
          'status': 'Mulai 15 Mnt Lagi',
          'isLive': true,
          'patientId': 'patient-001',
          'sessionId': 'session-live-001',
        },
        {
          'time': '14:00 - 14:50 WIB',
          'patientName': 'Dinda Kirana (23 Thn)',
          'chiefComplaint': 'Burnout & serangan panik akut',
          'status': 'Perhatian Krisis 🚨',
          'isHighRisk': true,
          'patientId': 'patient-002',
        },
      ],
    },
    {
      'day': 'Rab',
      'date': '12',
      'hasSession': true,
      'isHighRisk': false,
      'isOffDay': false,
      'sessions': [
        {
          'time': '11:00 - 11:50 WIB',
          'patientName': 'Maya Lestari (21 Thn)',
          'chiefComplaint': 'Quarter-life crisis & eksplorasi karier',
          'status': 'Terkonfirmasi',
          'patientId': 'patient-004',
        },
      ],
    },
    {
      'day': 'Kam',
      'date': '13',
      'hasSession': false,
      'isHighRisk': false,
      'isOffDay': false,
      'sessions': [],
    },
    {
      'day': 'Jum',
      'date': '14',
      'hasSession': true,
      'isHighRisk': false,
      'isOffDay': false,
      'sessions': [
        {
          'time': '13:30 - 14:20 WIB',
          'patientName': 'Budi Santoso',
          'chiefComplaint': 'Konseling evaluasi lanjutan',
          'status': 'Terkonfirmasi',
          'patientId': 'patient-001',
        },
      ],
    },
    {
      'day': 'Sab',
      'date': '15',
      'hasSession': false,
      'isHighRisk': false,
      'isOffDay': true, // LIBUR
      'sessions': [],
    },
    {
      'day': 'Min',
      'date': '16',
      'hasSession': false,
      'isHighRisk': false,
      'isOffDay': true, // LIBUR
      'sessions': [],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final patientsAsync = ref.watch(patientsListProvider);

    final selectedDayData = _calendarDays[_selectedCalendarIndex];
    final selectedSessions = (selectedDayData['sessions'] as List<dynamic>?) ?? [];
    final isSelectedDayOff = selectedDayData['isOffDay'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR: Logo Resmi Luna & Notifikasi Halaman
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
                          'assets/images/luna_logo_square.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
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
                          Row(
                            children: const [
                              Text(
                                'LUNA',
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
                            user?.displayName ?? 'dr. Sarah Jenkins, M.Psi',
                            style: AppTypography.headingSmall.copyWith(fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: const [
                              Icon(Icons.verified_rounded, size: 13, color: AppColors.verifiedGreen),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'STR Aktif #4192-PSI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.verifiedGreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // STATUS INFO PILL (Online / Menerima Konsultasi)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.verifiedGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online (Menerima Konsultasi)',
                          style: TextStyle(
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
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. UPCOMING TELECONSULTATION HERO CARD (No Overflows, Soft Gradient)
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
                              children: const [
                                Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Mulai dalam 15 Mnt • 10:00 WIB',
                                    style: TextStyle(
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Telekonsul',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Patient Photo + Clinical & Emotional Record
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
                              const Text(
                                'Rian Pratama (24 Thn)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Generalized Anxiety & Insomnia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text('😟', style: TextStyle(fontSize: 11)),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Cemas • DASS-21: 18',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
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
                                arguments: 'patient-001',
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
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/counselor-video-call',
                                arguments: 'session-live-001',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. PERMINTAAN KONSULTASI BARU (DISTINCT ACTION CARD DENGAN WARM AMBER STYLING & FOCUSED PAGER)
              if (_pendingBookings.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Permintaan Booking (${_pendingBookings.length} Menunggu)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    if (_pendingBookings.length > 1)
                      Text(
                        '${_currentBookingIndex + 1} dari ${_pendingBookings.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 222,
                  child: PageView.builder(
                    controller: _bookingPageController,
                    itemCount: _pendingBookings.length,
                    onPageChanged: (i) => setState(() => _currentBookingIndex = i),
                    itemBuilder: (context, idx) {
                      final b = _pendingBookings[idx];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF3),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFFFDFB0), width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Header: Tag Konsultasi Baru & Expiry Pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.mark_email_unread_rounded, size: 14, color: Color(0xFFD97706)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'PERMINTAAN KONSULTASI BARU',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 11, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sisa ${b['expiresIn'] ?? "01:30:00"}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Patient Profile & Problem
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFFFEDD5),
                                  child: Text(
                                    (b['patientName'] as String).substring(0, 1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC2410C)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b['patientName'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        b['chiefComplaint'] as String,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Proposed Schedule Capsule (Clear contrast box)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF1E5D5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  const Text('Jadwal: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Expanded(
                                    child: Text(
                                      b['requestedSchedule'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Action Buttons (Terima vs Jadwal Lain)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: Color(0xFFD6D9E4)),
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      final name = b['patientName'];
                                      setState(() {
                                        _pendingBookings.removeAt(idx);
                                        if (_currentBookingIndex >= _pendingBookings.length && _currentBookingIndex > 0) {
                                          _currentBookingIndex = _pendingBookings.length - 1;
                                        }
                                      });
                                      TopToast.show(
                                        context,
                                        title: 'Opsi Reschedule Dikirim',
                                        message: 'Tawaran opsi jadwal alternatif telah dikirimkan ke $name.',
                                        type: ToastType.info,
                                      );
                                    },
                                    child: const Text('Jadwal Lain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Terima Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      final name = b['patientName'];
                                      setState(() {
                                        _pendingBookings.removeAt(idx);
                                        if (_currentBookingIndex >= _pendingBookings.length && _currentBookingIndex > 0) {
                                          _currentBookingIndex = _pendingBookings.length - 1;
                                        }
                                      });
                                      TopToast.show(
                                        context,
                                        title: 'Booking Diterima',
                                        message: 'Jadwal telekonsultasi dengan $name telah disetujui & slot terkunci.',
                                        type: ToastType.success,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_pendingBookings.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pendingBookings.length, (dotIdx) {
                      final isActive = dotIdx == _currentBookingIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 16 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFD97706) : const Color(0xFFE2E4EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 18),
              ],

              // 5. HORIZONTAL SCHEDULE MINI-CALENDAR STRIP (LENGKAP 7 HARI, MERAH JIKA LIBUR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jadwal Praktik Mingguan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    'November 2026',
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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                        child: Row(
                          children: const [
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
                      }).toList(),
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
                        Navigator.of(context).pushNamed('/counselor-patient-detail', arguments: 'patient-002');
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
                                  child: const Text('Perhatian', style: TextStyle(color: AppColors.highRiskRed, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('1 Pasien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.highRiskRed)),
                            const SizedBox(height: 2),
                            const Text('Peringatan Berisiko', style: TextStyle(fontSize: 11, color: AppColors.highRiskRed)),
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

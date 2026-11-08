import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';
import '../widgets/clinic_location_map_card.dart';
import '../widgets/consultation_result_bottom_sheet.dart';
import 'psychologist_detail_screen.dart';
import 'psychologist_video_call_screen.dart';

/// Full-page screen for managing consultation schedules and entering live video calls.
class ConsultationScheduleScreen extends ConsumerStatefulWidget {
  const ConsultationScheduleScreen({super.key});

  @override
  ConsumerState<ConsultationScheduleScreen> createState() =>
      _ConsultationScheduleScreenState();
}

class _ConsultationScheduleScreenState
    extends ConsumerState<ConsultationScheduleScreen> {
  String _selectedTab = 'upcoming'; // 'upcoming', 'completed', 'all'

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dt) {
    final dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = dayNames[dt.weekday - 1];
    final monthName = monthNames[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  bool _isSessionTimeNow(ConsultationSessionEntity session) {
    if (session.type != ConsultationType.onlineVideo) return false;

    final now = DateTime.now();
    // Buka akses masuk mulai 10 menit sebelum jadwal sesi
    final startTime = session.sessionDateTime.subtract(const Duration(minutes: 10));
    // Sesi berakhir setelah durasi + 15 menit grace period
    final endTime = session.sessionDateTime.add(Duration(minutes: session.durationMinutes + 15));

    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  void _showNotYetSessionTimeDialog(ConsultationSessionEntity session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum Waktunya Sesi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ruang video call bersama ${session.psychologist.name} belum dapat dimasuki.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jadwal: ${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pintu sesi video call akan otomatis dibuka 10 menit sebelum jam sesi dimulai. Silakan kembali saat jam konsultasi telah tiba.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Mengerti',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionResult(ConsultationSessionEntity session) {
    ConsultationResultBottomSheet.show(context, session);
  }

  void _launchVideoCall(ConsultationSessionEntity session) {
    if (!_isSessionTimeNow(session)) {
      _showNotYetSessionTimeDialog(session);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PsychologistVideoCallScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(consultationSessionsProvider);
    final allSessions = sessionsAsync.value ?? [];

    final upcomingSessions = allSessions
        .where((s) => s.status == ConsultationStatus.upcoming)
        .toList();
    final completedSessions = allSessions
        .where((s) => s.status == ConsultationStatus.completed)
        .toList();

    List<ConsultationSessionEntity> displayedSessions;
    if (_selectedTab == 'upcoming') {
      displayedSessions = upcomingSessions;
    } else if (_selectedTab == 'completed') {
      displayedSessions = completedSessions;
    } else {
      displayedSessions = allSessions;
    }

    // Identify ready or imminent session
    final readySession = upcomingSessions.isNotEmpty ? upcomingSessions.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal Sesi Mendatang',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Kelola janji konsultasi aktif & riwayat jadwalmu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Highlight Banner: Ready to Join Video Call Banner
                    if (readySession != null) ...[
                      _buildReadyVideoCallBanner(readySession),
                      const SizedBox(height: 20),
                    ],

                    // Filter Tabs (Sesi Aktif, Selesai, Semua)
                    _buildFilterTabs(
                      upcomingCount: upcomingSessions.length,
                      completedCount: completedSessions.length,
                      totalCount: allSessions.length,
                    ),

                    const SizedBox(height: 16),

                    // Session List
                    if (displayedSessions.isEmpty)
                      _buildEmptyState()
                    else
                      ...displayedSessions.map((session) {
                        return _buildSessionCard(session);
                      }),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Special Highlight Banner for Live / Imminent Video Call or Offline Session
  Widget _buildReadyVideoCallBanner(ConsultationSessionEntity session) {
    final isOnline = session.type == ConsultationType.onlineVideo;
    final isTimeNow = isOnline && _isSessionTimeNow(session);

    Color bgGradientStart;
    Color bgGradientEnd;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (!isOnline) {
      bgGradientStart = const Color(0xFF0F766E);
      bgGradientEnd = const Color(0xFF14B8A6);
      badgeColor = const Color(0xFF0D9488);
      badgeText = 'Sesi Tatap Muka di Klinik (Offline)';
      badgeIcon = Icons.storefront_rounded;
    } else if (isTimeNow) {
      bgGradientStart = AppColors.primary;
      bgGradientEnd = const Color(0xFF6B71E8);
      badgeColor = AppColors.success;
      badgeText = 'Waktunya Sesi Konsultasi!';
      badgeIcon = Icons.videocam_rounded;
    } else {
      bgGradientStart = const Color(0xFF334155);
      bgGradientEnd = const Color(0xFF475569);
      badgeColor = const Color(0xFFF59E0B);
      badgeText = 'Jadwal Sesi Mendatang';
      badgeIcon = Icons.lock_clock_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgGradientStart, bgGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: bgGradientStart.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      badgeText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Sesi #${session.sessionNumber}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Psychologist Info
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(session.psychologist.avatarUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isTimeNow || !isOnline
                            ? AppColors.success
                            : const Color(0xFFF59E0B),
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
                      session.psychologist.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.psychologist.typeLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !isOnline
                        ? '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB (${session.locationName ?? 'Klinik Mitra'})'
                        : isTimeNow
                            ? '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB (Sedang Berlangsung)'
                            : '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB (Dibuka 10 mnt sebelum sesi)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Button based on Type and Time validity
          if (!isOnline)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  ClinicLocationMapCard.launchRandomGoogleMaps(
                    context: context,
                    query: session.locationName ??
                        session.psychologist.clinicAffiliation,
                  );
                },
                icon: const Icon(Icons.map_rounded, size: 18),
                label: Text(
                  'Buka di Google Maps',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else if (isTimeNow)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _launchVideoCall(session),
                icon: const Icon(Icons.video_call_rounded, size: 20),
                label: Text(
                  'Masuk Video Call Sekarang',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ),
                onPressed: () => _showNotYetSessionTimeDialog(session),
                icon: const Icon(Icons.lock_clock_rounded, size: 19),
                label: Text(
                  'Belum Waktunya Masuk Video Call',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs({
    required int upcomingCount,
    required int completedCount,
    required int totalCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Sesi Aktif ($upcomingCount)',
              keyTab: 'upcoming',
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Selesai ($completedCount)',
              keyTab: 'completed',
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Semua ($totalCount)',
              keyTab: 'all',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required String keyTab,
  }) {
    final isActive = _selectedTab == keyTab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = keyTab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(ConsultationSessionEntity session) {
    final isUpcoming = session.status == ConsultationStatus.upcoming;
    final isCompleted = session.status == ConsultationStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUpcoming ? AppColors.primaryContainer : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(session.psychologist.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.psychologist.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.psychologist.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? (session.type == ConsultationType.offlineClinic
                          ? const Color(0xFFCCFBF1)
                          : AppColors.successContainer)
                      : isCompleted
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUpcoming
                      ? (session.type == ConsultationType.offlineClinic
                          ? 'Tatap Muka'
                          : 'Online Video')
                      : isCompleted
                          ? 'Selesai'
                          : 'Dibatalkan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? (session.type == ConsultationType.offlineClinic
                            ? const Color(0xFF0F766E)
                            : AppColors.successDark)
                        : isCompleted
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Date & Time
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(session.sessionDateTime),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ${_formatTime(session.sessionDateTime)} WIB',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Complaints / Notes
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Keluhan: "${session.notes}"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Offline Clinic Map Preview Card
          if (session.type == ConsultationType.offlineClinic) ...[
            const SizedBox(height: 10),
            ClinicLocationMapCard(
              clinicName: session.locationName ??
                  session.psychologist.clinicAffiliation ??
                  'Klinik Psikologi Sahabat Jiwa',
              address: 'Jl. Kemanggisan Raya No. 45, Palmerah, Jakarta Barat',
            ),
          ],

          const SizedBox(height: 12),

          // Actions Row
          Row(
            children: [
              // Detail button
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PsychologistDetailScreen(
                          psychologist: session.psychologist,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Detail Konselor',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Action Button based on Type, Time & Status
              if (isUpcoming) ...[
                if (session.type == ConsultationType.offlineClinic)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        ClinicLocationMapCard.launchRandomGoogleMaps(
                          context: context,
                          query: session.locationName ??
                              session.psychologist.clinicAffiliation,
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: Text(
                        'Buka di Maps',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else if (_isSessionTimeNow(session))
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _launchVideoCall(session),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: Text(
                        'Masuk Video Call',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      onPressed: () => _showNotYetSessionTimeDialog(session),
                      icon: const Icon(Icons.lock_outline_rounded, size: 15),
                      label: Text(
                        'Belum Waktunya',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ] else if (isCompleted) ...[
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showSessionResult(session),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: Text(
                      'Lihat Saran Sesi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tidak Ada Jadwal Sesi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kamu belum memiliki jadwal sesi pada kategori ini. Silakan cari psikolog untuk menjadwalkan konsultasi baru.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cari Psikolog Sekarang',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

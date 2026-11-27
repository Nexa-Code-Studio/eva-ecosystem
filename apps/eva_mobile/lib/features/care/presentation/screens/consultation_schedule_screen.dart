import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_config.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/safe_network_avatar.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(consultationSessionsProvider.notifier).loadSessions();
      }
    });
  }

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
    final startTime = session.sessionDateTime.subtract(const Duration(minutes: 10));
    final endTime = session.sessionDateTime.add(Duration(minutes: session.durationMinutes + 15));

    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  void _showNotYetSessionTimeDialog(ConsultationSessionEntity session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Belum Waktunya Sesi',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSoft),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          if (AppConfig.useMockData)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PsychologistVideoCallScreen(session: session),
                  ),
                );
              },
              child: Text(
                'Masuk Sekarang (Simulasi/Test)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(96, 44),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Mengerti',
              style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Kelola janji konsultasi aktif dan riwayat jadwalmu',
                          style: GoogleFonts.inter(
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
              child: sessionsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(consultationSessionsProvider.notifier).loadSessions(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: _buildErrorState(err.toString()),
                  ),
                ),
                data: (allSessions) {
                  final upcomingSessions = (allSessions
                      .where((s) => s.status == ConsultationStatus.upcoming)
                      .toList())
                    ..sort((a, b) => a.sessionDateTime.compareTo(b.sessionDateTime));
                  final completedSessions = (allSessions
                      .where((s) => s.status == ConsultationStatus.completed)
                      .toList())
                    ..sort((a, b) => b.sessionDateTime.compareTo(a.sessionDateTime));

                  List<ConsultationSessionEntity> displayedSessions;
                  if (_selectedTab == 'upcoming') {
                    displayedSessions = upcomingSessions;
                  } else if (_selectedTab == 'completed') {
                    displayedSessions = completedSessions;
                  } else {
                    displayedSessions = allSessions;
                  }

                  final readySession =
                      upcomingSessions.isNotEmpty ? upcomingSessions.first : null;

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.read(consultationSessionsProvider.notifier).loadSessions(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (readySession != null) ...[
                            _buildReadyVideoCallBanner(readySession),
                            const SizedBox(height: 20),
                          ],
                          _buildFilterTabs(
                            upcomingCount: upcomingSessions.length,
                            completedCount: completedSessions.length,
                            totalCount: allSessions.length,
                          ),
                          const SizedBox(height: 16),
                          if (displayedSessions.isEmpty)
                            _buildEmptyState()
                          else
                            ...displayedSessions.map(_buildSessionCard),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.errorContainer),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Gagal Memuat Jadwal Sesi',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(140, 44),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () =>
                ref.read(consultationSessionsProvider.notifier).loadSessions(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Coba Lagi',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Highlight Banner aligned with Eva's Periwinkle/Lavender DESIGN.md identity
  Widget _buildReadyVideoCallBanner(ConsultationSessionEntity session) {
    final isTimeNow = _isSessionTimeNow(session);

    final Color titleColor = isTimeNow ? Colors.white : AppColors.textPrimary;
    final Color subtitleColor =
        isTimeNow ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary;
    final Color metaPillBg = isTimeNow
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.surface.withValues(alpha: 0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTimeNow
              ? const [AppColors.primary, AppColors.primaryLight]
              : const [AppColors.primaryContainer, Color(0xFFF3F0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isTimeNow
              ? Colors.white.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isTimeNow ? AppColors.success : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: isTimeNow
                      ? null
                      : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTimeNow ? Icons.videocam_rounded : Icons.schedule_rounded,
                      size: 14,
                      color: isTimeNow ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isTimeNow ? 'Waktunya Sesi Konsultasi!' : 'Jadwal Sesi Mendatang',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isTimeNow ? Colors.white : AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Sesi #${session.sessionNumber}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
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
                  SafeNetworkAvatar(
                    imageUrl: session.psychologist.avatarUrl,
                    radius: 26,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isTimeNow ? AppColors.success : AppColors.primary,
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
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.psychologist.typeLabel} • ${session.durationMinutes} Menit',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isTimeNow
                            ? AppColors.secondary
                            : AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: metaPillBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 15,
                  color: isTimeNow ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTimeNow
                        ? '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB (Sedang Berlangsung)'
                        : '${_formatDate(session.sessionDateTime)} • ${_formatTime(session.sessionDateTime)} WIB (Dibuka 10 mnt sebelum sesi)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (isTimeNow)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _launchVideoCall(session),
                icon: const Icon(Icons.video_call_rounded, size: 20),
                label: Text(
                  'Masuk Video Call Sekarang',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.onPrimaryContainer,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _showNotYetSessionTimeDialog(session),
                icon: const Icon(Icons.lock_clock_rounded, size: 19),
                label: Text(
                  'Belum Waktunya Masuk Video Call',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedTab = keyTab),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: AppColors.glassShadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(ConsultationSessionEntity session) {
    final isUpcoming = session.status == ConsultationStatus.upcoming;
    final isCompleted = session.status == ConsultationStatus.completed;
    final isMissed = session.status == ConsultationStatus.missed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUpcoming
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.borderSoft,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SafeNetworkAvatar(
                imageUrl: session.psychologist.avatarUrl,
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.psychologist.name,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.psychologist.title,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUpcoming
                      ? AppColors.successContainer
                      : isCompleted
                          ? AppColors.primaryContainer
                          : isMissed
                              ? AppColors.warningContainer
                              : AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isUpcoming
                      ? 'Online Video'
                      : isCompleted
                          ? 'Selesai'
                          : isMissed
                              ? 'Terlewat'
                              : 'Dibatalkan',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUpcoming
                        ? AppColors.successDark
                        : isCompleted
                            ? AppColors.onPrimaryContainer
                            : isMissed
                                ? AppColors.warningDark
                                : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),

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
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ${_formatTime(session.sessionDateTime)} WIB',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Keluhan: "${session.notes}"',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              if (isUpcoming) ...[
                if (_isSessionTimeNow(session))
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _launchVideoCall(session),
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: Text(
                          'Masuk Video Call',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceLow,
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.borderSoft),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _showNotYetSessionTimeDialog(session),
                        icon: const Icon(Icons.lock_outline_rounded, size: 15),
                        label: Text(
                          'Belum Waktunya',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ] else if (isCompleted) ...[
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _showSessionResult(session),
                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                      label: Text(
                        'Lihat Saran Sesi',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tidak Ada Jadwal Sesi',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kamu belum memiliki jadwal sesi pada kategori ini. Silakan cari psikolog untuk menjadwalkan konsultasi baru.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cari Psikolog Sekarang',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

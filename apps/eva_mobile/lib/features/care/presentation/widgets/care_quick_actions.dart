import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';
import 'booking_consultation_sheet.dart';

/// 4 Quick Action Buttons for Care / Layanan Screen:
/// 1. Jadwal Sesi (Sesi yang telah dibooking)
/// 2. Riwayat Bicara (History pernah bicara dengan siapa saja)
/// 3. Koin Saya (Saldo koin & top up cepat)
/// 4. Panduan & FAQ (Panduan konseling, perbedaan psikolog & etika)
class CareQuickActions extends ConsumerWidget {
  const CareQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coinBalance = ref.watch(coinBalanceProvider);
    final sessionsAsync = ref.watch(consultationSessionsProvider);

    final upcomingCount = sessionsAsync.value
            ?.where((s) => s.status == ConsultationStatus.upcoming)
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Jadwal',
                  subtitle: upcomingCount > 0 ? '$upcomingCount Sesi Aktif' : 'Cek Jadwal',
                  badge: upcomingCount > 0 ? '$upcomingCount' : null,
                  icon: Icons.calendar_today_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primaryContainer,
                  onTap: () => Navigator.pushNamed(context, '/care/schedule'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Riwayat',
                  subtitle: 'History Sesi',
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF6366F1),
                  iconBgColor: const Color(0xFFEEF2FF),
                  onTap: () => Navigator.pushNamed(context, '/care/history'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Koin Saya',
                  subtitle: '$coinBalance Koin',
                  icon: Icons.monetization_on_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEF3C7),
                  onTap: () {
                    Navigator.pushNamed(context, '/coin_purchase');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  context: context,
                  title: 'Panduan',
                  subtitle: 'Etika & FAQ',
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: const Color(0xFFCCFBF1),
                  onTap: () => _showCareGuideModal(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpcomingSessionsModal(BuildContext context, WidgetRef ref) {
    final sessions = ref.read(consultationSessionsProvider).value ?? [];
    final upcomingSessions =
        sessions.where((s) => s.status == ConsultationStatus.upcoming).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Jadwal Sesi Mendatang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Daftar janji konsultasi yang telah berhasil kamu booking.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (upcomingSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'Belum Ada Jadwal Aktif',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih psikolog atau volunteer di bawah untuk membuat janji baru.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...upcomingSessions.map((session) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryContainer),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    session.psychologist.typeLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Terkonfirmasi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '${session.sessionDateTime.day}/${session.sessionDateTime.month}/${session.sessionDateTime.year} • ${_formatTime(session.sessionDateTime)} WIB',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (session.notes != null && session.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Keluhan: "${session.notes}"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showConsultationHistoryModal(BuildContext context, WidgetRef ref) {
    final sessions = ref.read(consultationSessionsProvider).value ?? [];
    final completedSessions =
        sessions.where((s) => s.status == ConsultationStatus.completed).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Bicara & Konseling',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Daftar psikolog dan volunteer yang pernah kamu ajak bicara.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (completedSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'Belum Ada Riwayat Sesi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Setelah sesi selesai, catatan refleksi dan diagnosis akan tersimpan di sini.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...completedSessions.map((session) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
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
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                BookingConsultationSheet.show(context, session.psychologist);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Bicara Lagi',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (session.notes != null && session.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Catatan: ${session.notes}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showCareGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF0D9488), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Panduan Layanan Konseling',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildGuideSection(
                icon: Icons.verified_user_rounded,
                title: 'Psikolog Profesional Independen',
                desc:
                    'Memiliki izin praktik resmi SIPP/STR. Cocok untuk asesmen klinis mendalam, depresi, kecemasan akut, trauma, dan psikoterapi terstruktur.',
              ),
              const SizedBox(height: 10),
              _buildGuideSection(
                icon: Icons.work_outline_rounded,
                title: 'Psikolog Freelance',
                desc:
                    'Praktisi psikolog berlisensi yang fleksibel menangani konseling karir, quarter-life crisis, relasi hubungan, dan self-growth.',
              ),
              const SizedBox(height: 10),
              _buildGuideSection(
                icon: Icons.favorite_border_rounded,
                title: 'Volunteer Konselor Sebaya',
                desc:
                    'Relawan terlatih Psychological First Aid (PFA). Menyediakan ruang dengar hangat dan curhat tanpa biaya untuk teman sebaya.',
              ),
              const SizedBox(height: 10),
              _buildGuideSection(
                icon: Icons.monetization_on_rounded,
                title: 'Transaksi Koin EVA',
                desc:
                    'Seluruh sesi dapat dibayar menggunakan Koin EVA (atau transfer). Sesi volunteer gratis atau donasi koin sukarela.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

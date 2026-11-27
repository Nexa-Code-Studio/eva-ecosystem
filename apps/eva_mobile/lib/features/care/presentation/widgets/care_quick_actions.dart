import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../coin/presentation/providers/coin_provider.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../providers/care_provider.dart';

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
          border: Border.all(color: AppColors.borderSoft),
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
                          style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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
              color: AppColors.borderSubtle,
            ),
          ],
        ),
      ),
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
                    color: AppColors.borderSoft,
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
                    style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
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
}

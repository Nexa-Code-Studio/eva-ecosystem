import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_config.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/glass_card.dart';
import '../../../../widgets/safe_network_avatar.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../providers/care_provider.dart';
import 'booking_consultation_screen.dart';
import '../widgets/psychologist_certificate_carousel.dart';

/// Comprehensive profile detail screen for Psychologists and Volunteers.
class PsychologistDetailScreen extends ConsumerWidget {
  final PsychologistEntity psychologist;

  const PsychologistDetailScreen({
    super.key,
    required this.psychologist,
  });

  String _formatCoinFee(int coins) {
    if (coins <= 0) return 'Gratis';
    return '$coins Koin';
  }

  Color _getTypeColor(PsychologistEntity activePsy) {
    switch (activePsy.practitionerType) {
      case PractitionerType.professional:
        return AppColors.primary;
      case PractitionerType.freelance:
        return const Color(0xFF4F46E5);
      case PractitionerType.volunteer:
        return const Color(0xFF0D9488);
    }
  }

  Color _getTypeBgColor(PsychologistEntity activePsy) {
    switch (activePsy.practitionerType) {
      case PractitionerType.professional:
        return AppColors.primaryContainer;
      case PractitionerType.freelance:
        return const Color(0xFFEEF2FF);
      case PractitionerType.volunteer:
        return const Color(0xFFCCFBF1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(counselorDetailProvider(psychologist.id));
    final reviewsAsync = ref.watch(counselorReviewsProvider(psychologist.id));
    final activePsy = detailAsync.valueOrNull ?? psychologist;

    final typeColor = _getTypeColor(activePsy);
    final typeBgColor = _getTypeBgColor(activePsy);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Navigation Header
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
                          'Profil Konselor',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          activePsy.typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
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
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(counselorDetailProvider(psychologist.id));
                  ref.invalidate(counselorReviewsProvider(psychologist.id));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Profile Card
                      _buildHeroProfileCard(activePsy, typeColor, typeBgColor),

                      if (activePsy.patientStats.hasData) ...[
                        const SizedBox(height: 20),
                        _buildPatientStatsSection(activePsy),
                      ],

                      const SizedBox(height: 20),

                      // About & Therapy Approach
                      _buildAboutSection(activePsy),

                      const SizedBox(height: 20),

                      // Verified Patient Testimonials from Backend API
                      _buildTestimonialsSection(context, ref, activePsy, reviewsAsync),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Sticky Bottom Action Bar
            _buildBottomBar(context, activePsy),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroProfileCard(
    PsychologistEntity activePsy,
    Color typeColor,
    Color typeBgColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SafeNetworkAvatar(
                    imageUrl: activePsy.avatarUrl,
                    radius: 36,
                  ),
                  if (activePsy.availableOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (activePsy.isVolunteer)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.volunteer_activism_rounded,
                                  size: 11,
                                  color: AppColors.tertiaryDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Relawan',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0369A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (activePsy.hasPsychologistCertificate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school_rounded,
                                  size: 11,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Profesional',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3730A3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (activePsy.levelName != null &&
                            activePsy.levelName!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 11,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  activePsy.levelName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activePsy.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activePsy.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            activePsy.registrationNumber,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.surfaceHigh),
          const SizedBox(height: 14),

          // Stats Overview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.star_rounded,
                iconColor: AppColors.warningDark,
                title: activePsy.rating.toStringAsFixed(1),
                subtitle: '${activePsy.reviewCount} Ulasan',
              ),
              Container(width: 1, height: 28, color: AppColors.borderSoft),
              _buildStatItem(
                icon: Icons.work_outline_rounded,
                iconColor: AppColors.primary,
                title: '${activePsy.experienceYears} Thn',
                subtitle: 'Pengalaman',
              ),
              Container(width: 1, height: 28, color: AppColors.borderSoft),
              _buildStatItem(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF0D9488),
                title: '${activePsy.durationMinutes} Mnt',
                subtitle: 'Per Sesi',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientStatsSection(PsychologistEntity activePsy) {
    final stats = activePsy.patientStats;

    return GlassCard.surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik Pasien Dirawat',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Berdasarkan riwayat konsultasi & pemulihan klinis',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Counters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMetricItem(
                  value: '${stats.totalPatientsTreated}+',
                  label: 'Pasien Dirawat',
                  icon: Icons.people_outline_rounded,
                  accentColor: AppColors.primary,
                ),
                Container(width: 1, height: 32, color: AppColors.borderSoft),
                _buildStatMetricItem(
                  value: '${stats.satisfactionRate.toStringAsFixed(1)}%',
                  label: 'Tingkat Puas',
                  icon: Icons.sentiment_very_satisfied_rounded,
                  accentColor: const Color(0xFF16A34A),
                ),
                Container(width: 1, height: 32, color: AppColors.borderSoft),
                _buildStatMetricItem(
                  value: '${stats.avgRecoverySessions.toStringAsFixed(1)} Sesi',
                  label: 'Rata-rata Selesai',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: const Color(0xFF0D9488),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Review Sentiment Ratio Bar (Positif vs Negatif)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.positiveReviewRate.toStringAsFixed(0)}% Ulasan Positif',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${stats.negativeReviewRate.toStringAsFixed(0)}% Catatan / Masukan',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (stats.positiveReviewRate * 10).toInt(),
                        child: Container(color: const Color(0xFF22C55E)),
                      ),
                      Expanded(
                        flex: (stats.negativeReviewRate * 10).toInt(),
                        child: Container(color: const Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Clinical Recovery Description Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats.recoveryDescription,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetricItem({
    required String value,
    required String label,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(PsychologistEntity activePsy) {
    final title = activePsy.hasPsychologistCertificate
        ? 'Tentang Psikolog & Kredensial Keahlian'
        : 'Tentang Relawan & Kredensial Keahlian';
    final certItems = AppConfig.useMockData
        ? activePsy.effectiveCertificateItems
        : activePsy.certificateItems;

    return GlassCard.surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                activePsy.hasPsychologistCertificate
                    ? Icons.psychology_outlined
                    : Icons.volunteer_activism_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activePsy.bio.isNotEmpty
                ? activePsy.bio
                : 'Konselor terverifikasi Eva siap mendampingi sesi telekonseling Anda.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          if (activePsy.clinicAffiliation != null || activePsy.registrationNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    activePsy.clinicAffiliation != null
                        ? Icons.business_rounded
                        : Icons.verified_user_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      activePsy.clinicAffiliation != null
                          ? 'Mitra Praktik: ${activePsy.clinicAffiliation}'
                          : 'Kredensial Terdaftar: ${activePsy.registrationNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceHigh),
          const SizedBox(height: 12),

          if (certItems.isNotEmpty)
            PsychologistCertificateCarousel(certificateItems: certItems)
          else if (activePsy.certifications.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KREDENSIAL & LISENSI',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                ...activePsy.certifications.map(
                  (cert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cert,
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
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Verified Patient Testimonials loaded from Backend API (or mock list in mock mode)
  Widget _buildTestimonialsSection(
    BuildContext context,
    WidgetRef ref,
    PsychologistEntity activePsy,
    AsyncValue<List<PatientReviewItem>> reviewsAsync,
  ) {
    final allTestimonials = reviewsAsync.valueOrNull ??
        (AppConfig.useMockData ? activePsy.effectiveTestimonials : const <PatientReviewItem>[]);
    final displayedFive = allTestimonials.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'TESTIMONI PASIEN',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${allTestimonials.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (allTestimonials.isNotEmpty)
              InkWell(
                onTap: () => _showAllTestimonialsSheet(context, activePsy, allTestimonials),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Semua',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (reviewsAsync.isLoading && allTestimonials.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (reviewsAsync.hasError && allTestimonials.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Gagal memuat ulasan pasien dari server.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(counselorReviewsProvider(activePsy.id)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (allTestimonials.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              'Belum ada ulasan pasien terverifikasi untuk konselor ini.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          )
        else ...[
          Text(
            '${displayedFive.length} ulasan pengalaman konseling pasien terverifikasi:',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...displayedFive.map((item) => _buildTestimonialCard(item)),
        ],
      ],
    );
  }

  Widget _buildTestimonialCard(PatientReviewItem item) {
    final isPos = item.isPositive;
    final sentimentBg = isPos ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final sentimentBorder = isPos ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
    final sentimentText = isPos ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final sentimentIcon = isPos ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Patient Profile, Rating Stars, Time, and Sentiment Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isPos ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                child: Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: sentimentText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.patientName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (starIndex) {
                            final fill = (starIndex + 1) <= item.rating.floor();
                            return Icon(
                              fill ? Icons.star_rounded : Icons.star_half_rounded,
                              size: 12,
                              color: AppColors.warningDark,
                            );
                          }),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  ${item.timeAgo}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Sentiment Icon (Thumbs up/down only, without Positif/Catatan text)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: sentimentBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: sentimentBorder),
                ),
                child: Icon(sentimentIcon, size: 12, color: sentimentText),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Ulasan Singkat (Tag Label)
          if (item.label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: sentimentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline_rounded,
                    size: 12,
                    color: sentimentText,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sentimentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Deskripsi Testimoni
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.format_quote_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Interactive Modal Bottom Sheet allowing patients to see all testimonials with filters
  void _showAllTestimonialsSheet(
    BuildContext context,
    PsychologistEntity activePsy,
    List<PatientReviewItem> allTestimonials,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        String activeFilter = 'semua';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final positiveList = allTestimonials.where((t) => t.isPositive).toList();
            final negativeList = allTestimonials.where((t) => t.isNegative).toList();

            List<PatientReviewItem> displayedList;
            if (activeFilter == 'positif') {
              displayedList = positiveList;
            } else if (activeFilter == 'negatif') {
              displayedList = negativeList;
            } else {
              displayedList = allTestimonials;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Semua Testimoni Pasien',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${allTestimonials.length} Ulasan Terverifikasi • ${activePsy.name}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  // Filter Chips (Semua, Positif, Catatan)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Semua (${allTestimonials.length})',
                          isActive: activeFilter == 'semua',
                          activeColor: AppColors.primary,
                          onTap: () => setModalState(() => activeFilter = 'semua'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Positif (${positiveList.length})',
                          isActive: activeFilter == 'positif',
                          activeColor: const Color(0xFF16A34A),
                          onTap: () => setModalState(() => activeFilter = 'positif'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Catatan (${negativeList.length})',
                          isActive: activeFilter == 'negatif',
                          activeColor: const Color(0xFFDC2626),
                          onTap: () => setModalState(() => activeFilter = 'negatif'),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.borderSoft),

                  // Testimonial List
                  Expanded(
                    child: displayedList.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada ulasan pada kategori ini.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            itemCount: displayedList.length,
                            itemBuilder: (context, index) {
                              return _buildTestimonialCard(displayedList[index]);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : AppColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, PsychologistEntity activePsy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.borderSoft, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Biaya Konsultasi',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (activePsy.coinsPerSession > 0) ...[
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: Color(0xFFFFB300),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatCoinFee(activePsy.coinsPerSession),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: activePsy.coinsPerSession > 0
                            ? AppColors.textPrimary
                            : const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              BookingConsultationScreen.open(context, activePsy);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Jadwalkan Konsultasi',
              style: GoogleFonts.inter(
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

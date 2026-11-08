import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/psychologist_entity.dart';
import 'dense_review_tags_wrap.dart';

class PsychologistCard extends StatelessWidget {
  final PsychologistEntity psychologist;
  final VoidCallback onBookTap;
  final VoidCallback? onTap;

  const PsychologistCard({
    super.key,
    required this.psychologist,
    required this.onBookTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAEBFA)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Online indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: NetworkImage(psychologist.avatarUrl),
                        onBackgroundImageError: (exception, stackTrace) {},
                        child: Text(
                          psychologist.name.substring(0, 2).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (psychologist.availableOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name, Practitioner Badge, Title & Rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (psychologist.isVolunteer)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFBAE6FD)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.volunteer_activism_rounded,
                                      size: 11,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Relawan',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0369A1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (psychologist.hasPsychologistCertificate)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(5),
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
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3730A3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          psychologist.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          psychologist.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              '${psychologist.rating.toStringAsFixed(1)} (${psychologist.reviewCount})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '• ${psychologist.experienceYears} Thn Pengalaman',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Patient Review Tags (Intelligent 2-row bin-packing with positive & negative sentiment)
              if (psychologist.effectiveReviewTags.isNotEmpty) ...[
                DenseReviewTagsWrap(
                  tags: psychologist.effectiveReviewTags,
                  maxRows: 2,
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Pricing & Booking Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biaya Sesi (${psychologist.durationMinutes} mnt)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (psychologist.coinsPerSession > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 14,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              psychologist.coinsPerSession > 0
                                  ? '${psychologist.coinsPerSession} Koin'
                                  : 'Gratis',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: psychologist.coinsPerSession > 0
                                    ? AppColors.textPrimary
                                    : const Color(0xFF0D9488),
                              ),
                            ),
                            if (psychologist.coinsPerSession > 0)
                              Text(
                                ' / sesi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onBookTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Jadwalkan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

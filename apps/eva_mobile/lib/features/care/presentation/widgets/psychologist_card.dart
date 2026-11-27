import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/safe_network_avatar.dart';
import '../../domain/entities/psychologist_entity.dart';
import 'dense_review_tags_wrap.dart';

class PsychologistCard extends StatelessWidget {
  final PsychologistEntity psychologist;
  final VoidCallback onBookTap;
  final VoidCallback? onTap;
  final bool preferTomorrowTag;

  const PsychologistCard({
    super.key,
    required this.psychologist,
    required this.onBookTap,
    this.onTap,
    this.preferTomorrowTag = false,
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
                  // Avatar with Level Badge at bottom-right
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SafeNetworkAvatar(
                        imageUrl: psychologist.avatarUrl,
                        radius: 28,
                      ),
                      if (psychologist.levelTier != null)
                        Positioned(
                          bottom: -2,
                          right: -4,
                          child: _AvatarLevelBadge(
                            tier: psychologist.levelTier!,
                            levelName: psychologist.levelName,
                            badgeIcon: psychologist.levelBadgeIcon,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Availability Tags, Name, Title & Rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AvailabilityTagsRow(
                          psychologist: psychologist,
                          preferTomorrowTag: preferTomorrowTag,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          psychologist.name,
                          style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 15, color: AppColors.warningDark),
                            const SizedBox(width: 3),
                            Text(
                              '${psychologist.rating.toStringAsFixed(1)} (${psychologist.reviewCount})',
                              style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
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

              const Divider(height: 1, color: AppColors.surfaceHigh),
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
                          style: GoogleFonts.inter(
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
                              style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
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
                      style: GoogleFonts.inter(
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

class _AvatarLevelBadge extends StatelessWidget {
  final int tier;
  final String? levelName;
  final String? badgeIcon;

  const _AvatarLevelBadge({
    required this.tier,
    this.levelName,
    this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _tierPalette(tier);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tierIcon(badgeIcon, tier), size: 10, color: palette.accent),
          const SizedBox(width: 2),
          Text(
            'Lv.$tier',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: palette.accent,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (levelName != null && levelName!.trim().isNotEmpty) {
      return Tooltip(message: levelName!, child: badge);
    }
    return badge;
  }

  static IconData _tierIcon(String? badgeIcon, int tier) {
    switch (badgeIcon?.toLowerCase()) {
      case 'crown':
        return Icons.emoji_events_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'shield-check':
        return Icons.verified_user_rounded;
      case 'award':
        return Icons.workspace_premium_rounded;
      default:
        if (tier >= 4) return Icons.emoji_events_rounded;
        if (tier == 3) return Icons.star_rounded;
        if (tier == 2) return Icons.verified_user_rounded;
        return Icons.workspace_premium_rounded;
    }
  }

  static ({Color bg, Color accent}) _tierPalette(int tier) {
    if (tier >= 4) {
      return (bg: AppColors.primaryContainer, accent: AppColors.primary);
    } else if (tier == 3) {
      return (bg: AppColors.warningContainer, accent: AppColors.warningDark);
    } else if (tier == 2) {
      return (bg: AppColors.secondary.withValues(alpha: 0.45), accent: AppColors.onPrimaryContainer);
    }
    return (bg: AppColors.tertiaryContainer, accent: AppColors.tertiaryDark);
  }
}

class _AvailabilityTagsRow extends StatelessWidget {
  final PsychologistEntity psychologist;
  final bool preferTomorrowTag;

  const _AvailabilityTagsRow({
    required this.psychologist,
    this.preferTomorrowTag = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = psychologist.availabilityStatus;

    if (preferTomorrowTag && psychologist.hasSlotsTomorrow) {
      final slot = psychologist.nextSlotTomorrow ?? psychologist.nextAvailableSlot;
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _TagPill(
            bgColor: const Color(0xFFF5F3FF),
            borderColor: const Color(0xFFDDD6FE),
            textColor: const Color(0xFF5B21B6),
            icon: Icons.event_available_rounded,
            label: slot != null ? 'Besok • $slot' : 'Tersedia Besok',
          ),
        ],
      );
    }

    switch (status) {
      case CounselorAvailabilityStatus.availableNow:
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            const _TagPill(
              bgColor: Color(0xFFECFDF5),
              borderColor: Color(0xFFA7F3D0),
              textColor: Color(0xFF047857),
              showPulseDot: true,
              label: 'Tersedia Sekarang',
            ),
            if (psychologist.remainingSlotsToday > 0)
              _TagPill(
                bgColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFF99F6E4),
                textColor: const Color(0xFF0F766E),
                label: '${psychologist.remainingSlotsToday} Slot Hari Ini',
              ),
          ],
        );

      case CounselorAvailabilityStatus.availableToday:
        final slot = psychologist.nextAvailableSlot;
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _TagPill(
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              textColor: const Color(0xFF1D4ED8),
              icon: Icons.schedule_rounded,
              label: slot != null ? 'Hari Ini • $slot' : 'Tersedia Hari Ini',
            ),
            if (psychologist.remainingSlotsToday > 0)
              _TagPill(
                bgColor: AppColors.surfaceLow,
                borderColor: AppColors.borderSoft,
                textColor: AppColors.textSecondary,
                label: '${psychologist.remainingSlotsToday} Slot Tersisa',
              ),
          ],
        );

      case CounselorAvailabilityStatus.availableTomorrow:
        final slot = psychologist.nextAvailableSlot ?? psychologist.nextSlotTomorrow;
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _TagPill(
              bgColor: const Color(0xFFF5F3FF),
              borderColor: const Color(0xFFDDD6FE),
              textColor: const Color(0xFF5B21B6),
              icon: Icons.event_available_rounded,
              label: slot != null ? 'Besok • $slot' : 'Tersedia Besok',
            ),
          ],
        );

      case CounselorAvailabilityStatus.unavailable:
        return const Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _TagPill(
              bgColor: AppColors.surfaceHigh,
              borderColor: AppColors.borderSubtle,
              textColor: AppColors.textSecondary,
              icon: Icons.event_busy_rounded,
              label: 'Jadwal Penuh',
            ),
          ],
        );
    }
  }
}

class _TagPill extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  final bool showPulseDot;
  final String label;

  const _TagPill({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.label,
    this.icon,
    this.showPulseDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulseDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

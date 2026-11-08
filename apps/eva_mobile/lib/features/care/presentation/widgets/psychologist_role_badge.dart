import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../domain/entities/psychologist_entity.dart';

/// Reusable credential & role badge representing Volunteer and/or Certified Psychologist.
/// Aligned with the portal & mobile shield medallion design system.
class PsychologistRoleBadge extends StatelessWidget {
  final PsychologistEntity psychologist;
  final bool showExplanationOnTap;

  const PsychologistRoleBadge({
    super.key,
    required this.psychologist,
    this.showExplanationOnTap = true,
  });

  void _showQualificationModal(BuildContext context) {
    if (!showExplanationOnTap) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                _buildMedallionIcons(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        psychologist.badgeHeaderTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildBadgeChips(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Layer Explanations
            Text(
              'Tingkat Kualifikasi & Kredensial',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            if (psychologist.isVolunteer) ...[
              _buildLayerItem(
                number: '1',
                title: 'Relawan',
                description: psychologist.hasPsychologistCertificate
                    ? 'Aktif memberikan sesi curhat & pendampingan sebaya bebas biaya (Gratis) untuk masyarakat.'
                    : 'Relawan terlatih di bidang Psychological First Aid (PFA) & konseling sebaya. Bebas biaya / Gratis.',
                bgColor: const Color(0xFF0EA5E9),
              ),
              const SizedBox(height: 10),
            ],

            if (psychologist.hasPsychologistCertificate) ...[
              _buildLayerItem(
                number: psychologist.isVolunteer ? '2' : '1',
                title: 'Profesional',
                description:
                    'Lulusan Magister Profesi Psikologi (S2) dengan Surat Izin Praktik Psikologi (SIPP) resmi: ${psychologist.registrationNumber}.',
                bgColor: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerItem({
    required String number,
    required String title,
    required String description,
    required Color bgColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
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

  Widget _buildMedallionIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (psychologist.isVolunteer)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF0EA5E9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x330EA5E9),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
        if (psychologist.hasBothBadges) const SizedBox(width: 5),
        if (psychologist.hasPsychologistCertificate)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x336366F1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
      ],
    );
  }

  Widget _buildBadgeChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (psychologist.isVolunteer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Relawan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        if (psychologist.hasPsychologistCertificate)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'Profesional',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3730A3),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: showExplanationOnTap ? () => _showQualificationModal(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            _buildMedallionIcons(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          psychologist.badgeHeaderTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showExplanationOnTap)
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildBadgeChips(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

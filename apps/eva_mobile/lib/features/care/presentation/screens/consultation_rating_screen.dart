import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../../../../widgets/app_snack_bar.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../providers/care_provider.dart';

/// Dedicated screen allowing patients to rate and review their consultation experience.
/// Follows the repository standard format: Star, Ulasan Singkat, & Deskripsi.
class ConsultationRatingScreen extends ConsumerStatefulWidget {
  final PsychologistEntity psychologist;
  final PsychologistRatingReview? initialRating;

  const ConsultationRatingScreen({
    super.key,
    required this.psychologist,
    this.initialRating,
  });

  @override
  ConsumerState<ConsultationRatingScreen> createState() =>
      _ConsultationRatingScreenState();
}

class _ConsultationRatingScreenState
    extends ConsumerState<ConsultationRatingScreen> {
  late double _rating;
  late TextEditingController _labelController;
  late TextEditingController _descriptionController;
  late bool _isAnonymous;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating?.rating ?? 5.0;
    _labelController = TextEditingController(
      text: widget.initialRating?.label ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialRating?.description ?? '',
    );
    _isAnonymous = widget.initialRating?.isAnonymous ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getRatingFeedbackLabel(double rating) {
    if (rating >= 5.0) return 'Luar Biasa Memuaskan & Bermanfaat! 🌟';
    if (rating >= 4.0) return 'Sangat Baik & Sangat Membantu 👍';
    if (rating >= 3.0) return 'Cukup Baik & Bermanfaat 🙂';
    if (rating >= 2.0) return 'Kurang Sesuai Harapan 😕';
    return 'Pengalaman Belum Memuaskan 🙁';
  }

  Future<void> _handleSubmit() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.create(
          message: 'Harap isi ulasan singkat sesi.',
          variant: SnackBarVariant.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    ref.read(psychologistRatingsProvider.notifier).submitRating(
      psychologistId: widget.psychologist.id,
      rating: _rating,
      isPositive: _rating >= 4.0,
      label: label,
      description: _descriptionController.text.trim(),
      tags: [label],
      isAnonymous: _isAnonymous,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      AppSnackBar.create(
        message: widget.initialRating != null
            ? 'Penilaian & ulasan sesi berhasil diperbarui!'
            : 'Terima kasih! Penilaian & ulasan sesi Anda berhasil dikirim.',
        variant: SnackBarVariant.success,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final counselorFirstName = widget.psychologist.name.split(',')[0];

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
                          'Beri Penilaian Sesi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ulasan & evaluasi bersama $counselorFirstName',
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

            // 2. Scrollable Rating Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Psychologist Info Card
                    _buildPsychologistInfoCard(),
                    const SizedBox(height: 18),

                    // Section 1: Star Rating Card
                    _buildStarRatingCard(),
                    const SizedBox(height: 18),

                    // Section 2: Ulasan Singkat Form Input
                    _buildShortReviewCard(),
                    const SizedBox(height: 18),

                    // Section 3: Deskripsi Ulasan
                    _buildDescriptionInputCard(),
                    const SizedBox(height: 16),

                    // Anonymous Toggle Card
                    _buildAnonymousToggleCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 3. Persistent Submit Button Dock
            _buildBottomSubmitDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildPsychologistInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(widget.psychologist.avatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.psychologist.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.psychologist.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sesi Konseling Selesai',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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

  /// Section 1: Interactive Star Rating
  Widget _buildStarRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '1. Nilai Pengalaman Sesi (Star)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih skala bintang 1.0 sampai 5.0',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 5 Large Interactive Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starScore = (index + 1).toDouble();
              final isFilled = _rating >= starScore;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starScore;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isFilled ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                      size: 38,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Dynamic Feedback Label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey<double>(_rating),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRatingFeedbackLabel(_rating),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 2: Ulasan Singkat Form Input with Character Limit
  Widget _buildShortReviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '2. Ulasan Singkat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                'Maks. 50 Karakter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tuliskan satu kalimat ulasan singkat atau kesan utama sesimu',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Plain Form Input with Character Limit
          TextField(
            controller: _labelController,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Contoh: Sangat Sabar & Solutif',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textLight,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              counterStyle: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: AppColors.textLight,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 3: Deskripsi Ulasan
  Widget _buildDescriptionInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3. Deskripsi Ulasan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Opsional',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ceritakan pengalaman, cara konselor membantumu, atau saran perbaikan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText:
                  'Contoh: Konselor sangat sabar mendengarkan tanpa menghakimi. Teknik grounding yang diajarkan sangat membantu meredakan rasa cemas sehari-hari.',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textLight,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kirim Ulasan Secara Anonim',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nama & profil Anda tidak diperlihatkan ke publik demi privasi medis.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (val) => setState(() => _isAnonymous = val),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSubmitDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.initialRating != null
                          ? 'Perbarui Penilaian'
                          : 'Kirim Penilaian & Ulasan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

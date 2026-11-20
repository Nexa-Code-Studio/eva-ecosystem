import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import 'counselor_edit_profile_modal.dart';
import 'counselor_reviews_modal.dart';

class CounselorProfileHeaderCard extends StatelessWidget {
  final PsychologistUserEntity? user;
  final VoidCallback? onEditProfile;

  const CounselorProfileHeaderCard({
    super.key,
    required this.user,
    this.onEditProfile,
  });

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinBalance = user?.coinBalance ?? 0;
    final displayName = (user?.fullName != null && user!.fullName.isNotEmpty)
        ? user!.displayName
        : 'Psikolog Mandiri';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECEFF8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  CounselorEditProfileModal.show(context, user: user);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.primaryContainer,
                      backgroundImage: getProfileImageProvider(user?.profilePhotoUrl),
                      child: getProfileImageProvider(user?.profilePhotoUrl) == null
                          ? const Icon(Icons.person,
                              size: 34, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge.proIndependent('Psikolog Mandiri'),
                        StatusBadge.coins(coinBalance),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // EDIT PROFILE BUTTON
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                tooltip: 'Edit Profil',
                onPressed: () {
                  if (onEditProfile != null) {
                    onEditProfile!();
                  } else {
                    CounselorEditProfileModal.show(context, user: user);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InkWell(
                  onTap: () =>
                      CounselorReviewsModal.show(context, totalSessions: 0),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: _statItem('Baru ⭐', '0 Ulasan >'),
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFE2E5F0)),
                _statItem('0 Sesi', 'Bulan Ini'),
                Container(width: 1, height: 28, color: const Color(0xFFE2E5F0)),
                _statItem('100%', 'Respon Booking'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

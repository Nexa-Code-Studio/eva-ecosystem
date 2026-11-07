import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import 'counselor_reviews_modal.dart';

class CounselorProfileHeaderCard extends StatelessWidget {
  final PsychologistUserEntity? user;

  const CounselorProfileHeaderCard({super.key, required this.user});

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: user?.profilePhotoUrl != null
                    ? NetworkImage(user!.profilePhotoUrl!)
                    : null,
                child: user?.profilePhotoUrl == null
                    ? const Icon(Icons.person, size: 34, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'dr. Sarah Jenkins, M.Psi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'sarah.jenkins@psikolog.eva.id',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (user?.isVolunteer == true)
                          StatusBadge.volunteer('Relawan Teman Sebaya')
                        else if (user?.isPartner == true)
                          StatusBadge.proPartner('Psikolog Mitra')
                        else
                          StatusBadge.proIndependent('Psikolog Mandiri'),
                        if (user?.isProfessional == true)
                          StatusBadge.coins(user?.coinBalance ?? 1250),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                  onTap: () => CounselorReviewsModal.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: _statItem('⭐ 4.9', '140 Ulasan >'),
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFE2E5F0)),
                _statItem('38', 'Sesi Bulan Ini'),
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

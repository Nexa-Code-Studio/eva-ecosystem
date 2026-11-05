import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/presentation/providers/patient_provider.dart';

class CounselorHomeScreen extends ConsumerWidget {
  const CounselorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final patientsAsync = ref.watch(patientsListProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile & Availability Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: user?.profilePhotoUrl != null
                            ? NetworkImage(user!.profilePhotoUrl!)
                            : null,
                        child: user?.profilePhotoUrl == null
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Psikolog Mitra',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              StatusBadge.verified('STR Aktif'),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: (user?.isOnline ?? true)
                                      ? AppColors.verifiedGreen
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (user?.isOnline ?? true)
                                    ? 'Online'
                                    : 'Istirahat (Offline)',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: user?.isOnline ?? true,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      ref
                          .read(authStateProvider.notifier)
                          .toggleAvailability(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Upcoming Teleconsultation Banner Card
              GlassCard(
                backgroundColor: AppColors.primary,
                customBorder: Border.all(color: Colors.transparent),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.video_camera_front_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'SESI TELEKONSULTASI BERIKUTNYA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Dalam 15 Menit',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Rian Pratama (26 Thn)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Topik: Evaluasi Lanjutan Kecemasan Akademik & Pacer Napas',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    CustomButton(
                      label: 'Buka Ruang Video Call',
                      icon: Icons.videocam_rounded,
                      variant: ButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/counselor-video-call',
                          arguments: 'session-live-001',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // High Risk Patient Alert Banner (If Any)
              patientsAsync.when(
                data: (patients) {
                  final highRiskPatients =
                      patients.where((p) => p.isHighRisk).toList();
                  if (highRiskPatients.isEmpty) return const SizedBox.shrink();

                  final target = highRiskPatients.first;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.highRiskBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.highRiskRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.crisis_alert_rounded,
                            color: AppColors.highRiskRed, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Peringatan Distres Akut Pasien',
                                style: AppTypography.headingSmall.copyWith(
                                  color: AppColors.highRiskRed,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${target.name} mengalami lonjakan stres berat dan skor DASS krisis. Sistem EVA menyarankan peninjauan catatan & de-eskalasi.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.highRiskRed.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Quick Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              color: AppColors.primary, size: 24),
                          const SizedBox(height: 8),
                          Text('8 Pasien', style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text('Sedang Dampingi', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              color: AppColors.verifiedGreen, size: 24),
                          const SizedBox(height: 8),
                          Text('Rp 2.450.000', style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text('Saldo Tersedia', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Navigation to Patients
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pasien Terbaru', style: AppTypography.headingMedium),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/counselor-patients');
                    },
                    child: Text(
                      'Lihat Semua',
                      style: AppTypography.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              patientsAsync.when(
                data: (patients) {
                  return Column(
                    children: patients.take(3).map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/counselor-patient-detail',
                              arguments: p.id,
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: p.isHighRisk
                                    ? AppColors.highRiskBg
                                    : AppColors.primaryContainer,
                                child: Text(
                                  p.name.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: p.isHighRisk
                                        ? AppColors.highRiskRed
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: AppTypography.headingSmall.copyWith(fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.chiefComplaint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              p.hasConsent
                                  ? StatusBadge.consentGranted('Akses Ada')
                                  : StatusBadge.consentLocked('Terkunci'),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

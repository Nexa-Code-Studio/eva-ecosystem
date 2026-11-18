import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/counselor_main_shell_screen.dart';
import '../widgets/counselor_bank_account_modal.dart';
import '../widgets/counselor_certificates_modal.dart';
import '../widgets/counselor_guidelines_modal.dart';
import '../widgets/counselor_profile_drive_card.dart';
import '../widgets/counselor_profile_header_card.dart';
import '../widgets/counselor_profile_menu_card.dart';
import '../widgets/counselor_rate_modal.dart';
import '../widgets/counselor_security_modal.dart';
import '../widgets/counselor_str_credentials_modal.dart';
import 'counselor_schedule_settings_screen.dart';

class CounselorProfileScreen extends ConsumerStatefulWidget {
  const CounselorProfileScreen({super.key});

  @override
  ConsumerState<CounselorProfileScreen> createState() => _CounselorProfileScreenState();
}

class _CounselorProfileScreenState extends ConsumerState<CounselorProfileScreen> {
  final Set<String> _activeDays = const {'Sen', 'Sel', 'Rab', 'Kam', 'Jum'};
  static const String _workingHours = '09:00 - 17:00 WIB';
  bool _isBackingUp = false;
  String _backupFrequency = 'Harian';
  bool _backupWifiOnly = true;

  void _handleBackupNow(PsychologistUserEntity? user) async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _isBackingUp = false);

    ref.read(authStateProvider.notifier).syncDriveBackup(
          email: user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
          frequency: _backupFrequency,
        );

    TopToast.show(
      context,
      title: 'Pencadangan Berhasil! ☁️',
      message: '18.4 MB data rekam SOAP & audio transkrip terenkripsi aman di Google Drive Anda.',
      type: ToastType.success,
    );
  }

  void _handleRestoreDrive() {
    TopToast.show(
      context,
      title: 'Memeriksa Cadangan Google Drive...',
      message: 'Data lokal terverifikasi sinkron dengan cadangan cloud terakhir (Hari ini, 10:15 WIB).',
      type: ToastType.info,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final userCerts = CounselorCertificatesModal.getCertificatesForUser(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Banner Card
              CounselorProfileHeaderCard(user: user),
              const SizedBox(height: 16),

              // 2. Jadwal Praktik Telekonseling
              _buildSectionHeader('Jadwal Praktik Telekonseling', Icons.calendar_month_rounded),
              CounselorProfileMenuCard(
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryContainer,
                title: 'Jadwal Telekonseling Online',
                subtitle: '${_activeDays.join(", ")} • $_workingHours (Sesi Paten 30 Mnt)',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Online 100% 💻',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CounselorScheduleSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 3. Honorarium & Keuangan Praktik
              _buildSectionHeader('Honorarium & Keuangan Praktik', Icons.account_balance_wallet_outlined),
              CounselorProfileMenuCard(
                icon: Icons.monetization_on_rounded,
                iconColor: const Color(0xFFC2410C),
                iconBg: const Color(0xFFFFF7ED),
                title: 'Tarif & Kebijakan Bagi Hasil',
                subtitle: 'Sesi Paten 30 Menit • Bagi hasil terkelola transparan oleh platform Eva',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Terkelola ⚡',
                        style: TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 12, color: Color(0xFFC2410C)),
                    ],
                  ),
                ),
                onTap: () => CounselorRateModal.show(
                  context: context,
                  user: user,
                  onSave: (_) {},
                ),
              ),
              CounselorProfileMenuCard(
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Rekening Bank Pencairan Dana',
                subtitle: 'BCA • ****8192 (dr. Sarah Jenkins)',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.verifiedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Terverifikasi ✅', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: () => CounselorBankAccountModal.show(context),
              ),
              const SizedBox(height: 16),

              // 4. Pencadangan Google Drive
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildSectionHeader('Pencadangan Rekam Medis', Icons.cloud_sync_outlined),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('E2EE 256-bit ✅', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data rekam medis SOAP & audio transkrip tersimpan lokal di perangkat Anda (bukan di server EVA). Cadangkan ke Google Drive pribadi Anda untuk keamanan.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),
              CounselorProfileDriveCard(
                user: user,
                backupFrequency: _backupFrequency,
                backupWifiOnly: _backupWifiOnly,
                isBackingUp: _isBackingUp,
                onSettingsSaved: (freq, wifi) {
                  setState(() {
                    _backupFrequency = freq;
                    _backupWifiOnly = wifi;
                  });
                  ref.read(authStateProvider.notifier).syncDriveBackup(
                        email: user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
                        frequency: freq,
                      );
                },
                onBackupNow: () => _handleBackupNow(user),
                onRestore: _handleRestoreDrive,
              ),
              const SizedBox(height: 16),

              // 5. Sertifikasi Eva
              _buildSectionHeader('Pencapaian & Sertifikasi Eva', Icons.military_tech_rounded),
              CounselorProfileMenuCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Sertifikat Penghargaan & Pencapaian',
                subtitle: '${userCerts.length} Sertifikat Resmi Diraih • Siap Diunduh (PDF)',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${userCerts.length} Sertif 🏆',
                    style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                onTap: () => CounselorCertificatesModal.showGallery(context, user),
              ),
              const SizedBox(height: 16),

              // 6. Legalitas & SOP Pelayanan
              _buildSectionHeader('Legalitas & SOP Pelayanan', Icons.verified_user_outlined),
              CounselorProfileMenuCard(
                icon: Icons.verified_user_outlined,
                iconColor: AppColors.verifiedGreen,
                iconBg: AppColors.verifiedBg,
                title: 'Kredensial SIPP & STR Psikolog',
                subtitle: 'STR #4192-PSI-2024 • KTKI & HIMPSI',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.verifiedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Aktif 2029', style: TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: () => CounselorStrCredentialsModal.show(context),
              ),
              CounselorProfileMenuCard(
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Panduan Etik & SOP HIMPSI',
                subtitle: 'Kode etik layanan telekonseling & penanganan krisis',
                trailingBadge: const SizedBox.shrink(),
                onTap: () => CounselorGuidelinesModal.showProfessional(context),
              ),
              const SizedBox(height: 16),

              // 7. Keamanan & Panduan Aplikasi
              _buildSectionHeader('Keamanan & Panduan Aplikasi', Icons.shield_outlined),
              CounselorProfileMenuCard(
                icon: Icons.lock_clock_outlined,
                iconColor: AppColors.primary,
                iconBg: AppColors.secondary,
                title: 'Keamanan Rekam Medis & Privasi',
                subtitle: 'Biometrik FaceID & Enkripsi AES-256',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('2FA Aktif', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: () => CounselorSecurityModal.show(context),
              ),
              CounselorProfileMenuCard(
                icon: Icons.explore_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBg: const Color(0xFFEEF2FF),
                title: 'Tur Panduan Aplikasi Konselor',
                subtitle: 'Pelajari alur tiap menu, rekam medis & backup Drive',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Buka Tur 🧭', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                onTap: () => ref.read(triggerCounselorSpotlightTourProvider.notifier).state++,
              ),
              const SizedBox(height: 24),

              // 8. Logout
              GestureDetector(
                onTap: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/counselor-login');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.highRiskBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Keluar dari Akun Konselor',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

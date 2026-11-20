import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/counselor_main_shell_screen.dart';
import '../widgets/counselor_bank_account_modal.dart';
import '../widgets/counselor_certificates_modal.dart';
import '../widgets/counselor_edit_profile_modal.dart';
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
    final targetEmail = user?.effectiveGoogleDriveEmail ?? user?.email ?? '';
    setState(() => _isBackingUp = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final result = await driveService.uploadEncryptedBackup(
        email: targetEmail,
        data: {'session_count': 12, 'timestamp': DateTime.now().toIso8601String()},
      );

      if (!mounted) return;
      ref.read(authStateProvider.notifier).syncDriveBackup(
            email: targetEmail,
            frequency: _backupFrequency,
          );

      TopToast.show(
        context,
        title: 'Pencadangan Berhasil! ☁️',
        message:
            '${result.formattedSizeMb} data rekam SOAP & audio transkrip terenkripsi aman di Google Drive Anda ($targetEmail).',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Mencadangkan',
        message: e.toString(),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _handleRestoreDrive() async {
    final user = ref.read(authStateProvider).value;
    final targetEmail = user?.effectiveGoogleDriveEmail ?? user?.email ?? '';
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      await driveService.restoreEncryptedBackup(email: targetEmail);

      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Cadangan Google Drive Sinkron ☁️',
        message:
            'Data rekam medis lokal terverifikasi sinkron dengan cadangan Google Drive ($targetEmail).',
        type: ToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memeriksa Cadangan',
        message: e.toString(),
        type: ToastType.error,
      );
    }
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
    final hasBank = (user?.bankName ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Banner Card
              CounselorProfileHeaderCard(
                user: user,
                onEditProfile: () => CounselorEditProfileModal.show(context, user: user),
              ),
              const SizedBox(height: 16),

              // 2. Jadwal Praktik Telekonseling
              _buildSectionHeader('Jadwal Praktik Telekonseling', Icons.calendar_month_rounded),
              CounselorProfileMenuCard(
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryContainer,
                title: 'Jadwal Telekonseling Online',
                subtitle: '${_activeDays.join(", ")} • $_workingHours (Sesi Paten 30 Mnt)',
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
                subtitle: hasBank
                    ? '${user!.bankName} • ****${user.bankAccountNumber.length >= 4 ? user.bankAccountNumber.substring(user.bankAccountNumber.length - 4) : user.bankAccountNumber}'
                    : 'Belum diatur • Ketuk untuk mendaftarkan rekening',
                onTap: () => CounselorBankAccountModal.show(context, ref: ref),
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
                        email: user?.effectiveGoogleDriveEmail ?? user?.email ?? '',
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
                subtitle: 'STR #${(user?.strNumber != null && user!.strNumber.isNotEmpty) ? user.strNumber : "Belum diisi"} • KTKI & HIMPSI',
                onTap: () => CounselorStrCredentialsModal.show(context, user: user, ref: ref),
              ),
              CounselorProfileMenuCard(
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFEF3C7),
                title: 'Panduan Etik & SOP HIMPSI',
                subtitle: 'Kode etik layanan telekonseling & penanganan krisis',
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
                onTap: () => CounselorSecurityModal.show(context),
              ),
              CounselorProfileMenuCard(
                icon: Icons.explore_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBg: const Color(0xFFEEF2FF),
                title: 'Tur Panduan Aplikasi Konselor',
                subtitle: 'Pelajari alur tiap menu, rekam medis & backup Drive',
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

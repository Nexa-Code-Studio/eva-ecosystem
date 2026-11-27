import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../domain/entities/psychologist_user_entity.dart';
import '../providers/auth_provider.dart';

class VerificationPendingScreen extends ConsumerStatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  ConsumerState<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState
    extends ConsumerState<VerificationPendingScreen> {
  bool _isRefreshing = false;

  void _handleRefreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(authStateProvider.notifier).checkAuthSession();
      final user = ref.read(authStateProvider).value;
      if (!mounted) return;

      if (user?.verificationStatus == VerificationStatus.verified) {
        TopToast.show(
          context,
          title: 'Verifikasi Berhasil',
          message: 'Akun profesional Anda telah disetujui. Selamat datang di Eva.',
          type: ToastType.success,
        );
        Navigator.of(context).pushReplacementNamed('/counselor-shell');
      } else if (user?.verificationStatus == VerificationStatus.needRevision ||
          user?.verificationStatus == VerificationStatus.rejected) {
        Navigator.of(context)
            .pushReplacementNamed('/counselor-verification-rejected');
      } else {
        TopToast.show(
          context,
          title: 'Status: Masih Ditinjau ⏳',
          message:
              'Berkas pendaftaran Anda masih dalam antrean peninjauan oleh tim admin di Web Portal.',
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memeriksa Status',
        message: e.toString(),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _handleLogout() async {
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/counselor-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Header Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 40,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Dokumen Sedang Ditinjau',
                style: AppTypography.headingLarge.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Berkas STR dan SIPP Anda sedang diverifikasi tim kredensial (maksimal 1x24 jam kerja).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Summary Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kredensial Diajukan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule,
                                  size: 12, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _infoRow('Nama Lengkap', user?.fullName ?? 'Psikolog Profesional'),
                    const SizedBox(height: 10),
                    _infoRow('Gelar Klinis', user?.titleDegree ?? 'M.Psi., Psikolog'),
                    const SizedBox(height: 10),
                    _infoRow('Nomor STR', user?.strNumber ?? 'Dalam Verifikasi'),
                    const SizedBox(height: 10),
                    _infoRow('Asosiasi Profesi', user?.association ?? 'HIMPSI'),
                    const SizedBox(height: 10),
                    _infoRow('Email Terdaftar', user?.email ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Refresh Button
              CustomButton(
                label: 'Periksa Status Verifikasi',
                icon: Icons.refresh_rounded,
                isLoading: _isRefreshing,
                onPressed: _handleRefreshStatus,
              ),
              const SizedBox(height: 12),

              // Helpdesk & Contact
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xFFD0D4E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded,
                    size: 18, color: AppColors.textPrimary),
                label: const Text(
                  'Hubungi Tim Kredensial',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  TopToast.show(
                    context,
                    title: 'Bantuan Kredensial Eva',
                    message:
                        'Kirim pertanyaan atau dokumen pendukung ke kredensial@psikolog.eva.id',
                    type: ToastType.info,
                  );
                },
              ),
              const SizedBox(height: 20),

              // Logout Link
              GestureDetector(
                onTap: _handleLogout,
                child: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

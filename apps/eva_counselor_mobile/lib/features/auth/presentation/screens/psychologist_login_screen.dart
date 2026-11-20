import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../domain/entities/psychologist_user_entity.dart';
import '../providers/auth_provider.dart';

class PsychologistLoginScreen extends ConsumerStatefulWidget {
  const PsychologistLoginScreen({super.key});

  @override
  ConsumerState<PsychologistLoginScreen> createState() =>
      _PsychologistLoginScreenState();
}

class _PsychologistLoginScreenState extends ConsumerState<PsychologistLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final rawEmail = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (rawEmail.isEmpty || password.isEmpty) {
      TopToast.show(
        context,
        title: 'Input Belum Lengkap',
        message: 'Mohon masukkan email atau username dan kata sandi.',
        type: ToastType.error,
      );
      return;
    }

    final email = (rawEmail.contains('@') ? rawEmail : '$rawEmail@gmail.com').toLowerCase().trim();

    setState(() => _isLoading = true);
    await ref
        .read(authStateProvider.notifier)
        .login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    final authState = ref.read(authStateProvider);
    final user = authState.value;

    if (authState.hasError || user == null) {
      final err = authState.error?.toString() ?? 'Email atau kata sandi tidak valid.';
      TopToast.show(
        context,
        title: 'Gagal Masuk',
        message: err.replaceFirst(RegExp(r'^Exception:\s*'), ''),
        type: ToastType.error,
      );
      return;
    }

    if (user.verificationStatus == VerificationStatus.pending) {
      Navigator.of(context)
          .pushReplacementNamed('/counselor-verification-pending');
      return;
    } else if (user.verificationStatus == VerificationStatus.rejected ||
        user.verificationStatus == VerificationStatus.needRevision) {
      Navigator.of(context)
          .pushReplacementNamed('/counselor-verification-rejected');
      return;
    }

    Navigator.of(context).pushReplacementNamed('/counselor-shell');
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final account = await driveService.signInWithGoogle();
      if (account != null) {
        setState(() {
          _emailController.text = account.email;
        });

        await ref
            .read(authStateProvider.notifier)
            .login(account.email, _passwordController.text);
        if (!mounted) return;

        final user = ref.read(authStateProvider).value;
        if (user != null) {
          ref.read(authStateProvider.notifier).syncDriveBackup(
                email: account.email,
                frequency: 'Harian',
              );
          Navigator.of(context).pushReplacementNamed('/counselor-shell');
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          title: 'Google Sign-In',
          message: 'Gagal menghubungkan akun Google: ${e.toString()}',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/eva_logo.png',
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.psychology_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Portal Psikolog EVA',
                style: AppTypography.headingLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola telekonsultasi, rekam psikologis pasien berizin, dan sesi video call.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Email Profesional',
                      hint: 'nama@psikolog.eva.id',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Kata Sandi',
                      hint: '••••••••',
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: _isPasswordVisible
                              ? AppColors.primary
                              : AppColors.textLight,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        splashRadius: 20,
                        tooltip: _isPasswordVisible
                            ? 'Sembunyikan Kata Sandi'
                            : 'Tampilkan Kata Sandi',
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Masuk Sebagai Psikolog',
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'atau masuk dengan',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Image.network(
                          'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 24,
                            color: AppColors.primary,
                          ),
                        ),
                        label: const Text(
                          'Masuk dengan Akun Google',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _emailController.text = 'khoirotunnisa2507@gmail.com';
                          _passwordController.text = 'password123';
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 13, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Akun Uji: khoirotunnisa2507 (dr. Sarah)',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Belum terdaftar sebagai psikolog profesional?',
                    style: AppTypography.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/counselor-register');
                    },
                    child: Text(
                      'Daftar di Sini',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Layanan resmi telekonseling berizin. Setiap praktisi wajib memiliki STR & SIPP aktif.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

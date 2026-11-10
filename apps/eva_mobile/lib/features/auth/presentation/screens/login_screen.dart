import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/custom_text_field.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/social_auth_dev_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDemoAccount() {
    setState(() {
      _emailController.text = AppConfig.demoEmail;
      _passwordController.text = AppConfig.demoPassword;
    });
    AppSnackBar.showPrimary(
      context,
      'Akun demo berhasil diisi (${AppConfig.demoEmail})',
      icon: Icons.check_circle_outline,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppSnackBar.showWarning(context, 'Silakan masukkan email dan kata sandi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login(email, password);

      if (!mounted) return;
      // Welcome snackbar is temporarily disabled upon initial login per user request
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        'Gagal masuk: ${e.toString().replaceAll('ApiException: ', '')}',
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3F5FF),
              Color(0xFFE9ECFF),
              Color(0xFFF8F9FE),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Logo
                    Image.asset(
                      'assets/images/eva_logo.png',
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.nightlight_round,
                          size: 44,
                          color: AppColors.primary,
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Selamat Datang Kembali',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Masuk untuk melanjutkan perjalanan ketenanganmu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Email Field
                    CustomPillTextField(
                      controller: _emailController,
                      hintText: 'Alamat Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Password Field
                    CustomPillTextField(
                      controller: _passwordController,
                      hintText: 'Kata Sandi',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 10),

                    // Demo Account Autofill Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('login_demo_autofill_button'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: _fillDemoAccount,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gunakan Akun Demo',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          )
                        : CustomPillButton(
                            text: 'Masuk',
                            onPressed: _handleLogin,
                          ),
                    const SizedBox(height: 20),

                    // Or Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFD6DCF5))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'atau masuk dengan',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFD6DCF5))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Social Login Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: SocialPillButton(
                            type: 'google',
                            onPressed: () {
                              showSocialAuthDevSheet(context, provider: 'Google');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SocialPillButton(
                            type: 'apple',
                            onPressed: () {
                              showSocialAuthDevSheet(context, provider: 'Apple');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Register Link Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/register');
                          },
                          child: Text(
                            'Daftar',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}

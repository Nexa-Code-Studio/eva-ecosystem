import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/custom_text_field.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/widgets/social_auth_dev_sheet.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _agreeTerms = false;
  bool _isLoading = false;

  Timer? _debounceTimer;
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable;
  String? _emailStatusMessage;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String val) {
    _debounceTimer?.cancel();
    final cleanEmail = val.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      setState(() {
        _isCheckingEmail = false;
        _isEmailAvailable = null;
        _emailStatusMessage = null;
      });
      return;
    }

    final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegExp.hasMatch(cleanEmail)) {
      setState(() {
        _isCheckingEmail = false;
        _isEmailAvailable = false;
        _emailStatusMessage = 'Format email belum valid';
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _isEmailAvailable = null;
      _emailStatusMessage = 'Memeriksa ketersediaan email...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await ref.read(authRepositoryProvider).checkEmailAvailability(cleanEmail);
        if (!mounted) return;

        final msg = available ? 'Email tersedia' : 'Email sudah terdaftar';
        setState(() {
          _isCheckingEmail = false;
          _isEmailAvailable = available;
          _emailStatusMessage = msg;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _isCheckingEmail = false;
            _isEmailAvailable = null;
            _emailStatusMessage = null;
          });
        }
      }
    });
  }

  Widget? _buildEmailSuffixIcon() {
    if (_isCheckingEmail) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_isEmailAvailable == true) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF2E7D32),
        size: 20,
      );
    }
    if (_isEmailAvailable == false) {
      return const Icon(
        Icons.cancel_rounded,
        color: Color(0xFFD32F2F),
        size: 20,
      );
    }
    return null;
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      AppSnackBar.showWarning(context, 'Silakan lengkapi semua data formulir');
      return;
    }

    if (_isCheckingEmail) {
      AppSnackBar.showPrimary(context, 'Sedang memeriksa email, mohon tunggu...');
      return;
    }

    if (_isEmailAvailable == false) {
      AppSnackBar.showError(
        context,
        _emailStatusMessage ?? 'Email sudah terdaftar atau tidak valid',
      );
      return;
    }

    if (!_agreeTerms) {
      AppSnackBar.showWarning(context, 'Anda harus menyetujui Syarat & Ketentuan Layanan');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.register(name, email, password);

      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Akun berhasil didaftarkan! Selamat datang di EVA, ${user.name}.',
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        'Registrasi gagal: ${e.toString().replaceAll('ApiException: ', '')}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                      'Buat Akun Baru',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Bergabung dengan EVA dan mulai merawat kesehatan mentalmu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name Field
                    CustomPillTextField(
                      controller: _nameController,
                      hintText: 'Nama Panggilan',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),

                    // Email Field
                    CustomPillTextField(
                      controller: _emailController,
                      hintText: 'Alamat Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      suffixIcon: _buildEmailSuffixIcon(),
                      onChanged: _onEmailChanged,
                    ),
                    if (_emailStatusMessage != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(
                            _emailStatusMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _isEmailAvailable == true
                                  ? const Color(0xFF2E7D32)
                                  : (_isEmailAvailable == false
                                      ? const Color(0xFFD32F2F)
                                      : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Password Field
                    CustomPillTextField(
                      controller: _passwordController,
                      hintText: 'Kata Sandi',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),

                    // Terms and Conditions Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _agreeTerms,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            side: const BorderSide(
                              color: Color(0xFFC7D2FE),
                              width: 1.5,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _agreeTerms = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Saya menyetujui ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Syarat & Ketentuan',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const TextSpan(text: ' serta '),
                                TextSpan(
                                  text: 'Kebijakan Privasi',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          )
                        : CustomPillButton(
                            text: 'Daftar Sekarang',
                            onPressed: _handleRegister,
                          ),
                    const SizedBox(height: 24),

                    // Or Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFD6DCF5))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'atau daftar dengan',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFD6DCF5))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Social Register Buttons Row
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

                    // Login Link Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah punya akun? ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            'Masuk',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/auth_provider.dart';

class PsychologistLoginScreen extends ConsumerStatefulWidget {
  const PsychologistLoginScreen({super.key});

  @override
  ConsumerState<PsychologistLoginScreen> createState() =>
      _PsychologistLoginScreenState();
}

class _PsychologistLoginScreenState extends ConsumerState<PsychologistLoginScreen> {
  final _emailController =
      TextEditingController(text: 'sarah.anindya@psikolog.eva.id');
  final _passwordController = TextEditingController(text: 'password123');
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await ref
        .read(authStateProvider.notifier)
        .login(_emailController.text, _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacementNamed('/counselor-shell');
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
                      color: AppColors.primary.withOpacity(0.15),
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
                    errorBuilder: (_, __, ___) => const Icon(
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
              const SizedBox(height: 36),
              GlassCard(
                padding: const EdgeInsets.all(20),
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
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Masuk Sebagai Psikolog',
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Belum terdaftar sebagai mitra?',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/counselor-register');
                    },
                    child: Text(
                      'Daftar & Upload STR',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

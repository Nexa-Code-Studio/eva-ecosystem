import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';

class PartnerCounselorActivationScreen extends ConsumerStatefulWidget {
  final String? invitationToken;
  final String? prefilledEmail;
  final String? partnerName;
  final String? fullName;

  const PartnerCounselorActivationScreen({
    super.key,
    this.invitationToken,
    this.prefilledEmail,
    this.partnerName,
    this.fullName,
  });

  @override
  ConsumerState<PartnerCounselorActivationScreen> createState() =>
      _PartnerCounselorActivationScreenState();
}

class _PartnerCounselorActivationScreenState
    extends ConsumerState<PartnerCounselorActivationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _partnerCtrl;
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(
      text: widget.prefilledEmail ?? 'sarah.lestari@gmail.com',
    );
    _nameCtrl = TextEditingController(
      text: widget.fullName ?? 'Dr. Sarah Lestari, M.Psi., Psikolog',
    );
    _partnerCtrl = TextEditingController(
      text: widget.partnerName ?? 'RS Mitra Sehati Jakarta',
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _partnerCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleActivate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await ref.read(authStateProvider.notifier).activatePartnerAccount(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          partnerName: _partnerCtrl.text.trim(),
          fullName: _nameCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showActivationSuccessDialog();
  }

  void _showActivationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF7E22CE),
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Akun Mitra Berhasil Diaktifkan!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kata sandi Anda telah berhasil dibuat. Anda terafiliasi dengan ${_partnerCtrl.text} dan kini dapat masuk menggunakan email ${_emailCtrl.text}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Masuk ke Beranda Konselor',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacementNamed('/counselor-shell');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/counselor-login'),
        ),
        title: Text(
          'Aktivasi Akun Mitra',
          style: AppTypography.headingMedium.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Welcome Banner (Soft Violet & Clean)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6B21A8), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E22CE).withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_email_read_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Tautan Undangan Email Terverifikasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Selamat Datang di EVA Konselor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Institusi mitra telah mendaftarkan detail profil Anda. Silakan buat kata sandi baru untuk mengamankan akun dan mulai praktik telekonsultasi.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD 1: DETAIL AKUN DARI MITRA (READ-ONLY / PRE-FILLED)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Informasi Akun Didaftarkan Mitra',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Data Resmi Mitra',
                        style: TextStyle(
                          color: Color(0xFF7E22CE),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Lembaga / RS Mitra Pengundang',
                        hint: 'Nama Mitra',
                        controller: _partnerCtrl,
                        prefixIcon: Icons.apartment_rounded,
                        readOnly: true,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Nama Lengkap Psikolog',
                        hint: 'Nama Psikolog',
                        controller: _nameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                        readOnly: true,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Email Terdaftar (Gmail / Akun Mitra)',
                        hint: 'nama@gmail.com',
                        controller: _emailCtrl,
                        prefixIcon: Icons.email_outlined,
                        readOnly: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD 2: BUAT KATA SANDI (STEP 4)
                const Text(
                  'Buat Kata Sandi Akun Baru',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kata sandi ini akan Anda gunakan untuk login mandiri di aplikasi EVA setiap saat.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Kata Sandi Baru',
                        hint: 'Minimal 6 karakter',
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                          if (v.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // PROTOCOL INFO CAPSULE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF7E22CE), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ketentuan Psikolog Mitra: Jadwal praktik & honorarium koin Anda dikelola terpusat oleh administrator Mitra via Web Portal Mitra. Rekam medis SOAP klinis tersimpan secara lokal di perangkat Anda (E2EE 256-bit).',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B21A8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SUBMIT BUTTON
                CustomButton(
                  label: 'Simpan Kata Sandi & Masuk ke EVA',
                  isLoading: _isLoading,
                  onPressed: _handleActivate,
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/counselor-login');
                    },
                    child: const Text(
                      'Sudah Pernah Aktivasi? Masuk ke Halaman Login',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

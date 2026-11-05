import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/auth_provider.dart';

class PsychologistRegistrationScreen extends ConsumerStatefulWidget {
  const PsychologistRegistrationScreen({super.key});

  @override
  ConsumerState<PsychologistRegistrationScreen> createState() =>
      _PsychologistRegistrationScreenState();
}

class _PsychologistRegistrationScreenState
    extends ConsumerState<PsychologistRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController(text: 'M.Psi., Psikolog Klinis');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _associationCtrl =
      TextEditingController(text: 'Himpunan Psikologi Indonesia (HIMPSI)');
  final _rateCtrl = TextEditingController(text: '200000');

  String? _uploadedFileName;
  bool _isLoading = false;

  final List<String> _availableSpecializations = [
    'Kecemasan Dewasa',
    'Depresi & Suasana Hati',
    'Manajemen Stres & Burnout',
    'Konseling Remaja & Akademik',
    'Hubungan & Keluarga',
    'Trauma & PTSD',
  ];
  final Set<String> _selectedSpecializations = {'Kecemasan Dewasa', 'Manajemen Stres & Burnout'};

  void _handlePickFile() {
    setState(() {
      _uploadedFileName = 'STR_Psikolog_${DateTime.now().year}_scan.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen STR berhasil dipilih untuk verifikasi.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lampirkan scan STR/SIPP untuk verifikasi legalitas praktik.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await ref.read(authStateProvider.notifier).register(
          fullName: _fullNameCtrl.text,
          titleDegree: _degreeCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          strNumber: _strCtrl.text,
          association: _associationCtrl.text,
          specializations: _selectedSpecializations.toList(),
          yearsOfExperience: 3,
          consultationRate: int.tryParse(_rateCtrl.text) ?? 200000,
          certificateDocFileName: _uploadedFileName!,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_user_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Pendaftaran Terkirim'),
          ],
        ),
        content: const Text(
          'Pendaftaran akun psikolog dan berkas STR Anda telah berhasil diunggah. Tim klinis EVA akan memverifikasi dokumen Anda dalam 1x24 jam kerja.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacementNamed('/counselor-shell');
            },
            child: const Text('Buka Dashboard Mitra'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pendaftaran Mitra Psikolog', style: AppTypography.headingMedium),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kredensial Profesional',
                  style: AppTypography.headingSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Pastikan data sesuai dengan sertifikasi resmi HIMPSI atau Kemenkes.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Nama Lengkap (Tanpa Gelar)',
                        hint: 'cth: Sarah Anindya',
                        controller: _fullNameCtrl,
                        prefixIcon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Gelar Akademik & Profesi',
                        hint: 'cth: M.Psi., Psikolog',
                        controller: _degreeCtrl,
                        prefixIcon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Email Profesional',
                        hint: 'nama@psikolog.eva.id',
                        controller: _emailCtrl,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Kata Sandi',
                        hint: '••••••••',
                        controller: _passwordCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                        validator: (v) => (v?.length ?? 0) < 6 ? 'Min. 6 karakter' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Nomor STR / SIPP Aktif',
                        hint: 'cth: STR-PK-198827364-2024',
                        controller: _strCtrl,
                        prefixIcon: Icons.badge_outlined,
                        validator: (v) => v!.isEmpty ? 'Nomor STR/SIPP wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Tarif Konsultasi per Sesi (Rp)',
                        hint: '200000',
                        controller: _rateCtrl,
                        prefixIcon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Fokus Spesialisasi Klinis', style: AppTypography.headingSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSpecializations.map((spec) {
                    final isSelected = _selectedSpecializations.contains(spec);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(spec),
                      selectedColor: AppColors.primaryContainer,
                      checkmarkColor: AppColors.primary,
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSpecializations.add(spec);
                          } else {
                            _selectedSpecializations.remove(spec);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Unggah Berkas Legalitas (STR / SIPP)', style: AppTypography.headingSmall),
                const SizedBox(height: 6),
                Text(
                  'Format PDF atau JPG/PNG (Maks 5MB) untuk diverifikasi oleh Dewan Etik EVA.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _handlePickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _uploadedFileName != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.cloud_upload_outlined,
                          size: 38,
                          color: _uploadedFileName != null
                              ? AppColors.verifiedGreen
                              : AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uploadedFileName ?? 'Klik untuk Memilih File Scan STR/SIPP',
                          style: AppTypography.headingSmall.copyWith(
                            fontSize: 14,
                            color: _uploadedFileName != null
                                ? AppColors.verifiedGreen
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  label: 'Kirim Pendaftaran & Berkas',
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
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

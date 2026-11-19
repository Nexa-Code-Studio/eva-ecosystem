import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/top_toast.dart';
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

  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController(text: 'M.Psi., Psikolog Klinis');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _sipCtrl = TextEditingController();
  final _associationCtrl =
      TextEditingController(text: 'Himpunan Psikologi Indonesia (HIMPSI)');

  // Durasi paten platform
  static const int _sessionDurationMinutes = 30;

  String? _uploadedFileName;
  bool _isLoading = false;

  final List<String> _availableSpecializations = [
    'Kecemasan Dewasa',
    'Depresi & Suasana Hati',
    'Manajemen Stres & Burnout',
    'Konseling Remaja & Akademik',
    'Hubungan & Komunikasi',
    'Trauma & Regulasi Emosi',
    'Quarter-life Crisis',
  ];
  final Set<String> _selectedSpecializations = {
    'Kecemasan Dewasa',
    'Manajemen Stres & Burnout',
  };

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _degreeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _strCtrl.dispose();
    _sipCtrl.dispose();
    _associationCtrl.dispose();
    super.dispose();
  }

  void _handlePickFile() {
    setState(() {
      _uploadedFileName = 'STR_Psikolog_${DateTime.now().year}_scan.pdf';
    });
    TopToast.show(
      context,
      title: 'Berkas Legalitas Terpilih 📄',
      message: 'Scan STR/SIPP siap dilampirkan: $_uploadedFileName',
      type: ToastType.success,
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uploadedFileName == null) {
      TopToast.show(
        context,
        title: 'Dokumen STR Belum Dilampirkan',
        message: 'Mohon lampirkan scan STR/SIPP untuk verifikasi akun profesional.',
        type: ToastType.error,
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
          consultationRate: 100000,
          certificateDocFileName: _uploadedFileName ?? 'none',
          counselorRole: 'professional_independent',
          partnerName: null,
          sessionDurationMinutes: _sessionDurationMinutes,
          coinsPerSession: 0,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
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
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 38,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pendaftaran Terkirim',
              style: AppTypography.headingMedium.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Pendaftaran akun Psikolog Mandiri dan dokumen STR/SIPP Anda telah berhasil diunggah. Akun Anda akan ditinjau oleh tim kredensial dalam 1x24 jam kerja.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Lihat Status Pengajuan',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context)
                    .pushReplacementNamed('/counselor-verification-pending');
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
        centerTitle: false,
        title: Text(
          'Pendaftaran Psikolog Profesional',
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
                // Top Header Intro Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Praktisi Individu Profesional',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Bergabung sebagai psikolog mandiri berlisensi di platform telekonseling Eva.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SECTION 1: IDENTITAS UTAMA
                const Text(
                  'Data Akun & Identitas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                        label: 'Nama Lengkap (Sesuai KTP / Ijazah)',
                        hint: 'cth: Dimas Wicaksono',
                        controller: _fullNameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Gelar Akademik & Profesi',
                        hint: 'cth: M.Psi., Psikolog Klinis',
                        controller: _degreeCtrl,
                        prefixIcon: Icons.school_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Gelar wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Email Profesional',
                        hint: 'nama@email.com',
                        controller: _emailCtrl,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Email wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Kata Sandi',
                        hint: '••••••••',
                        controller: _passwordCtrl,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (v) =>
                            (v?.length ?? 0) < 6 ? 'Minimal 6 karakter' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 2: KREDENSIAL PROFESIONAL
                const Text(
                  'Kredensial Legalitas Klinis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                        label: 'Nomor STR / Surat Tanda Registrasi',
                        hint: 'cth: STR-PK-198827364-2026',
                        controller: _strCtrl,
                        prefixIcon: Icons.badge_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nomor STR wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Nomor SIPP / SIP Psikolog',
                        hint: 'cth: 503/SIP-PSI/DKS/2024',
                        controller: _sipCtrl,
                        prefixIcon: Icons.assignment_outlined,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Organisasi Profesi',
                        hint: 'cth: HIMPSI',
                        controller: _associationCtrl,
                        prefixIcon: Icons.corporate_fare_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 3: KEBIJAKAN SESI PLATFORM
                const Text(
                  'Standar Sesi Telekonseling Eva',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Durasi Paten 30 Menit / Sesi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Setiap slot telekonseling diatur paten 30 menit. Pasien dapat melakukan booking dinamis sesuai jam operasional yang Anda buka di aplikasi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      Divider(height: 18),
                      Row(
                        children: [
                          Icon(Icons.savings_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Tarif & Bagi Hasil Terkelola',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tarif per sesi dan skema bagi hasil ditetapkan transparan oleh platform Eva dan langsung disalurkan ke rekening bank Anda setelah sesi diverifikasi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 4: PEMINATAN KLINIS
                const Text(
                  'Fokus Peminatan Klinis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSpecializations.map((spec) {
                    final isSelected = _selectedSpecializations.contains(spec);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(spec),
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primaryContainer,
                      checkmarkColor: AppColors.primary,
                      showCheckmark: isSelected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : const Color(0xFFECEFF8),
                          width: 1.0,
                        ),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSpecializations.add(spec);
                          } else {
                            if (_selectedSpecializations.length > 1) {
                              _selectedSpecializations.remove(spec);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // SECTION 5: UNGGAH SCAN STR/SIPP
                const Text(
                  'Unggah Berkas Scan STR / SIPP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Format PDF, JPG, atau PNG (Maksimal 5 MB) untuk diverifikasi tim kredensial.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _handlePickFile,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _uploadedFileName != null
                            ? AppColors.verifiedGreen.withValues(alpha: 0.5)
                            : const Color(0xFFD6DBEC),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _uploadedFileName != null
                              ? Icons.task_alt_rounded
                              : Icons.cloud_upload_outlined,
                          size: 36,
                          color: _uploadedFileName != null
                              ? AppColors.verifiedGreen
                              : AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uploadedFileName ??
                              'Pilih Dokumen Scan STR/SIPP (Maks. 5 MB)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _uploadedFileName != null
                                ? AppColors.verifiedGreen
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // CTA SUBMIT BUTTON
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

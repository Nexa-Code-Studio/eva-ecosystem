import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../domain/entities/psychologist_user_entity.dart';
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

  // Role Category Selection
  CounselorRole _selectedRole = CounselorRole.professionalIndependent;

  // Controllers
  final _fullNameCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController(text: 'M.Psi., Psikolog Klinis');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _associationCtrl =
      TextEditingController(text: 'Himpunan Psikologi Indonesia (HIMPSI)');
  final _partnerNameCtrl =
      TextEditingController(text: 'RS Mitra Sehati Jakarta');
  final _volunteerCommunityCtrl =
      TextEditingController(text: 'Komunitas Teman Curhat Mahasiswa');

  // Session & Coin Settings (Khusus Profesional Mandiri)
  int _sessionDurationMinutes = 50;
  final _coinsPerSessionCtrl = TextEditingController(text: '150');

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
    _associationCtrl.dispose();
    _partnerNameCtrl.dispose();
    _volunteerCommunityCtrl.dispose();
    _coinsPerSessionCtrl.dispose();
    super.dispose();
  }

  void _handlePickFile() {
    setState(() {
      _uploadedFileName = 'STR_Psikolog_${DateTime.now().year}_scan.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dokumen STR / Berkas Legalitas berhasil dipilih.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check certificate requirement (Only for professionals)
    if (_selectedRole != CounselorRole.peerVolunteer && _uploadedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mohon lampirkan scan STR/SIPP untuk verifikasi akun profesional.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final roleString = _selectedRole == CounselorRole.peerVolunteer
        ? 'peer_volunteer'
        : 'professional_independent';

    final coins = int.tryParse(_coinsPerSessionCtrl.text) ?? 150;

    await ref.read(authStateProvider.notifier).register(
          fullName: _fullNameCtrl.text,
          titleDegree: _selectedRole == CounselorRole.peerVolunteer
              ? 'Relawan Teman Sebaya'
              : _degreeCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          strNumber: _selectedRole == CounselorRole.peerVolunteer
              ? 'VOLUNTEER-PEER'
              : _strCtrl.text,
          association: _selectedRole == CounselorRole.peerVolunteer
              ? _volunteerCommunityCtrl.text
              : _associationCtrl.text,
          specializations: _selectedSpecializations.toList(),
          yearsOfExperience: _selectedRole == CounselorRole.peerVolunteer ? 1 : 3,
          consultationRate: _selectedRole == CounselorRole.peerVolunteer
              ? 0
              : coins * 1000,
          certificateDocFileName: _uploadedFileName ?? 'none',
          counselorRole: roleString,
          partnerName: null,
          sessionDurationMinutes: _sessionDurationMinutes,
          coinsPerSession: _selectedRole == CounselorRole.peerVolunteer ? 0 : coins,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    final isVolunteer = _selectedRole == CounselorRole.peerVolunteer;
    final title = isVolunteer
        ? 'Pendaftaran Relawan Berhasil'
        : 'Pendaftaran Profesional Terkirim';
    final message = isVolunteer
        ? 'Akun Relawan Teman Sebaya Anda telah aktif. Anda dapat langsung membuka jadwal ketersediaan untuk sesi curhat non-kritis tanpa perlu mengisi SOAP medis.'
        : 'Pendaftaran akun Psikolog Mandiri dan berkas STR Anda telah berhasil diunggah. Tarif $_sessionDurationMinutes mnt (${_coinsPerSessionCtrl.text} Koin) siap diaktifkan setelah verifikasi 1x24 jam.';
    final icon = isVolunteer
        ? Icons.volunteer_activism_rounded
        : Icons.verified_user_rounded;
    final iconColor = isVolunteer
        ? const Color(0xFF00796B)
        : AppColors.primary;

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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
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
        centerTitle: false,
        title: Text(
          'Pendaftaran Konselor',
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
                // Top Header Intro (Clean & Soft)
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
                          Icons.diversity_3_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Pilih Peran Layanan Anda',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih kategori relawan untuk menyesuaikan alur verifikasi & fitur aplikasi.',
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

                // 2 PILIHAN PENDAFTARAN MOBILE + 1 KARTU KHUSUS MITRA
                _buildCategoryOption(
                  role: CounselorRole.peerVolunteer,
                  title: 'Relawan Non-Profesional (Teman Sebaya)',
                  badge: 'Teman Curhat • Non-Komersial',
                  badgeColor: const Color(0xFFE0F7F6),
                  badgeTextColor: const Color(0xFF00796B),
                  icon: Icons.volunteer_activism_rounded,
                  description:
                      'Berperan sebagai teman curhat & pendengar aktif untuk kasus non-kritis. Tanpa syarat STR, tanpa SOAP medis, dan sukarela tanpa koin.',
                ),
                const SizedBox(height: 10),
                _buildCategoryOption(
                  role: CounselorRole.professionalIndependent,
                  title: 'Relawan Profesional Mandiri (Non-Mitra)',
                  badge: 'Klinis Mandiri • Sistem Koin',
                  badgeColor: AppColors.primaryContainer,
                  badgeTextColor: AppColors.primary,
                  icon: Icons.psychology_rounded,
                  description:
                      'Praktik klinis mandiri untuk menangani kasus komprehensif. Wajib STR. Anda bebas menentukan durasi sesi & tarif koin untuk di-redeem ke Rupiah.',
                ),
                const SizedBox(height: 12),

                // INFO UNTUK PSIKOLOG MITRA (SINGKAT & ELEGAN)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Anda psikolog mitra? Daftarkan instansi/mitra Anda melalui Web Portal Mitra (eva.id/mitra) untuk aktivasi akun.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // DYNAMIC NOTICE CALLOUT
                _buildRoleNoticeBanner(),
                const SizedBox(height: 20),

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
                        label: _selectedRole == CounselorRole.peerVolunteer
                            ? 'Nama Lengkap Panggilan'
                            : 'Nama Lengkap (Sesuai Ijazah)',
                        hint: _selectedRole == CounselorRole.peerVolunteer
                            ? 'cth: Sarah Anindya'
                            : 'cth: Sarah Anindya (tanpa gelar)',
                        controller: _fullNameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                      if (_selectedRole != CounselorRole.peerVolunteer) ...[
                        const SizedBox(height: 14),
                        CustomTextField(
                          label: 'Gelar Akademik & Profesi',
                          hint: 'cth: M.Psi., Psikolog Klinis',
                          controller: _degreeCtrl,
                          prefixIcon: Icons.school_outlined,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Gelar wajib diisi' : null,
                        ),
                      ],
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Email Akun Konselor',
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

                // SECTION 2: KREDENSIAL PROFESIONAL / RELAWAN
                if (_selectedRole == CounselorRole.peerVolunteer) ...[
                  const Text(
                    'Profil Teman Sebaya & Minat',
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
                          label: 'Komunitas / Asal Kampus / Organisasi',
                          hint: 'cth: BEM Psikologi / Relawan Sebaya',
                          controller: _volunteerCommunityCtrl,
                          prefixIcon: Icons.groups_outlined,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Kredensial Profesional Klinis',
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
                          label: 'Nomor STR / SIPP Aktif',
                          hint: 'cth: STR-PK-198827364-2026',
                          controller: _strCtrl,
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Nomor STR wajib diisi' : null,
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
                ],
                const SizedBox(height: 20),

                // SECTION 3: PENGATURAN SESI & KOIN (Hanya untuk Profesional Mandiri)
                if (_selectedRole == CounselorRole.professionalIndependent) ...[
                  const Text(
                    'Pengaturan Sesi & Sistem Koin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tentukan durasi dan tarif koin per sesi. Koin dapat Anda redeem menjadi Rupiah ke rekening bank.',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Durasi Standar 1 Sesi Telekonsultasi:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [30, 45, 50, 60].map((mins) {
                            final isSel = _sessionDurationMinutes == mins;
                            return ChoiceChip(
                              label: Text('$mins Menit'),
                              selected: isSel,
                              backgroundColor: Colors.white,
                              selectedColor: AppColors.primaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSel
                                      ? AppColors.primary.withValues(alpha: 0.35)
                                      : const Color(0xFFECEFF8),
                                  width: 1.0,
                                ),
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (_) {
                                setState(() => _sessionDurationMinutes = mins);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Tarif Koin per Sesi Konsultasi',
                          hint: '150',
                          controller: _coinsPerSessionCtrl,
                          prefixIcon: Icons.monetization_on_rounded,
                          keyboardType: TextInputType.number,
                          helperText: '1 Koin = Rp 1.000 (150 Koin ≈ Rp 150.000)',
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 10) return 'Minimal 10 koin';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // SECTION 4: BIDANG FOKUS / TOPIK
                const Text(
                  'Fokus Topik / Minat Pendampingan',
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

                // SECTION 5: UNGGAH DOKUMEN STR (Hanya untuk Profesional)
                if (_selectedRole != CounselorRole.peerVolunteer) ...[
                  const Text(
                    'Unggah Berkas Legalitas (STR / SIPP)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Format PDF, JPG, atau PNG untuk diverifikasi tim etik EVA.',
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
                ] else ...[
                  const SizedBox(height: 10),
                ],

                // CTA SUBMIT BUTTON
                CustomButton(
                  label: _selectedRole == CounselorRole.peerVolunteer
                      ? 'Daftar Sebagai Relawan Sebaya'
                      : 'Kirim Pendaftaran & Berkas',
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

  Widget _buildCategoryOption({
    required CounselorRole role,
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
    required String description,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFECEFF8),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer
                    : const Color(0xFFF4F6FC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textLight,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleNoticeBanner() {
    switch (_selectedRole) {
      case CounselorRole.peerVolunteer:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB2DFDB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF00796B), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sebagai Relawan Teman Sebaya, Anda tidak memerlukan STR dan tidak mengisi catatan rekam medis SOAP. Sesi curhat murni bersifat sukarela tanpa sistem koin. Kasus krisis berisiko tinggi otomatis dialihkan ke Profesional.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF004D40),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      case CounselorRole.professionalIndependent:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Praktik mandiri: Slot jadwal yang dibuka langsung otomatis terkonfirmasi saat pasien booking. Koin sesi diterima setelah video call dan SOAP note klinis selesai diisi. Koin dapat di-redeem ke Rupiah kapan saja.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      case CounselorRole.professionalPartner:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8B4FE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF7E22CE), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sebagai Psikolog Mitra, jadwal dan alokasi koin dikelola terpusat oleh Mitra melalui Web Portal Mitra. Koin sesi masuk ke kas lembaga mitra Anda.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF581C87),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/google_drive_service.dart';
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
  final _confirmPasswordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _sipCtrl = TextEditingController();
  final _associationCtrl =
      TextEditingController(text: 'Himpunan Psikologi Indonesia (HIMPSI)');

  // Durasi paten platform
  static const int _sessionDurationMinutes = 30;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Multi-document uploads
  final List<String> _uploadedFiles = [
    'Scan_STR_KTKI_2026.pdf',
  ];

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
    _confirmPasswordCtrl.dispose();
    _strCtrl.dispose();
    _sipCtrl.dispose();
    _associationCtrl.dispose();
    super.dispose();
  }

  void _handleGooglePrefill() async {
    setState(() => _isLoading = true);
    try {
      final driveService = ref.read(googleDriveServiceProvider);
      final account = await driveService.signInWithGoogle();
      if (account != null) {
        setState(() {
          _emailCtrl.text = account.email;
          if (account.displayName != null && account.displayName!.isNotEmpty) {
            _fullNameCtrl.text = account.displayName!;
          }
        });
        if (!mounted) return;
        TopToast.show(
          context,
          title: 'Akun Google Terhubung ✨',
          message:
              'Email & nama otomatis terisi dari Google (${account.email}). Notifikasi verifikasi akan dikirimkan ke email ini.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          title: 'Gagal Menghubungkan Google',
          message: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAddDocument(String docName) {
    if (_uploadedFiles.contains(docName)) {
      TopToast.show(
        context,
        title: 'Berkas Sudah Ada',
        message: 'Dokumen $docName sudah ada dalam daftar berkas.',
        type: ToastType.info,
      );
      return;
    }
    setState(() {
      _uploadedFiles.add(docName);
    });
    TopToast.show(
      context,
      title: 'Berkas Ditambahkan 📄',
      message: '$docName berhasil dilampirkan.',
      type: ToastType.success,
    );
  }

  void _showDocumentPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Pilih Jenis Dokumen Legalitas Tambahan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lampirkan dokumen pendukung untuk kelengkapan verifikasi:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildDocOption(
                icon: Icons.badge_outlined,
                title: 'Scan STR Aktif KTKI',
                subtitle: 'Surat Tanda Registrasi Tenaga Psikologi Klinis',
                docName: 'Scan_STR_KTKI_${DateTime.now().year}.pdf',
              ),
              _buildDocOption(
                icon: Icons.assignment_outlined,
                title: 'Scan SIPP / Surat Izin Praktik',
                subtitle: 'Izin praktik psikologi klinis Dinkes/DPMPTSP',
                docName: 'Scan_SIPP_Praktik_${DateTime.now().year}.pdf',
              ),
              _buildDocOption(
                icon: Icons.card_membership_rounded,
                title: 'Scan Kartu Anggota HIMPSI',
                subtitle: 'KTA Himpunan Psikologi Indonesia',
                docName: 'Scan_KTA_HIMPSI.pdf',
              ),
              _buildDocOption(
                icon: Icons.school_outlined,
                title: 'Scan Ijazah S2 Profesi Psikologi',
                subtitle: 'Ijazah Magister Psikologi Profesi',
                docName: 'Scan_Ijazah_S2_Profesi.pdf',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String docName,
  }) {
    final alreadyAdded = _uploadedFiles.contains(docName);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: alreadyAdded
              ? const Color(0xFFE8F5E9)
              : AppColors.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          alreadyAdded ? Icons.check_circle_rounded : icon,
          color: alreadyAdded ? AppColors.verifiedGreen : AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: alreadyAdded ? AppColors.verifiedGreen : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: alreadyAdded
          ? const Text(
              'Terlampir',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.verifiedGreen,
                fontWeight: FontWeight.bold,
              ),
            )
          : const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
              size: 20,
            ),
      onTap: () {
        Navigator.pop(context);
        _handleAddDocument(docName);
      },
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uploadedFiles.isEmpty) {
      TopToast.show(
        context,
        title: 'Dokumen Legalitas Belum Dilampirkan',
        message: 'Mohon lampirkan minimal 1 berkas STR/SIPP untuk verifikasi.',
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
          certificateDocFileName: _uploadedFiles.join(', '),
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

                // FAST GOOGLE PREFILL BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    ),
                    icon: Image.network(
                      'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    label: const Text(
                      'Daftar Cepat dengan Akun Google',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleGooglePrefill,
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'atau lengkapi formulir pendaftaran',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  ],
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
                        label: 'Email Akun / Google Aktif',
                        hint: 'nama@gmail.com',
                        helperText:
                            'Penting: Notifikasi hasil verifikasi legalitas resmi akan dikirimkan ke email ini.',
                        controller: _emailCtrl,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Kata Sandi (Min. 8 Karakter)',
                        hint: '••••••••',
                        controller: _passwordCtrl,
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
                        validator: (v) =>
                            (v?.length ?? 0) < 8 ? 'Minimal 8 karakter' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Konfirmasi Kata Sandi',
                        hint: '••••••••',
                        controller: _confirmPasswordCtrl,
                        obscureText: !_isConfirmPasswordVisible,
                        prefixIcon: Icons.lock_clock_outlined,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: _isConfirmPasswordVisible
                                ? AppColors.primary
                                : AppColors.textLight,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                          splashRadius: 20,
                          tooltip: _isConfirmPasswordVisible
                              ? 'Sembunyikan Kata Sandi'
                              : 'Tampilkan Kata Sandi',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Konfirmasi kata sandi wajib diisi';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Konfirmasi kata sandi tidak cocok';
                          }
                          return null;
                        },
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

                // SECTION 5: UNGGAH SCAN STR/SIPP (MULTI-FILE)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dokumen Legalitas Profesi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_uploadedFiles.length} Berkas Dilampirkan',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bisa melampirkan lebih dari 1 dokumen (Scan STR, SIPP, KTA HIMPSI, atau Ijazah) dalam format PDF/JPG (Maks. 5 MB).',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),

                // DAFTAR BERKAS TERLAMPIR
                if (_uploadedFiles.isNotEmpty) ...[
                  ..._uploadedFiles.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final fileName = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: AppColors.verifiedGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Siap diverifikasi • Terenkripsi',
                                  style: TextStyle(fontSize: 10, color: AppColors.verifiedGreen),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
                            onPressed: () {
                              setState(() {
                                _uploadedFiles.removeAt(idx);
                              });
                            },
                            tooltip: 'Hapus Berkas',
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                ],

                // BUTTON TAMBAH DOKUMEN LAINNYA
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                    label: const Text(
                      'Tambah Berkas Dokumen Legalitas +',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: _showDocumentPickerModal,
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

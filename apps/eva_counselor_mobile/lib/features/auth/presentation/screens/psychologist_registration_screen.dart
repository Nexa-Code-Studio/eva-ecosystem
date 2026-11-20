import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/storage/schedule_storage.dart';
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
  final _degreeCtrl = TextEditingController(text: 'M.Psi., Psikolog');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _sipCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController(text: 'Kemenkes RI / KTKI');
  final _expiryCtrl = TextEditingController(text: 'Seumur Hidup (UU Kesehatan No. 17/2023)');
  final _associationCtrl = TextEditingController(text: 'HIMPSI');

  // Dokumen Legalitas: 'both', 'str', 'sip'
  String _documentType = 'both';

  // Pendidikan Terakhir
  final List<String> _educationLevels = [
    'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    'S2 Magister Psikologi Terapan',
    'S1 Sarjana Psikologi',
    'S3 Doktor Psikologi',
  ];
  late String _selectedEducation;

  // Pengalaman Klinis
  final List<Map<String, dynamic>> _experienceOptions = [
    {'label': '1 - 2 Thn', 'value': 2},
    {'label': '3 - 5 Thn', 'value': 3},
    {'label': '6 - 10 Thn', 'value': 7},
    {'label': '> 10 Thn', 'value': 10},
  ];
  int _selectedExperienceYears = 3;

  // Masa Berlaku Toggle
  bool _isLifetimeExpiry = true;
  DateTime _customExpiryDate = DateTime.now().add(const Duration(days: 365 * 5));

  // Instansi Penerbit Preset
  final List<String> _commonInstitutions = [
    'Kemenkes RI / KTKI',
    'Dinas Kesehatan Kab/Kota',
    'HIMPSI (Himpunan Psikologi)',
    'Kementerian Kesehatan RI',
  ];

  // Durasi paten platform
  static const int _sessionDurationMinutes = 30;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Multi-document uploads
  final List<String> _uploadedFiles = [];

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
  void initState() {
    super.initState();
    _selectedEducation = _educationLevels[0];
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _degreeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _strCtrl.dispose();
    _sipCtrl.dispose();
    _institutionCtrl.dispose();
    _expiryCtrl.dispose();
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

  Future<void> _handlePickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customExpiryDate.isBefore(now) ? now : _customExpiryDate,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customExpiryDate = picked;
        _isLifetimeExpiry = false;
        final d = picked.day.toString().padLeft(2, '0');
        final m = picked.month.toString().padLeft(2, '0');
        _expiryCtrl.text = '$d/$m/${picked.year}';
      });
    }
  }

  void _handlePickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (files.isNotEmpty) {
        int addedCount = 0;
        setState(() {
          for (final f in files) {
            if (!_uploadedFiles.contains(f.name)) {
              _uploadedFiles.add(f.name);
              addedCount++;
            }
          }
        });
        if (!mounted) return;
        if (addedCount > 0) {
          TopToast.show(
            context,
            title: 'Berkas Ditambahkan 📄',
            message: '$addedCount berkas berhasil dilampirkan dari perangkat.',
            type: ToastType.success,
          );
        } else {
          TopToast.show(
            context,
            title: 'Berkas Sudah Ada',
            message: 'Berkas yang dipilih sudah ada dalam daftar lampiran.',
            type: ToastType.info,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memilih Berkas',
        message: 'Tidak dapat mengakses berkas: $e',
        type: ToastType.error,
      );
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi Nomor Dokumen sesuai pilihan
    if (_documentType == 'str' || _documentType == 'both') {
      if (_strCtrl.text.trim().isEmpty) {
        TopToast.show(
          context,
          title: 'Nomor STR Wajib Diisi',
          message: 'Mohon masukkan nomor STR aktif Anda.',
          type: ToastType.error,
        );
        return;
      }
    }

    if (_documentType == 'sip' || _documentType == 'both') {
      if (_sipCtrl.text.trim().isEmpty) {
        TopToast.show(
          context,
          title: 'Nomor SIP / SIPP Wajib Diisi',
          message: 'Mohon masukkan nomor SIP / SIPP aktif Anda.',
          type: ToastType.error,
        );
        return;
      }
    }

    if (_selectedSpecializations.isEmpty) {
      TopToast.show(
        context,
        title: 'Spesialisasi Belum Dipilih',
        message: 'Mohon pilih minimal 1 bidang fokus / spesialisasi praktik Anda.',
        type: ToastType.error,
      );
      return;
    }

    if (_uploadedFiles.isEmpty) {
      final docLabel = _documentType == 'both'
          ? 'STR / SIP'
          : (_documentType == 'str' ? 'STR' : 'SIP');
      TopToast.show(
        context,
        title: 'Dokumen Legalitas Belum Dilampirkan',
        message: 'Mohon lampirkan minimal 1 berkas scan $docLabel untuk verifikasi.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    await ScheduleStorage.resetForNewRegistration();

    final strVal = _documentType == 'sip' ? '' : _strCtrl.text.trim();
    final sipVal = _documentType == 'str' ? null : _sipCtrl.text.trim();

    await ref.read(authStateProvider.notifier).register(
          fullName: _fullNameCtrl.text.trim(),
          titleDegree: _degreeCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          strNumber: strVal,
          sipNumber: sipVal,
          documentType: _documentType,
          issuingInstitution: _institutionCtrl.text.trim(),
          documentExpiryDate: _expiryCtrl.text.trim(),
          lastEducation: _selectedEducation,
          association: _associationCtrl.text.trim(),
          specializations: _selectedSpecializations.toList(),
          yearsOfExperience: _selectedExperienceYears,
          consultationRate: 150000,
          certificateDocFileName: _uploadedFiles.join(', '),
          counselorRole: 'professional_independent',
          partnerName: null,
          sessionDurationMinutes: _sessionDurationMinutes,
          coinsPerSession: 150,
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
              'Pendaftaran akun Psikolog Mandiri dan dokumen kredensial Anda telah berhasil diunggah. Akun Anda akan ditinjau oleh tim kredensial Eva dalam 1x24 jam kerja.',
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

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          child,
        ],
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
                          size: 26,
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
                            SizedBox(height: 3),
                            Text(
                              'Daftar dengan STR, SIP, atau keduanya untuk membuka praktik telekonseling mandiri di Eva.',
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
                const SizedBox(height: 14),

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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    icon: Image.network(
                      'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                      width: 18,
                      height: 18,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    label: const Text(
                      'Daftar Cepat dengan Akun Google',
                      style: TextStyle(
                        fontSize: 12.5,
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

                // SEKSI 1: DATA AKUN & IDENTITAS PRIBADI
                _buildSectionCard(
                  title: 'Data Akun & Identitas',
                  subtitle: 'Informasi dasar akun dan profil praktisi',
                  icon: Icons.person_outline_rounded,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Nama Lengkap (Sesuai KTP / Ijazah)',
                        hint: 'cth: Dimas Wicaksono',
                        controller: _fullNameCtrl,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nama lengkap wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Gelar Akademik & Profesi',
                        hint: 'cth: M.Psi., Psikolog Klinis',
                        controller: _degreeCtrl,
                        prefixIcon: Icons.school_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Gelar profesi wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Email Akun / Google Aktif',
                        hint: 'nama@gmail.com',
                        helperText:
                            'Notifikasi hasil verifikasi legalitas resmi akan dikirimkan ke email ini.',
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

                // SEKSI 2: PENDIDIKAN & PENGALAMAN KLINIS (BARU)
                _buildSectionCard(
                  title: 'Pendidikan & Pengalaman Klinis',
                  subtitle: 'Kualifikasi akademik dan rekam jejak praktik',
                  icon: Icons.history_edu_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown Pendidikan Terakhir
                      const Text(
                        'Pendidikan Terakhir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedEducation,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            items: _educationLevels.map((edu) {
                              return DropdownMenuItem<String>(
                                value: edu,
                                child: Text(
                                  edu,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedEducation = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pilihan Pengalaman Klinis
                      const Text(
                        'Pengalaman Praktik Klinis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _experienceOptions.map((opt) {
                          final isSelected = _selectedExperienceYears == opt['value'];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => setState(() => _selectedExperienceYears = opt['value'] as int),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryContainer : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      opt['label'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Organisasi Profesi
                      CustomTextField(
                        label: 'Organisasi Profesi',
                        hint: 'cth: HIMPSI / IPK Indonesia',
                        controller: _associationCtrl,
                        prefixIcon: Icons.corporate_fare_outlined,
                      ),
                    ],
                  ),
                ),

                // SEKSI 3: DOKUMEN LEGALITAS PROFESI (FLEKSIBEL STR / SIP / KEDUANYA)
                _buildSectionCard(
                  title: 'Dokumen Legalitas Profesi',
                  subtitle: 'Pilih jenis dokumen izin praktik yang Anda miliki',
                  icon: Icons.verified_user_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Dokumen yang Ingin Digunakan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Segmented Pills untuk jenis dokumen: STR Saja, SIP Saja, Keduanya
                      Row(
                        children: [
                          _buildDocTypePill('both', 'Keduanya\n(STR & SIP)', Icons.library_books_outlined),
                          const SizedBox(width: 8),
                          _buildDocTypePill('str', 'STR Saja\n(Registrasi)', Icons.badge_outlined),
                          const SizedBox(width: 8),
                          _buildDocTypePill('sip', 'SIP Saja\n(Izin Praktik)', Icons.assignment_outlined),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input Nomor Registrasi sesuai pilihan
                      if (_documentType == 'str' || _documentType == 'both') ...[
                        CustomTextField(
                          label: 'Nomor STR (Surat Tanda Registrasi)',
                          hint: 'cth: STR-PK-198827364-2026',
                          controller: _strCtrl,
                          prefixIcon: Icons.badge_outlined,
                          validator: (v) {
                            if (_documentType == 'str' || _documentType == 'both') {
                              return (v == null || v.isEmpty) ? 'Nomor STR wajib diisi' : null;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (_documentType == 'sip' || _documentType == 'both') ...[
                        CustomTextField(
                          label: 'Nomor SIP / SIPP (Surat Izin Praktik)',
                          hint: 'cth: 503/SIP-PSI/DKS/2024',
                          controller: _sipCtrl,
                          prefixIcon: Icons.assignment_outlined,
                          validator: (v) {
                            if (_documentType == 'sip' || _documentType == 'both') {
                              return (v == null || v.isEmpty) ? 'Nomor SIP/SIPP wajib diisi' : null;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Instansi Penerbit
                      CustomTextField(
                        label: 'Instansi Penerbit Dokumen',
                        hint: 'cth: Kemenkes RI / KTKI / Dinas Kesehatan',
                        controller: _institutionCtrl,
                        prefixIcon: Icons.account_balance_outlined,
                        validator: (v) => v == null || v.isEmpty ? 'Instansi penerbit wajib diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _commonInstitutions.map((inst) {
                          return ActionChip(
                            label: Text(inst, style: const TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onPressed: () {
                              setState(() {
                                _institutionCtrl.text = inst;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Masa Berlaku Dokumen
                      const Text(
                        'Masa Berlaku Dokumen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isLifetimeExpiry = true;
                                  _expiryCtrl.text = 'Seumur Hidup (UU Kesehatan No. 17/2023)';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: _isLifetimeExpiry ? AppColors.primaryContainer : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isLifetimeExpiry ? AppColors.primary : const Color(0xFFE2E8F0),
                                    width: _isLifetimeExpiry ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 16,
                                      color: _isLifetimeExpiry ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Seumur Hidup',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _isLifetimeExpiry ? FontWeight.bold : FontWeight.w500,
                                        color: _isLifetimeExpiry ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: _handlePickExpiryDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: !_isLifetimeExpiry ? AppColors.primaryContainer : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !_isLifetimeExpiry ? AppColors.primary : const Color(0xFFE2E8F0),
                                    width: !_isLifetimeExpiry ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 16,
                                      color: !_isLifetimeExpiry ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      !_isLifetimeExpiry ? _expiryCtrl.text : 'Pilih Tanggal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: !_isLifetimeExpiry ? FontWeight.bold : FontWeight.w500,
                                        color: !_isLifetimeExpiry ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // UNGGAH BERKAS SCAN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _documentType == 'both'
                                ? 'Unggah Scan STR & SIP'
                                : (_documentType == 'str' ? 'Unggah Scan STR' : 'Unggah Scan SIP / SIPP'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                        'Format file didukung: PDF, JPG, PNG (Maks. 5 MB). Lampirkan scan asli agar proses verifikasi lebih cepat.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      if (_uploadedFiles.isEmpty) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _handlePickFiles,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _documentType == 'both'
                                      ? 'Pilih Berkas Scan STR & SIP dari Perangkat'
                                      : (_documentType == 'str'
                                          ? 'Pilih Berkas Scan STR dari Perangkat'
                                          : 'Pilih Berkas Scan SIP dari Perangkat'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Klik di sini untuk memilih berkas dari memori perangkat',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        ..._uploadedFiles.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final fileName = entry.value;
                          final isPdf = fileName.toLowerCase().endsWith('.pdf');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPdf ? const Color(0xFFE8F5E9) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                    size: 18,
                                    color: isPdf ? AppColors.verifiedGreen : AppColors.primary,
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                            label: const Text(
                              'Tambah Berkas dari Perangkat +',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            onPressed: _handlePickFiles,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // SEKSI 4: PEMINATAN KLINIS
                _buildSectionCard(
                  title: 'Fokus Peminatan Klinis',
                  subtitle: 'Pilih spesialisasi masalah yang biasa Anda tangani',
                  icon: Icons.psychology_outlined,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableSpecializations.map((spec) {
                      final isSelected = _selectedSpecializations.contains(spec);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(spec),
                        backgroundColor: const Color(0xFFF8FAFC),
                        selectedColor: AppColors.primaryContainer,
                        checkmarkColor: AppColors.primary,
                        showCheckmark: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : const Color(0xFFECEFF8),
                            width: 1.0,
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                ),

                // SEKSI 5: STANDAR SESI TELEKONSELING
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
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
                          Icon(Icons.timer_outlined, size: 18, color: AppColors.primary),
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
                        'Setiap slot telekonseling diatur paten 30 menit dengan buffer istirahat otomatis antar sesi sesuai jadwal buka Anda.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                      Divider(height: 18),
                      Row(
                        children: [
                          Icon(Icons.savings_outlined, size: 18, color: AppColors.primary),
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
                        'Tarif per sesi dan honorarium psikolog disalurkan transparan ke rekening bank Anda setelah sesi diverifikasi.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),

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

  Widget _buildDocTypePill(String typeKey, String label, IconData icon) {
    final isSelected = _documentType == typeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _documentType = typeKey;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

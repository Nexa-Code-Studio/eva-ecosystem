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
  final _degreeCtrl = TextEditingController(); // Kosong di awal, hanya placeholder
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _strCtrl = TextEditingController();
  final _sipCtrl = TextEditingController();
  final _customStrInstitutionCtrl = TextEditingController();
  final _customSipInstitutionCtrl = TextEditingController();
  final _customAssociationCtrl = TextEditingController();
  final _strExpiryCtrl = TextEditingController(text: 'Seumur Hidup (UU Kesehatan No. 17/2023)');
  final _sipExpiryCtrl = TextEditingController(text: '${DateTime.now().year + 5}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');

  // Dokumen Legalitas: 'both', 'str', 'sip'
  String _documentType = 'both';

  // Dropdown Pendidikan Terakhir (Kosong di awal)
  final List<String> _educationLevels = [
    'S2 Magister Psikologi Profesi (Psikolog Klinis)',
    'S2 Magister Psikologi Terapan',
    'S1 Sarjana Psikologi',
    'S3 Doktor Psikologi',
  ];
  String? _selectedEducation;

  // Dropdown Instansi Penerbit STR
  final List<String> _strInstitutionOptions = [
    'Kemenkes RI / KTKI (Konsil Tenaga Kesehatan Indonesia)',
    'KKI (Konsil Kedokteran Indonesia)',
    'Kementerian Kesehatan RI',
    'Instansi STR Lainnya (Ketik Manual)',
  ];
  String? _selectedStrInstitution;

  // Dropdown Instansi Penerbit SIP
  final List<String> _sipInstitutionOptions = [
    'Dinas Kesehatan Kabupaten / Kota',
    'DPMPTSP (Dinas Penanaman Modal & Pelayanan Terpadu Satu Pintu)',
    'Dinas Kesehatan Provinsi',
    'Instansi SIP Lainnya (Ketik Manual)',
  ];
  String? _selectedSipInstitution;

  // Dropdown Organisasi Profesi (Dropdown seperti Pendidikan)
  final List<String> _associationOptions = [
    'HIMPSI (Himpunan Psikologi Indonesia)',
    'IPK Indonesia (Ikatan Psikolog Klinis Indonesia)',
    'APPI (Asosiasi Psikologi Positif Indonesia)',
    'Organisasi Lainnya (Ketik Manual)',
  ];
  String? _selectedAssociation;

  // Pengalaman Klinis
  final List<Map<String, dynamic>> _experienceOptions = [
    {'label': '1 - 2 Thn', 'value': 2},
    {'label': '3 - 5 Thn', 'value': 3},
    {'label': '6 - 10 Thn', 'value': 7},
    {'label': '> 10 Thn', 'value': 10},
  ];
  int _selectedExperienceYears = 3;

  // Masa Berlaku STR
  bool _isStrLifetime = true;
  DateTime _customStrExpiryDate = DateTime.now().add(const Duration(days: 365 * 5));

  // Masa Berlaku SIP
  DateTime _customSipExpiryDate = DateTime.now().add(const Duration(days: 365 * 5));

  // Durasi paten platform
  static const int _sessionDurationMinutes = 30;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Berkas Dokumen Terpisah: STR & SIP
  String? _strFileName;
  String? _sipFileName;

  // Spesialisasi (Kosong di awal, tidak ada default terpilih)
  final List<String> _availableSpecializations = [
    'Kecemasan Dewasa',
    'Depresi & Suasana Hati',
    'Manajemen Stres & Burnout',
    'Konseling Remaja & Akademik',
    'Hubungan & Komunikasi',
    'Trauma & Regulasi Emosi',
    'Quarter-life Crisis',
  ];
  final Set<String> _selectedSpecializations = {};

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _degreeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _strCtrl.dispose();
    _sipCtrl.dispose();
    _customStrInstitutionCtrl.dispose();
    _customSipInstitutionCtrl.dispose();
    _customAssociationCtrl.dispose();
    _strExpiryCtrl.dispose();
    _sipExpiryCtrl.dispose();
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

  Future<void> _handlePickStrExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStrExpiryDate.isBefore(now) ? now : _customStrExpiryDate,
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
        _customStrExpiryDate = picked;
        _isStrLifetime = false;
        final d = picked.day.toString().padLeft(2, '0');
        final m = picked.month.toString().padLeft(2, '0');
        _strExpiryCtrl.text = '$d/$m/${picked.year}';
      });
    }
  }

  Future<void> _handlePickSipExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSipExpiryDate.isBefore(now) ? now : _customSipExpiryDate,
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
        _customSipExpiryDate = picked;
        final d = picked.day.toString().padLeft(2, '0');
        final m = picked.month.toString().padLeft(2, '0');
        _sipExpiryCtrl.text = '$d/$m/${picked.year}';
      });
    }
  }

  Future<void> _handlePickStrFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (files.isNotEmpty) {
        setState(() {
          _strFileName = files.first.name;
        });
        if (!mounted) return;
        TopToast.show(
          context,
          title: 'Berkas STR Terpilih 📄',
          message: '${files.first.name} berhasil dilampirkan.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memilih Berkas STR',
        message: 'Tidak dapat mengakses berkas: $e',
        type: ToastType.error,
      );
    }
  }

  Future<void> _handlePickSipFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (files.isNotEmpty) {
        setState(() {
          _sipFileName = files.first.name;
        });
        if (!mounted) return;
        TopToast.show(
          context,
          title: 'Berkas SIP Terpilih 📄',
          message: '${files.first.name} berhasil dilampirkan.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      TopToast.show(
        context,
        title: 'Gagal Memilih Berkas SIP',
        message: 'Tidak dapat mengakses berkas: $e',
        type: ToastType.error,
      );
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEducation == null) {
      TopToast.show(
        context,
        title: 'Pendidikan Terakhir Belum Dipilih',
        message: 'Mohon pilih jenjang pendidikan terakhir Anda.',
        type: ToastType.error,
      );
      return;
    }

    final effectiveAssociation = _selectedAssociation == 'Organisasi Lainnya (Ketik Manual)'
        ? _customAssociationCtrl.text.trim()
        : _selectedAssociation;

    if (effectiveAssociation == null || effectiveAssociation.isEmpty) {
      TopToast.show(
        context,
        title: 'Organisasi Profesi Belum Dipilih',
        message: 'Mohon tentukan organisasi profesi Anda.',
        type: ToastType.error,
      );
      return;
    }

    final hasStr = _documentType == 'str' || _documentType == 'both';
    final hasSip = _documentType == 'sip' || _documentType == 'both';

    String? effectiveStrInst;
    String? effectiveStrExp;
    if (hasStr) {
      if (_strCtrl.text.trim().isEmpty) {
        TopToast.show(
          context,
          title: 'Nomor STR Wajib Diisi',
          message: 'Mohon masukkan nomor STR aktif Anda.',
          type: ToastType.error,
        );
        return;
      }
      effectiveStrInst = _selectedStrInstitution == 'Instansi STR Lainnya (Ketik Manual)'
          ? _customStrInstitutionCtrl.text.trim()
          : _selectedStrInstitution;
      if (effectiveStrInst == null || effectiveStrInst.isEmpty) {
        TopToast.show(
          context,
          title: 'Instansi Penerbit STR Belum Dipilih',
          message: 'Mohon pilih instansi penerbit STR Anda.',
          type: ToastType.error,
        );
        return;
      }
      effectiveStrExp = _isStrLifetime ? 'Seumur Hidup (UU Kesehatan No. 17/2023)' : _strExpiryCtrl.text.trim();
      if (_strFileName == null) {
        TopToast.show(
          context,
          title: 'Berkas Scan STR Belum Diunggah',
          message: 'Mohon lampirkan scan asli dokumen STR Anda.',
          type: ToastType.error,
        );
        return;
      }
    }

    String? effectiveSipInst;
    String? effectiveSipExp;
    if (hasSip) {
      if (_sipCtrl.text.trim().isEmpty) {
        TopToast.show(
          context,
          title: 'Nomor SIP / SIPP Wajib Diisi',
          message: 'Mohon masukkan nomor SIP / SIPP aktif Anda.',
          type: ToastType.error,
        );
        return;
      }
      effectiveSipInst = _selectedSipInstitution == 'Instansi SIP Lainnya (Ketik Manual)'
          ? _customSipInstitutionCtrl.text.trim()
          : _selectedSipInstitution;
      if (effectiveSipInst == null || effectiveSipInst.isEmpty) {
        TopToast.show(
          context,
          title: 'Instansi Penerbit SIP Belum Dipilih',
          message: 'Mohon pilih instansi penerbit SIP Anda.',
          type: ToastType.error,
        );
        return;
      }
      effectiveSipExp = _sipExpiryCtrl.text.trim();
      if (effectiveSipExp.isEmpty) {
        TopToast.show(
          context,
          title: 'Masa Berlaku SIP Wajib Ditentukan',
          message: 'Mohon tentukan masa berlaku SIP Anda.',
          type: ToastType.error,
        );
        return;
      }
      if (_sipFileName == null) {
        TopToast.show(
          context,
          title: 'Berkas Scan SIP Belum Diunggah',
          message: 'Mohon lampirkan scan asli dokumen SIP / SIPP Anda.',
          type: ToastType.error,
        );
        return;
      }
    }

    if (_selectedSpecializations.isEmpty) {
      TopToast.show(
        context,
        title: 'Fokus Peminatan Belum Dipilih',
        message: 'Mohon pilih minimal 1 bidang fokus / peminatan klinis Anda.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    await ScheduleStorage.resetForNewRegistration();

    final strVal = hasStr ? _strCtrl.text.trim() : '';
    final sipVal = hasSip ? _sipCtrl.text.trim() : null;

    final uploadedList = <String>[];
    if (_strFileName != null && hasStr) {
      uploadedList.add('STR: $_strFileName');
    }
    if (_sipFileName != null && hasSip) {
      uploadedList.add('SIP: $_sipFileName');
    }

    await ref.read(authStateProvider.notifier).register(
          fullName: _fullNameCtrl.text.trim(),
          titleDegree: _degreeCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          strNumber: strVal,
          sipNumber: sipVal,
          documentType: _documentType,
          issuingInstitution: hasStr ? effectiveStrInst! : effectiveSipInst!,
          documentExpiryDate: hasStr ? effectiveStrExp! : effectiveSipExp!,
          lastEducation: _selectedEducation!,
          strIssuingInstitution: effectiveStrInst,
          strExpiryDate: effectiveStrExp,
          strDocFileName: _strFileName,
          sipIssuingInstitution: effectiveSipInst,
          sipExpiryDate: effectiveSipExp,
          sipDocFileName: _sipFileName,
          association: effectiveAssociation,
          specializations: _selectedSpecializations.toList(),
          yearsOfExperience: _selectedExperienceYears,
          consultationRate: 150000,
          certificateDocFileName: uploadedList.join(', '),
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

  Widget _buildDropdownCard<T>({
    required String label,
    required T? value,
    required String hintText,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hintText,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textLight),
              ),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadBox({
    required String title,
    required String subtitle,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final isAttached = fileName != null && fileName.isNotEmpty;
    final isPdf = isAttached && fileName.toLowerCase().endsWith('.pdf');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAttached ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: isAttached ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAttached ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAttached ? 'Terlampir ✓' : 'Belum Ada',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAttached ? AppColors.verifiedGreen : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (!isAttached) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPick,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Pilih Berkas Scan dari Perangkat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPdf ? const Color(0xFFE8F5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      size: 16,
                      color: isPdf ? AppColors.verifiedGreen : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                        const SizedBox(height: 1),
                        const Text(
                          'Terenkripsi • Siap Ditinjau',
                          style: TextStyle(fontSize: 10, color: AppColors.verifiedGreen),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Ganti Berkas',
                    onPressed: onPick,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textLight),
                    tooltip: 'Hapus Berkas',
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ],
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
                    icon: Image.asset(
                      'assets/images/google_logo.png',
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

                // SEKSI 2: PENDIDIKAN & PENGALAMAN KLINIS (DROPDOWN RAPI)
                _buildSectionCard(
                  title: 'Pendidikan & Pengalaman Klinis',
                  subtitle: 'Kualifikasi akademik dan rekam jejak praktik',
                  icon: Icons.history_edu_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown Pendidikan Terakhir
                      _buildDropdownCard<String>(
                        label: 'Pendidikan Terakhir',
                        value: _selectedEducation,
                        hintText: 'Pilih Pendidikan Terakhir',
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
                      const SizedBox(height: 16),

                      // Pilihan Pengalaman Klinis (Chips)
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

                      // Dropdown Organisasi Profesi
                      _buildDropdownCard<String>(
                        label: 'Organisasi Profesi',
                        value: _selectedAssociation,
                        hintText: 'Pilih Organisasi Profesi',
                        items: _associationOptions.map((assoc) {
                          return DropdownMenuItem<String>(
                            value: assoc,
                            child: Text(
                              assoc,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAssociation = val);
                        },
                      ),

                      if (_selectedAssociation == 'Organisasi Lainnya (Ketik Manual)') ...[
                        const SizedBox(height: 10),
                        CustomTextField(
                          label: 'Nama Organisasi Profesi Lainnya',
                          hint: 'cth: Ikatan Psikologi Klinis Cabang Surabaya',
                          controller: _customAssociationCtrl,
                          prefixIcon: Icons.corporate_fare_outlined,
                          validator: (v) =>
                              _selectedAssociation == 'Organisasi Lainnya (Ketik Manual)' &&
                                      (v == null || v.isEmpty)
                                  ? 'Nama organisasi profesi wajib diisi'
                                  : null,
                        ),
                      ],
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

                      // ================= STR SECTION =================
                      if (_documentType == 'str' || _documentType == 'both') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Dokumen STR (Surat Tanda Registrasi)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                label: 'Nomor STR',
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
                              const SizedBox(height: 12),
                              _buildDropdownCard<String>(
                                label: 'Instansi Penerbit STR',
                                value: _selectedStrInstitution,
                                hintText: 'Pilih Instansi Penerbit STR',
                                items: _strInstitutionOptions.map((inst) {
                                  return DropdownMenuItem<String>(
                                    value: inst,
                                    child: Text(inst, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStrInstitution = val);
                                },
                              ),
                              if (_selectedStrInstitution == 'Instansi STR Lainnya (Ketik Manual)') ...[
                                const SizedBox(height: 10),
                                CustomTextField(
                                  label: 'Nama Instansi Penerbit STR Lainnya',
                                  hint: 'cth: Konsil Tenaga Kesehatan Indonesia',
                                  controller: _customStrInstitutionCtrl,
                                  prefixIcon: Icons.account_balance_outlined,
                                  validator: (v) =>
                                      _selectedStrInstitution == 'Instansi STR Lainnya (Ketik Manual)' && (v == null || v.isEmpty)
                                          ? 'Nama instansi STR wajib diisi'
                                          : null,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Masa Berlaku STR',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isStrLifetime = true;
                                          _strExpiryCtrl.text = 'Seumur Hidup (UU Kesehatan No. 17/2023)';
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: _isStrLifetime ? AppColors.primaryContainer : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _isStrLifetime ? AppColors.primary : const Color(0xFFE2E8F0),
                                            width: _isStrLifetime ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.all_inclusive_rounded,
                                              size: 16,
                                              color: _isStrLifetime ? AppColors.primary : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Seumur Hidup',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: _isStrLifetime ? FontWeight.bold : FontWeight.w500,
                                                color: _isStrLifetime ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _handlePickStrExpiryDate,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: !_isStrLifetime ? AppColors.primaryContainer : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: !_isStrLifetime ? AppColors.primary : const Color(0xFFE2E8F0),
                                            width: !_isStrLifetime ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_month_outlined,
                                              size: 16,
                                              color: !_isStrLifetime ? AppColors.primary : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              !_isStrLifetime ? _strExpiryCtrl.text : 'Pilih Tanggal',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: !_isStrLifetime ? FontWeight.bold : FontWeight.w500,
                                                color: !_isStrLifetime ? AppColors.primary : AppColors.textPrimary,
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
                              const SizedBox(height: 12),
                              _buildUploadBox(
                                title: 'Scan Berkas STR Asli',
                                subtitle: 'Scan sertifikat kompetensi / STR resmi dari Kemenkes/KTKI',
                                fileName: _strFileName,
                                onPick: _handlePickStrFile,
                                onRemove: () => setState(() => _strFileName = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ================= SIP SECTION =================
                      if (_documentType == 'sip' || _documentType == 'both') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.assignment_outlined, color: Color(0xFF059669), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Dokumen SIP / SIPP (Surat Izin Praktik)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                label: 'Nomor SIP / SIPP',
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
                              const SizedBox(height: 12),
                              _buildDropdownCard<String>(
                                label: 'Instansi Penerbit SIP',
                                value: _selectedSipInstitution,
                                hintText: 'Pilih Instansi Penerbit SIP',
                                items: _sipInstitutionOptions.map((inst) {
                                  return DropdownMenuItem<String>(
                                    value: inst,
                                    child: Text(inst, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedSipInstitution = val);
                                },
                              ),
                              if (_selectedSipInstitution == 'Instansi SIP Lainnya (Ketik Manual)') ...[
                                const SizedBox(height: 10),
                                CustomTextField(
                                  label: 'Nama Instansi Penerbit SIP Lainnya',
                                  hint: 'cth: DPMPTSP Kabupaten Tangerang',
                                  controller: _customSipInstitutionCtrl,
                                  prefixIcon: Icons.account_balance_outlined,
                                  validator: (v) =>
                                      _selectedSipInstitution == 'Instansi SIP Lainnya (Ketik Manual)' && (v == null || v.isEmpty)
                                          ? 'Nama instansi SIP wajib diisi'
                                          : null,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Masa Berlaku SIP',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _handlePickSipExpiryDate,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF059669)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _sipExpiryCtrl.text.isNotEmpty ? 'Masa Berlaku s/d: ${_sipExpiryCtrl.text}' : 'Pilih Tanggal Masa Berlaku SIP',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildUploadBox(
                                title: 'Scan Berkas SIP / SIPP Asli',
                                subtitle: 'Scan surat izin praktik resmi dari Dinas Kesehatan / DPMPTSP',
                                fileName: _sipFileName,
                                onPick: _handlePickSipFile,
                                onRemove: () => setState(() => _sipFileName = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // SEKSI 4: PEMINATAN KLINIS (KOSONG DI AWAL, PILIH SENDIRI)
                _buildSectionCard(
                  title: 'Fokus Peminatan Klinis',
                  subtitle: 'Pilih spesialisasi masalah yang biasa Anda tangani (bisa lebih dari satu)',
                  icon: Icons.psychology_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedSpecializations.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedSpecializations.length} Spesialisasi Dipilih',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      Wrap(
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
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : const Color(0xFFECEFF8),
                                width: isSelected ? 1.4 : 1.0,
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
                    ],
                  ),
                ),

                // SEKSI 5: STANDAR SESI TELEKONSELING (DENGAN LINE WARNA ESTETIK)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Durasi Paten 30 Menit / Sesi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Termasuk buffer jeda istirahat otomatis antar sesi',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // LINE GARIS PEMISAH BERWARNA (SESUAI PERMINTAAN USER)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 14),
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.primary.withValues(alpha: 0.6),
                              const Color(0xFF10B981).withValues(alpha: 0.5),
                              const Color(0xFF10B981).withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.savings_outlined, size: 18, color: Color(0xFF059669)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tarif & Bagi Hasil Terkelola',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Honorarium otomatis masuk ke dompet & rekening bank Anda',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
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

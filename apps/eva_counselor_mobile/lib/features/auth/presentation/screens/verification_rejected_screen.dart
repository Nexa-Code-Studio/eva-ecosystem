import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/top_toast.dart';
import '../providers/auth_provider.dart';

class VerificationRejectedScreen extends ConsumerStatefulWidget {
  const VerificationRejectedScreen({super.key});

  @override
  ConsumerState<VerificationRejectedScreen> createState() =>
      _VerificationRejectedScreenState();
}

class _VerificationRejectedScreenState
    extends ConsumerState<VerificationRejectedScreen> {
  String? _newFileName;
  bool _isUploading = false;

  void _handlePickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (file != null) {
        setState(() {
          _newFileName = file.name;
        });
        if (!mounted) return;
        TopToast.show(
          context,
          title: 'Berkas Dipilih 📄',
          message: 'File berkas perbaikan siap diunggah: ${file.name}',
          type: ToastType.success,
        );
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

  void _handleSubmitRevision() async {
    if (_newFileName == null) {
      TopToast.show(
        context,
        title: 'Berkas Belum Dipilih',
        message: 'Mohon lampirkan scan STR/SIPP perbaikan sebelum mengirim.',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isUploading = true);
    await ref.read(authStateProvider.notifier).uploadCertificate(_newFileName!);
    if (!mounted) return;
    setState(() => _isUploading = false);

    TopToast.show(
      context,
      title: 'Dokumen Terkirim! 🚀',
      message: 'Berkas perbaikan Anda telah diteruskan ke tim kredensial.',
      type: ToastType.success,
    );
    Navigator.of(context).pushReplacementNamed('/counselor-verification-pending');
  }

  void _handleLogout() async {
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/counselor-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Header Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.gpp_bad_rounded,
                    size: 40,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Verifikasi Perlu Perbaikan',
                style: AppTypography.headingLarge.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Pengajuan kredensial Anda belum memenuhi syarat administrasi. Silakan periksa catatan peninjau dan unggah dokumen perbaikan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Feedback Note Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE4E6)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.feedback_outlined,
                            size: 16, color: Color(0xFFBE123C)),
                        SizedBox(width: 8),
                        Text(
                          'Catatan Verifikator Kredensial:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Scan dokumen STR/SIPP yang diunggah buram atau terpotong pada bagian masa berlaku. Pastikan scan e-STR resmi dari KTKI/HIMPSI terbaca dengan resolusi tinggi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF881337),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Upload New Document Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unggah Dokumen Perbaikan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nama: ${user?.fullName ?? "Psikolog"} • STR: ${user?.strNumber ?? "-"}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _handlePickFile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: _newFileName != null
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _newFileName != null
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _newFileName != null
                                  ? Icons.check_circle_rounded
                                  : Icons.upload_file_rounded,
                              size: 32,
                              color: _newFileName != null
                                  ? const Color(0xFF16A34A)
                                  : AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _newFileName ??
                                  'Pilih Dokumen Scan STR/SIPP Baru (PDF/JPG)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _newFileName != null
                                    ? const Color(0xFF15803D)
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Revision Button
              CustomButton(
                label: 'Kirim Dokumen Perbaikan',
                icon: Icons.send_rounded,
                isLoading: _isUploading,
                onPressed: _handleSubmitRevision,
              ),
              const SizedBox(height: 20),

              // Logout Link
              GestureDetector(
                onTap: _handleLogout,
                child: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

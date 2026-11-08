import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CounselorRoleUpgradeModal {
  static void show(BuildContext context, WidgetRef ref) {
    final strCtrl = TextEditingController();
    final assocCtrl = TextEditingController(text: 'HIMPSI');
    final partnerCtrl = TextEditingController();
    CounselorRole targetRole = CounselorRole.professionalIndependent;
    String? pickedFile;
    bool isUpgrading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isMandiri = targetRole == CounselorRole.professionalIndependent;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade ke Psikolog Profesional',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Daftarkan nomor STR/SIPP aktif untuk membuka dompet koin dan rekam SOAP klinis.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => targetRole = CounselorRole.professionalIndependent),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isMandiri ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isMandiri ? const Color(0xFFECEFF8) : Colors.transparent,
                                ),
                                boxShadow: isMandiri
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 15,
                                    color: isMandiri ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Praktik Mandiri',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isMandiri ? FontWeight.bold : FontWeight.w500,
                                      color: isMandiri ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => targetRole = CounselorRole.professionalPartner),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isMandiri ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isMandiri ? const Color(0xFFECEFF8) : Colors.transparent,
                                ),
                                boxShadow: !isMandiri
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.apartment_rounded,
                                    size: 15,
                                    color: !isMandiri ? const Color(0xFF7E22CE) : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dengan Mitra',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !isMandiri ? FontWeight.bold : FontWeight.w500,
                                      color: !isMandiri ? const Color(0xFF7E22CE) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isMandiri) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF7E22CE), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Akun psikolog mitra diatur jadwal dan tarif koinnya via Web Portal Mitra.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Nomor STR / SIPP Aktif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: TextField(
                      controller: strCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Misal: 4192-PSI-2024',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Organisasi Profesi Psikologi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECEFF8)),
                    ),
                    child: TextField(
                      controller: assocCtrl,
                      decoration: const InputDecoration(
                        hintText: 'HIMPSI / IPK Indonesia',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: Icon(Icons.account_balance_outlined, size: 18, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  if (!isMandiri) ...[
                    const SizedBox(height: 12),
                    const Text('Nama Lembaga / RS Mitra', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                      ),
                      child: TextField(
                        controller: partnerCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Misal: RS Jiwa Sanjiwani / PT Sehat Jiwa',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
                          prefixIcon: Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF7E22CE)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Unggah Berkas Bukti STR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        pickedFile = 'STR_Verified_${DateTime.now().year}.pdf';
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: pickedFile != null ? AppColors.verifiedBg : const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: pickedFile != null ? const Color(0xFFBBF7D0) : const Color(0xFFECEFF8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pickedFile != null ? const Color(0xFFDCFCE7) : AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              pickedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                              size: 18,
                              color: pickedFile != null ? AppColors.verifiedGreen : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickedFile ?? 'Pilih File Scan STR (PDF/JPG)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: pickedFile != null ? AppColors.verifiedGreen : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pickedFile != null ? 'Berkas siap diverifikasi (1.8 MB)' : 'Maksimal 5 MB • Kerahasiaan terenkripsi',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: 'Verifikasi & Upgrade Sekarang',
                    isLoading: isUpgrading,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () async {
                      if (strCtrl.text.isEmpty) {
                        TopToast.show(
                          context,
                          title: 'Nomor STR Wajib Diisi',
                          message: 'Mohon masukkan nomor STR/SIPP Anda.',
                          type: ToastType.error,
                        );
                        return;
                      }

                      setModalState(() => isUpgrading = true);
                      ref.read(authStateProvider.notifier).upgradeToProfessional(
                            strNumber: strCtrl.text,
                            association: assocCtrl.text,
                            certificateDocFileName: pickedFile ?? 'STR_Uploaded.pdf',
                            newRole: targetRole,
                            partnerName: targetRole == CounselorRole.professionalPartner
                                ? partnerCtrl.text
                                : null,
                          );

                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;

                      TopToast.show(
                        context,
                        title: 'Akun Berhasil Di-Upgrade!',
                        message:
                            'Selamat! Akun Anda kini aktif sebagai Psikolog Profesional dengan akses dompet koin.',
                        type: ToastType.success,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

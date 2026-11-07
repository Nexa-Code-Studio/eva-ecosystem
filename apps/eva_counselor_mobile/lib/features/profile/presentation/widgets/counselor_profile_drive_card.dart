import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import 'counselor_drive_backup_modal.dart';

class CounselorProfileDriveCard extends StatelessWidget {
  final PsychologistUserEntity? user;
  final String backupFrequency;
  final bool backupWifiOnly;
  final bool isBackingUp;
  final Function(String freq, bool wifi) onSettingsSaved;
  final VoidCallback onBackupNow;
  final VoidCallback onRestore;

  const CounselorProfileDriveCard({
    super.key,
    required this.user,
    required this.backupFrequency,
    required this.backupWifiOnly,
    required this.isBackingUp,
    required this.onSettingsSaved,
    required this.onBackupNow,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEFF8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: AppColors.verifiedGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.googleDriveEmail ?? 'sarah.anindya@gmail.com',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cadangan: ${user?.lastDriveBackup != null ? "Hari ini, 10:15 WIB (18.4 MB)" : "Belum dicadangkan"} • Otomatis $backupFrequency',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                onPressed: () => CounselorDriveBackupModal.show(
                  context: context,
                  user: user,
                  initialFrequency: backupFrequency,
                  initialWifiOnly: backupWifiOnly,
                  onSave: onSettingsSaved,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF0F2F8)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFECEFF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                  icon: const Icon(Icons.cloud_download_outlined, size: 16, color: AppColors.textPrimary),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Pulihkan Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                  onPressed: onRestore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                  icon: isBackingUp
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isBackingUp ? 'Mencadangkan...' : 'Cadangkan Sekarang',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onPressed: isBackingUp ? null : onBackupNow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

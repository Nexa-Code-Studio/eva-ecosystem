import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class CounselorNotificationScreen extends StatefulWidget {
  const CounselorNotificationScreen({super.key});

  @override
  State<CounselorNotificationScreen> createState() => _CounselorNotificationScreenState();
}

class _CounselorNotificationScreenState extends State<CounselorNotificationScreen> {
  String _selectedFilter = 'Semua';

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'notif-1',
      'title': 'Peringatan Distres Akut Pasien',
      'body': 'Dinda Kirana terdeteksi krisis skor 9/10 (DASS-21: 28). Protokol de-eskalasi & evaluasi riwayat klinis disarankan untuk segera ditinjau.',
      'category': 'Darurat',
      'time': '12 menit lalu',
      'isRead': false,
      'isCrisis': true,
      'patientId': 'patient-002',
      'actionLabel': 'Tinjau Pasien Segera',
    },
    {
      'id': 'notif-2',
      'title': 'Sesi Baru Terkonfirmasi Otomatis',
      'body': 'Maya Saraswati (22 th) memilih slot telekonseling Anda untuk besok Rabu, 12 Nov pukul 14:00 WIB (150 Koin). Jadwal langsung terkonfirmasi otomatis ke kalender.',
      'category': 'Jadwal',
      'time': '45 menit lalu',
      'isRead': false,
      'isConfirmedSession': true,
      'patientId': 'patient-004',
      'actionLabel': 'Lihat Jadwal & Pasien',
    },
    {
      'id': 'notif-3',
      'title': 'Pengingat: Sesi Dimulai 15 Menit Lagi',
      'body': 'Sesi telekonsultasi 1-on-1 dengan Rian Pratama akan dimulai pukul 10:00 WIB. Ruang video call terenkripsi telah siap.',
      'category': 'Jadwal',
      'time': '1 jam lalu',
      'isRead': false,
      'sessionId': 'session-live-001',
      'actionLabel': 'Masuk Ruang VC',
    },
    {
      'id': 'notif-4',
      'title': 'Koin Sesi Masuk ke Dompet 🪙',
      'body': '150 Koin berhasil ditambahkan ke saldo akun Anda setelah sesi telekonseling dan verifikasi catatan SOAP selesai.',
      'category': 'Keuangan',
      'time': '3 jam lalu',
      'isRead': false,
      'actionLabel': 'Lihat Saldo Koin',
    },
    {
      'id': 'notif-5',
      'title': 'Pencairan Dana Berhasil',
      'body': 'Pencairan 2.000 Koin (Rp 2.000.000) berhasil ditransfer ke rekening BCA Anda (No. Rek: ****8192).',
      'category': 'Keuangan',
      'time': '1 hari lalu',
      'isRead': true,
      'actionLabel': 'Lihat Mutasi',
    },
    {
      'id': 'notif-6',
      'title': 'Pencadangan Google Drive Selesai ☁️',
      'body': 'Rekam medis terenkripsi lokal berhasil dicadangkan ke Google Drive pribadi Anda secara end-to-end tanpa disimpan di server pusat.',
      'category': 'Sistem',
      'time': '1 hari lalu',
      'isRead': true,
      'actionLabel': 'Pengaturan Backup',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedFilter == 'Semua') return true;
      if (_selectedFilter == 'Darurat') return n['category'] == 'Darurat';
      if (_selectedFilter == 'Jadwal') return n['category'] == 'Jadwal';
      if (_selectedFilter == 'Keuangan') return n['category'] == 'Keuangan';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text('Notifikasi & Aktivitas', style: AppTypography.headingMedium),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Semua notifikasi ditandai sebagai dibaca.'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text(
              'Tandai Dibaca',
              style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Darurat', 'Jadwal', 'Keuangan'].map((cat) {
                    final isSel = _selectedFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Notifications List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = filtered[index];
                  final isCrisis = notif['isCrisis'] == true;
                  final isConfirmed = notif['isConfirmedSession'] == true;
                  final isRead = notif['isRead'] == true;
                  final category = notif['category'] as String;

                  Color catColor;
                  Color catBg;
                  IconData catIcon;

                  if (isCrisis) {
                    catColor = AppColors.highRiskRed;
                    catBg = AppColors.highRiskBg;
                    catIcon = Icons.crisis_alert_rounded;
                  } else if (isConfirmed) {
                    catColor = AppColors.verifiedGreen;
                    catBg = AppColors.verifiedBg;
                    catIcon = Icons.event_available_rounded;
                  } else if (category == 'Keuangan') {
                    catColor = const Color(0xFFD97706);
                    catBg = const Color(0xFFFEF3C7);
                    catIcon = Icons.monetization_on_rounded;
                  } else if (category == 'Sistem') {
                    catColor = const Color(0xFF7C3AED);
                    catBg = const Color(0xFFF3E8FF);
                    catIcon = Icons.cloud_done_rounded;
                  } else {
                    catColor = AppColors.primary;
                    catBg = AppColors.primaryContainer;
                    catIcon = Icons.notifications_active_rounded;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCrisis
                            ? AppColors.highRiskRed.withValues(alpha: 0.2)
                            : (isConfirmed
                                ? AppColors.verifiedGreen.withValues(alpha: 0.2)
                                : const Color(0xFFF0F2F8)),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isCrisis
                              ? AppColors.highRiskRed.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Icon + Category + Time + Unread indicator
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                catIcon,
                                size: 18,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: catColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${notif['time']}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    notif['title'] as String,
                                    style: AppTypography.headingSmall.copyWith(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Body
                        Text(
                          notif['body'] as String,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.textPrimary.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Actions
                        Row(
                          children: [
                            if (isConfirmed) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                                  label: Text(notif['actionLabel'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      '/counselor-patient-detail',
                                      arguments: notif['patientId'],
                                    );
                                  },
                                ),
                              ),
                            ] else if (isCrisis) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.highRiskRed,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.shield_outlined, size: 16),
                                  label: Text(notif['actionLabel'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      '/counselor-patient-detail',
                                      arguments: notif['patientId'],
                                    );
                                  },
                                ),
                              ),
                            ] else if (notif['sessionId'] != null) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.videocam_rounded, size: 16),
                                  label: Text(notif['actionLabel'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed(
                                      '/counselor-video-call',
                                      arguments: notif['sessionId'],
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              GestureDetector(
                                onTap: () {
                                  if (category == 'Keuangan') {
                                    Navigator.of(context).pushNamed('/counselor-finances');
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      notif['actionLabel'] as String,
                                      style: TextStyle(
                                        color: catColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, color: catColor, size: 14),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

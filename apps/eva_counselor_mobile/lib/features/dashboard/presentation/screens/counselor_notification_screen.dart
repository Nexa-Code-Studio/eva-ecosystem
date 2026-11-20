import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../profile/presentation/providers/privacy_settings_provider.dart';
import '../providers/counselor_notification_provider.dart';

class CounselorNotificationScreen extends ConsumerStatefulWidget {
  const CounselorNotificationScreen({super.key});

  @override
  ConsumerState<CounselorNotificationScreen> createState() =>
      _CounselorNotificationScreenState();
}

class _CounselorNotificationScreenState
    extends ConsumerState<CounselorNotificationScreen> {
  String _selectedFilter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(counselorNotificationsProvider);
    final privacy = ref.watch(privacySettingsProvider);

    final filtered = notifications.where((n) {
      if (_selectedFilter == 'Semua') return true;
      if (_selectedFilter == 'Darurat') return n.category == 'Darurat';
      if (_selectedFilter == 'Jadwal') return n.category == 'Jadwal';
      if (_selectedFilter == 'Keuangan') return n.category == 'Keuangan';
      if (_selectedFilter == 'Sistem') return n.category == 'Sistem';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title:
            Text('Notifikasi & Aktivitas', style: AppTypography.headingMedium),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(counselorNotificationsProvider.notifier)
                  .markAllAsRead();
              TopToast.show(
                context,
                title: 'Notifikasi Dibaca',
                message: 'Semua notifikasi ditandai sebagai dibaca.',
                type: ToastType.info,
              );
            },
            child: const Text(
              'Tandai Dibaca',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
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
                  children:
                      ['Semua', 'Sistem', 'Darurat', 'Jadwal', 'Keuangan']
                          .map((cat) {
                    final isSel = _selectedFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFilter = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                isSel ? AppColors.primary : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSel ? Colors.white : AppColors.textSecondary,
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
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer
                                    .withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 48,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak Ada Notifikasi',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pemberitahuan aktivitas sesi dan sistem akan tampil di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        final isCrisis = notif.isCrisis;
                        final isRead = notif.isRead;
                        final category = notif.category;

                        Color catColor;
                        Color catBg;
                        IconData catIcon;

                        if (isCrisis) {
                          catColor = AppColors.highRiskRed;
                          catBg = AppColors.highRiskBg;
                          catIcon = Icons.crisis_alert_rounded;
                        } else if (category == 'Keuangan') {
                          catColor = const Color(0xFFD97706);
                          catBg = const Color(0xFFFEF3C7);
                          catIcon = Icons.monetization_on_rounded;
                        } else if (category == 'Sistem') {
                          catColor = const Color(0xFF7C3AED);
                          catBg = const Color(0xFFF3E8FF);
                          catIcon = Icons.info_outline_rounded;
                        } else {
                          catColor = AppColors.primary;
                          catBg = AppColors.primaryContainer;
                          catIcon = Icons.notifications_active_rounded;
                        }

                        return GestureDetector(
                          onTap: () {
                            ref
                                .read(counselorNotificationsProvider.notifier)
                                .markAsRead(notif.id);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCrisis
                                    ? AppColors.highRiskRed.withValues(alpha: 0.2)
                                    : const Color(0xFFF0F2F8),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isCrisis
                                      ? AppColors.highRiskRed
                                          .withValues(alpha: 0.05)
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                '• ${notif.time}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textLight),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            privacy.maskText(notif.title),
                                            style: AppTypography.headingSmall
                                                .copyWith(
                                              fontSize: 14,
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.bold,
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
                                Text(
                                  privacy.maskText(notif.body),
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.85),
                                    height: 1.5,
                                  ),
                                ),
                                if (notif.actionLabel != null) ...[
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () {
                                      ref
                                          .read(counselorNotificationsProvider
                                              .notifier)
                                          .markAsRead(notif.id);
                                      if (notif.patientId != null) {
                                        Navigator.of(context).pushNamed(
                                          '/counselor-patient-detail',
                                          arguments: notif.patientId,
                                        );
                                      } else if (notif.sessionId != null) {
                                        Navigator.of(context).pushNamed(
                                          '/counselor-video-call',
                                          arguments: notif.sessionId,
                                        );
                                      } else if (category == 'Keuangan') {
                                        Navigator.of(context)
                                          ..pop()
                                          ..pushNamed('/counselor-finances');
                                      } else {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          notif.actionLabel!,
                                          style: TextStyle(
                                            color: catColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_rounded,
                                            color: catColor, size: 14),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounselorNotificationItem {
  final String id;
  final String title;
  final String body;
  final String category;
  final String time;
  final bool isRead;
  final String? actionLabel;
  final String? sessionId;
  final String? patientId;
  final bool isCrisis;

  const CounselorNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.time,
    this.isRead = false,
    this.actionLabel,
    this.sessionId,
    this.patientId,
    this.isCrisis = false,
  });

  CounselorNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? time,
    bool? isRead,
    String? actionLabel,
    String? sessionId,
    String? patientId,
    bool? isCrisis,
  }) {
    return CounselorNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel ?? this.actionLabel,
      sessionId: sessionId ?? this.sessionId,
      patientId: patientId ?? this.patientId,
      isCrisis: isCrisis ?? this.isCrisis,
    );
  }
}

class CounselorNotificationNotifier
    extends StateNotifier<List<CounselorNotificationItem>> {
  CounselorNotificationNotifier()
      : super([
          const CounselorNotificationItem(
            id: 'notif-welcome-01',
            title: 'Selamat Datang di Eva Konselor! 👋',
            body:
                'Akun Anda telah terdaftar. Silakan atur jadwal telekonseling dan lengkapi profil praktik Anda agar pasien dapat mulai menjadwalkan sesi.',
            category: 'Sistem',
            time: 'Baru saja',
            isRead: false,
            actionLabel: 'Atur Jadwal Praktik',
          ),
        ]);

  void markAllAsRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
  }

  void markAsRead(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
  }

  void addNotification(CounselorNotificationItem item) {
    state = [item, ...state];
  }

  void removeNotification(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final counselorNotificationsProvider = StateNotifierProvider<
    CounselorNotificationNotifier, List<CounselorNotificationItem>>((ref) {
  return CounselorNotificationNotifier();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(counselorNotificationsProvider);
  return notifs.where((n) => !n.isRead).length;
});

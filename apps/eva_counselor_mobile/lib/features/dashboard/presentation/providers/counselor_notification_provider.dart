import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _prefsKey = 'eva_counselor_read_notification_ids';

  static final List<CounselorNotificationItem> _initialNotifications = [
    const CounselorNotificationItem(
      id: 'notif-welcome-01',
      title: 'Selamat Datang di Eva Konselor! 👋',
      body:
          'Akun Anda telah terdaftar. Silakan atur jadwal telekonseling dan lengkapi profil praktik Anda agar pasien dapat mulai menjadwalkan sesi.',
      category: 'Sistem',
      time: 'Hari Ini, 09:15 WIB',
      isRead: false,
      actionLabel: 'Atur Jadwal Praktik',
    ),
    const CounselorNotificationItem(
      id: 'notif-earning-01',
      title: 'Honorarium Sesi Masuk 🪙',
      body:
          '+120 Koin berhasil dikreditkan ke dompet Anda dari sesi telekonsultasi #EVA-20261120-001.',
      category: 'Keuangan',
      time: 'Kemarin, 16:45 WIB',
      isRead: true,
    ),
    const CounselorNotificationItem(
      id: 'notif-system-01',
      title: 'Verifikasi Profil & STR Berhasil ✅',
      body:
          'Kredensial psikolog klinis Anda telah diverifikasi resmi oleh platform Eva.',
      category: 'Sistem',
      time: '18 Nov 2026',
      isRead: true,
    ),
  ];

  CounselorNotificationNotifier() : super(_initialNotifications) {
    _loadPersistedReadStatus();
  }

  Future<void> _loadPersistedReadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList(_prefsKey) ?? [];
      final isScheduleConfigured = prefs.getBool('eva_counselor_schedule_configured_persistent') ?? true;

      state = state.map((item) {
        if (item.id == 'notif-welcome-01' && (isScheduleConfigured || readIds.contains(item.id))) {
          return item.copyWith(isRead: true);
        }
        if (readIds.contains(item.id)) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();
    } catch (_) {}
  }

  Future<void> _persistReadIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, ids);
    } catch (_) {}
  }

  void markAllAsRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
    _persistReadIds(state.map((e) => e.id).toList());
  }

  void markAsRead(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
    final readIds = state.where((item) => item.isRead).map((e) => e.id).toList();
    _persistReadIds(readIds);
  }

  void addNotification(CounselorNotificationItem item) {
    state = [item, ...state];
  }

  void removeNotification(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearAll() {
    state = [];
    _persistReadIds([]);
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

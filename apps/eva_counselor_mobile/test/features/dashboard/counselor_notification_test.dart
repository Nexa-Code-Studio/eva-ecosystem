import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/providers/counselor_notification_provider.dart';

void main() {
  group('Counselor Notification Provider Tests', () {
    test('Initial state contains unread welcome notification for new counselors', () {
      final notifier = CounselorNotificationNotifier();
      final state = notifier.state;

      expect(state.isNotEmpty, true);
      expect(state.first.id, 'notif-welcome-01');
      expect(state.first.isRead, false);
      expect(state.where((n) => !n.isRead).length, 1);
    });

    test('markAllAsRead sets all notifications isRead to true', () {
      final notifier = CounselorNotificationNotifier();
      notifier.markAllAsRead();

      expect(notifier.state.every((n) => n.isRead), true);
      expect(notifier.state.where((n) => !n.isRead).length, 0);
    });

    test('markAsRead updates specific notification', () {
      final notifier = CounselorNotificationNotifier();
      notifier.markAsRead('notif-welcome-01');

      final item = notifier.state.firstWhere((n) => n.id == 'notif-welcome-01');
      expect(item.isRead, true);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_nemshi/models/app_notification.dart';
import 'package:yalla_nemshi/services/notification_storage.dart';

void main() {
  group('NotificationStorage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds and retrieves notifications', () async {
      final n1 = AppNotification(
        id: '1',
        type: NotificationType.walkJoined,
        title: 'Test',
        message: 'Msg',
        timestamp: DateTime(2025, 1, 1),
      );
      await NotificationStorage.addNotification(n1);

      final list = await NotificationStorage.getNotifications();
      expect(list.length, 1);
      expect(list.first.id, '1');
      expect(list.first.isRead, false);
    });

    test('markAllRead updates unread count', () async {
      final n1 = AppNotification(
        id: 'a',
        type: NotificationType.walkJoined,
        title: 'N1',
        message: 'M1',
        timestamp: DateTime.now(),
      );
      final n2 = AppNotification(
        id: 'b',
        type: NotificationType.dmMessage,
        title: 'N2',
        message: 'M2',
        timestamp: DateTime.now(),
      );
      await NotificationStorage.addNotification(n1);
      await NotificationStorage.addNotification(n2);

      expect(await NotificationStorage.getUnreadCount(), 2);
      await NotificationStorage.markAllRead();
      expect(await NotificationStorage.getUnreadCount(), 0);
    });
  });
}

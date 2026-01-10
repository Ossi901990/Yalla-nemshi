import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_nemshi/models/walk_event.dart';
import 'package:yalla_nemshi/services/notification_storage.dart';
import 'package:yalla_nemshi/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await NotificationStorage.clearNotifications();
    });

    test('scheduleWalkReminder respects walk reminders toggle', () async {
      // Enable reminders
      SharedPreferences.setMockInitialValues({
        'walk_reminders_enabled': true,
      });

      final event = WalkEvent(
        id: 'e1',
        firestoreId: 'f1',
        hostUid: 'u1',
        title: 'Morning Walk',
        dateTime: DateTime(2025, 1, 1, 8),
        distanceKm: 3.0,
        gender: 'Mixed',
      );

      await NotificationService.instance.scheduleWalkReminder(event);
      final list = await NotificationStorage.getNotifications();
      expect(list.length, 1);
      expect(list.first.title, 'Walk will start soon');

      // Disable reminders
      SharedPreferences.setMockInitialValues({
        'walk_reminders_enabled': false,
      });
      await NotificationStorage.clearNotifications();
      await NotificationService.instance.scheduleWalkReminder(event);
      final list2 = await NotificationStorage.getNotifications();
      expect(list2.length, 0);
    });

    test('showNearbyWalkAlert respects nearby alerts toggle', () async {
      // Enable nearby alerts
      SharedPreferences.setMockInitialValues({
        'nearby_alerts_enabled': true,
      });

      final event = WalkEvent(
        id: 'e2',
        firestoreId: 'f2',
        hostUid: 'u2',
        title: 'Park Walk',
        dateTime: DateTime(2025, 1, 1, 9),
        distanceKm: 2.0,
        gender: 'Mixed',
      );

      await NotificationService.instance.showNearbyWalkAlert(event);
      final list = await NotificationStorage.getNotifications();
      expect(list.length, 1);
      expect(list.first.title, 'New nearby walk');

      // Disable nearby alerts
      SharedPreferences.setMockInitialValues({
        'nearby_alerts_enabled': false,
      });
      await NotificationStorage.clearNotifications();
      await NotificationService.instance.showNearbyWalkAlert(event);
      final list2 = await NotificationStorage.getNotifications();
      expect(list2.length, 0);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../models/app_notification.dart';
import '../services/notification_storage.dart';

/// Provides the singleton NotificationService instance
final notificationServiceProvider = Provider((ref) {
  return NotificationService.instance;
});

/// Provides list of all notifications (async)
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  return NotificationStorage.getNotifications();
});

/// Provides count of unread notifications
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final notifs = await ref.watch(notificationsProvider.future);
  return notifs.where((n) => !n.isRead).length;
});

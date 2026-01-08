// lib/services/notification_service.dart
import '../models/app_notification.dart';
import '../models/walk_event.dart';
import 'notification_storage.dart';
import 'app_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // ✅ Add this so main.dart can call NotificationService.init()
  static Future<void> init() async {
    // For now: no-op (later you can wire Firebase/local notifications setup here)
  }

  Future<void> scheduleWalkReminder(WalkEvent event) async {
    // Respect setting toggle if you use it (walk reminders enabled)
    final enabled = await AppPreferences.getWalkRemindersEnabled();
    if (!enabled) return;

    final n = AppNotification(
      id: 'reminder_${event.firestoreId.isNotEmpty ? event.firestoreId : event.id}',
      title: 'Walk will start soon',
      message: 'Your walk "${event.title}" is coming up.',
      timestamp: DateTime.now(),
      isRead: false,
    );

    await NotificationStorage.addNotification(n);
  }

  /// Optional: remove/cancel reminder (for now we just do nothing safely).
  Future<void> cancelWalkReminder(WalkEvent event) async {
    // If later you implement removing by id, do it here.
    // For now, keeping it safe and no-op.
  }

  /// Adds a nearby-walk alert notification to local storage.
  Future<void> showNearbyWalkAlert(WalkEvent event) async {
    final enabled = await AppPreferences.getNearbyAlertsEnabled();
    if (!enabled) return;

    final n = AppNotification(
      id: 'nearby_${event.firestoreId.isNotEmpty ? event.firestoreId : event.id}',
      title: 'New nearby walk',
      message: '"${event.title}" is available nearby.',
      timestamp: DateTime.now(),
      isRead: false,
    );

    await NotificationStorage.addNotification(n);
  }
}

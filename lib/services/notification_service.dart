// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/walk_event.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Android init
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initializationSettings);

    // Timezone init
    tz.initializeTimeZones();

    _initialized = true;
  }

  int _eventNotificationId(String eventId) {
    // stable positive ID from the event id string
    return eventId.hashCode & 0x7fffffff;
  }

  /// DEBUG: show a notification immediately (no scheduling).
  Future<void> showTestNotification() async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test notifications',
        channelDescription: 'For debugging only',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      999, // some fixed ID for the debug notification
      'Test notification',
      'If you see this, local notifications are working 🎉',
      details,
    );
  }

  /// Schedule a reminder for a walk.
  /// Normal mode: ~1 hour before the walk.
  Future<void> scheduleWalkReminder(WalkEvent event) async {
    if (!_initialized) return;

    final now = DateTime.now();

    // Aim for 1 hour before the walk time
    DateTime scheduledTime = event.dateTime.subtract(const Duration(hours: 1));

    // If that's already in the past (event is <1h away or already started),
    // schedule it a few minutes from now instead.
    if (scheduledTime.isBefore(now)) {
      scheduledTime = now.add(const Duration(minutes: 5));
    }

    final id = _eventNotificationId(event.id);

    // Friendlier body depending on how close the event is
    final bool moreThanHourAway =
        event.dateTime.isAfter(now.add(const Duration(hours: 1)));
    final String body = moreThanHourAway
        ? '${event.title} starts in about 1 hour.'
        : '${event.title} is starting soon!';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'walk_reminders',
        'Walk reminders',
        channelDescription: 'Reminders before your walks start',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'Upcoming walk',
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
        // Use inexact alarms so we don't need SCHEDULE_EXACT_ALARM permission
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Notification schedule error: $e');
    }
  }


  /// Cancel the reminder for this event (if any).
  Future<void> cancelWalkReminder(WalkEvent event) async {
    if (!_initialized) return;
    final id = _eventNotificationId(event.id);
    await _plugin.cancel(id);
  }
}

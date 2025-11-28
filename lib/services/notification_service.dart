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

  /// Schedule a reminder ~1 hour before the walk starts.
  /// If the walk is in less than 1 hour, no reminder is scheduled.
  Future<void> scheduleWalkReminder(WalkEvent event) async {
    if (!_initialized) return;

    // ✅ REAL MODE: 1 hour before the event
    final scheduledTime = event.dateTime.subtract(const Duration(hours: 1));

    // If it's already in the past, don't schedule anything
    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    final id = _eventNotificationId(event.id);

    // Friendlier body depending on how close the event is
   final bool moreThanHourAway = event.dateTime
    .isAfter(DateTime.now().add(const Duration(hours: 1)));

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

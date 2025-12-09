// lib/services/notification_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

class NotificationStorage {
  static const _key = 'app_notifications';

  static Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null) return [];

    return raw
        .map((s) {
          try {
            final map = jsonDecode(s) as Map<String, dynamic>;
            return AppNotification.fromJson(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<AppNotification>()
        .toList();
  }

  static Future<void> _save(List<AppNotification> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> add(AppNotification notification) async {
    final list = await getNotifications();
    list.add(notification);
    await _save(list);
  }

  static Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Update one notification (used for read / unread)
  static Future<void> update(AppNotification updated) async {
    final list = await getNotifications();
    final index = list.indexWhere((n) => n.id == updated.id);
    if (index == -1) return;
    list[index] = updated;
    await _save(list);
  }
}

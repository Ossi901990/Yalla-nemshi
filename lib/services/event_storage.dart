// lib/services/event_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/walk_event.dart';

class EventStorage {
  static const _key = 'walk_events';

  static Future<void> saveEvents(List<WalkEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final list = events.map((e) => e.toMap()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<List<WalkEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];

    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) return [];

    return decoded
        .map<WalkEvent>((e) => WalkEvent.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

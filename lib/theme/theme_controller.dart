// lib/theme/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's appearance choice (Light / Dark / System), saved on the device.
///
/// Defaults to **light** while the redesign is in progress: screens that
/// haven't been redesigned yet were never checked in dark mode. Once every
/// screen supports both, change [_defaultMode] to [ThemeMode.system].
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'appearance_theme_mode';
  static const ThemeMode _defaultMode = ThemeMode.light;

  final ValueNotifier<ThemeMode> mode = ValueNotifier(_defaultMode);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = switch (prefs.getString(_key)) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => _defaultMode,
      };
    } catch (_) {
      // Keep the default if storage isn't available.
    }
  }

  Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {}
  }
}

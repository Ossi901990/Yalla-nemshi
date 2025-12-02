import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  // Holds the current theme mode
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  void setDarkMode(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

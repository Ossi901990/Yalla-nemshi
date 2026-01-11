import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../theme_controller.dart';

/// Provides the current ThemeMode (Light/Dark/System)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Simple notifier to wrap ThemeController's ValueListenable
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  late final VoidCallback _listener;

  ThemeModeNotifier() : super(ThemeController.instance.themeMode.value) {
    // Listen to theme controller changes
    _listener = () {
      state = ThemeController.instance.themeMode.value;
    };
    ThemeController.instance.themeMode.addListener(_listener);
  }

  void toggleTheme() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    ThemeController.instance.themeMode.value = newMode;
    state = newMode;
  }

  @override
  void dispose() {
    ThemeController.instance.themeMode.removeListener(_listener);
    super.dispose();
  }
}

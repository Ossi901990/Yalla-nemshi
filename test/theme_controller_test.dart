import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/theme_controller.dart';
import 'package:flutter/material.dart';

void main() {
  test('ThemeController toggles theme mode correctly', () {
    final controller = ThemeController.instance;
    expect(controller.themeMode.value, ThemeMode.light);

    controller.setDarkMode(true);
    expect(controller.themeMode.value, ThemeMode.dark);

    controller.setDarkMode(false);
    expect(controller.themeMode.value, ThemeMode.light);
  });
}

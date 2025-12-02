import 'package:flutter/material.dart';

import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Yalla Nemshi',
          debugShowCheckedModeBanner: false,
          themeMode: mode,          // 🔹 listens to your switch in Settings
          theme: _lightTheme,       // 🔹 light theme
          darkTheme: _darkTheme,    // 🔹 dark theme
          home: const HomeScreen(),
        );
      },
    );
  }
}

/// LIGHT THEME – close to what you already had
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF7F9F2),
  cardColor: const Color(0xFFFBFEF8),
);

/// DARK THEME – minimal, keeps green as accent
final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF050816),
  cardColor: const Color(0xFF111827),
);

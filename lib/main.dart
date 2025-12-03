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

/// LIGHT THEME  🌤️
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF4F925C),
    secondary: Color(0xFF294630),
    background: Color(0xFFF7F9F2),
    surface: Color(0xFFFBFEF8),
    onBackground: Colors.black,
    onSurface: Colors.black87,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFFF7F9F2),
  cardColor: const Color(0xFFFBFEF8),
);

/// DARK THEME  🌙
final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF4F925C),     // same green accent
    secondary: Color(0xFF294630),
    background: Color(0xFF050A08),  // main scaffold background
    surface: Color(0xFF0D1611),     // main sheet background
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Color(0xFFF7FCEA), // main readable text
    onSurface: Color(0xFFA9B9AE),    // secondary text
  ),
  scaffoldBackgroundColor: const Color(0xFF050A08),
  cardColor: const Color(0xFF151F18),
);


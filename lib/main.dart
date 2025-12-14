import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'package:flutter/foundation.dart';  

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 🔹 Web: use the firebaseConfig values you just saw
    await Firebase.initializeApp(
      options: const FirebaseOptions(
         apiKey: "AIzaSyBNZj_FBNB1L3V8UAVUScTrjpCWDc8lTT8",
  authDomain: "yallanemshiapp.firebaseapp.com",
  projectId: "yallanemshiapp",
  storageBucket: "yallanemshiapp.firebasestorage.app",
  messagingSenderId: "695876088604",
  appId: "1:695876088604:web:d7b5d37c1ff68131dcc0d9"
        // measurementId: "G-XXXXXXX", // <- only if your snippet shows this line
      ),
    );
  } else {
    // 🔹 Android (uses google-services.json)
    await Firebase.initializeApp();
  }

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
  themeMode: mode,        // still using your ThemeController
  theme: _lightTheme,
  darkTheme: _darkTheme,

  // ⬇️ NEW: start at the login screen
  initialRoute: LoginScreen.routeName,

  // ⬇️ NEW: define your routes
  routes: {
    LoginScreen.routeName: (context) => const LoginScreen(),
    SignupScreen.routeName: (context) => const SignupScreen(),
    '/home': (context) => const HomeScreen(),
  },
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
    surface: Color(0xFFFBFEF8),
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
    secondary: Color(0xFF294630),  // main scaffold background
    surface: Color(0xFF0D1611),     // main sheet background
    onPrimary: Colors.white,
    onSecondary: Colors.white, // main readable text
    onSurface: Color(0xFFA9B9AE),    // secondary text
  ),
  scaffoldBackgroundColor: const Color(0xFF050A08),
  cardColor: const Color(0xFF151F18),
);


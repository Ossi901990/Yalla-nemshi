import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';
import 'services/geocoding_service.dart';
import 'services/app_preferences.dart';
import 'services/crash_service.dart';
import 'services/profile_migration_service.dart';
import 'screens/home_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_screen.dart';
import 'theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/review_walk_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Load environment variables
  await dotenv.load(fileName: ".env");

  if (kIsWeb) {
    // 🔹 Web: use env variables
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? "",
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
        appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
      ),
    );
  } else {
    // 🔹 Android (uses google-services.json)
    await Firebase.initializeApp();
  }

  // 🔹 Initialize Firebase Crashlytics (not supported on web)
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Pass all uncaught exceptions to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Handle async errors outside Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await NotificationService.init();
  
  // 🔹 Migrate local profile to Firestore (background, non-blocking)
  ProfileMigrationService.migrateIfNeeded();
  
  // 🔹 Detect user's city on app startup (runs in background)
  _detectAndSaveUserCity();
  
  runApp(const ProviderScope(child: MyApp()));
}

/// Detects user's current location and saves their city to preferences.
/// Runs in the background without blocking app startup.
Future<void> _detectAndSaveUserCity() async {
  try {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return;
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Convert to city name
    final city = await GeocodingService.getCityFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (city != null && city.isNotEmpty) {
      await AppPreferences.setUserCity(city);
      debugPrint('✅ User city detected and saved: $city');
    } else {
      debugPrint('⚠️ Could not determine city from coordinates.');
    }
  } catch (e, stack) {
    // Log error to Crashlytics but don't block app
    CrashService.recordError(
      e,
      stack,
      reason: 'Failed to detect user city on app startup',
    );
    debugPrint('Error detecting user city: $e');
  }
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
          themeMode: mode, // still using your ThemeController
          theme: _lightTheme,
          darkTheme: _darkTheme,

          // ⬇️ NEW: start at the login screen
          initialRoute: LoginScreen.routeName,

          // ⬇️ NEW: define your routes
          routes: {
            LoginScreen.routeName: (context) => const LoginScreen(),
            ForgotPasswordScreen.routeName: (context) => const ForgotPasswordScreen(),
            ReviewWalkScreen.routeName: (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
              return ReviewWalkScreen(
                walk: args?['walk'],
                userId: args?['userId'],
                userName: args?['userName'],
              );
            },
            PrivacyPolicyScreen.routeName: (context) => const PrivacyPolicyScreen(),
            TermsScreen.routeName: (context) => const TermsScreen(),
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
  // ✅ Add text theme for accessibility text scaling
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    bodySmall: TextStyle(fontSize: 12),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  ),
);

/// DARK THEME  🌙
final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF4F925C), // same green accent
    secondary: Color(0xFF294630), // main scaffold background
    surface: Color(0xFF0D1611), // main sheet background
    onPrimary: Colors.white,
    onSecondary: Colors.white, // main readable text
    onSurface: Color(0xFFA9B9AE), // secondary text
  ),
  scaffoldBackgroundColor: const Color(0xFF050A08),
  cardColor: const Color(0xFF151F18),
  // ✅ Add text theme for accessibility text scaling
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    bodySmall: TextStyle(fontSize: 12),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  ),
);

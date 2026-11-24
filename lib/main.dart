import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/notification_service.dart';
import 'services/geocoding_service.dart';
import 'services/app_preferences.dart';
import 'services/crash_service.dart';
import 'services/profile_migration_service.dart';
import 'services/offline_service.dart';
import 'screens/home_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/review_walk_screen.dart';
import 'screens/walk_search_screen.dart';
import 'providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'screens/friend_list_screen.dart';
import 'screens/friend_search_screen.dart';
import 'screens/friend_profile_screen.dart';
import 'screens/dm_chat_screen.dart';
import 'screens/badge_leaderboard_screen.dart';
import 'screens/per_badge_leaderboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/notifications_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Background notification handler (must be top-level function)
/// This handles notifications when the app is terminated or in background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized (required for background handler)
  await Firebase.initializeApp();
  debugPrint('Background notification: ${message.notification?.title}');
  // Process notification data here if needed
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 APP STARTING');

  if (kIsWeb) {
    // 🔹 Web: Use hardcoded Firebase config
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAeeUDsBUghrf5gkD2NHZnd7UxSWzZ39u8",
        authDomain: "yalla-nemshi-app.firebaseapp.com",
        projectId: "yalla-nemshi-app",
        storageBucket: "yalla-nemshi-app.firebasestorage.app",
        messagingSenderId: "403871427941",
        appId: "1:403871427941:web:6a5e07328b4e5db5d9458c",
      ),
    );
  } else {
    // 🔹 Android/iOS (uses google-services.json)
    await Firebase.initializeApp();
  }

  // 🔹 Enable Firestore persistence and connectivity tracking (non-web)
  await OfflineService.instance.init();

  // 🔹 Appearance (Light / Dark / System), saved on the device
  await ThemeController.instance.load();

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

  // 🔹 Register background message handler (must be before init)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
      valueListenable: ThemeController.instance.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Yalla Nemshi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        navigatorKey: NotificationService.navigatorKey,
        home: const AuthStateRouter(),
        routes: {
          LoginScreen.routeName: (context) => const LoginScreen(),
          ForgotPasswordScreen.routeName: (context) =>
              const ForgotPasswordScreen(),
          ReviewWalkScreen.routeName: (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>?;
            return ReviewWalkScreen(
              walk: args?['walk'],
              userId: args?['userId'],
              userName: args?['userName'],
            );
          },
          PrivacyPolicyScreen.routeName: (context) =>
              const PrivacyPolicyScreen(),
          TermsScreen.routeName: (context) => const TermsScreen(),
          AnalyticsScreen.routeName: (context) => const AnalyticsScreen(),
          SignupScreen.routeName: (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/friends': (context) => FriendListScreen(),
          FriendSearchScreen.routeName: (context) => const FriendSearchScreen(),
          FriendProfileScreen.routeName: (context) =>
              const FriendProfileScreen(),
          WalkSearchScreen.routeName: (context) => const WalkSearchScreen(),
          DmChatScreen.routeName: (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments as DmChatScreenArgs;
            return DmChatScreen(args: args);
          },
          BadgeLeaderboardScreen.routeName: (context) =>
              const BadgeLeaderboardScreen(),
          PerBadgeLeaderboardScreen.routeName: (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>;
            return PerBadgeLeaderboardScreen(badgeData: args);
          },
          NotificationsScreen.routeName: (context) =>
              const NotificationsScreen(),
        },
      ),
    );
  }
}

/// Routes the user based on their authentication state
class AuthStateRouter extends ConsumerWidget {
  const AuthStateRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        // User is logged in, show home screen
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.handlePendingNavigation();
          });
          return const HomeScreen();
        }
        // User is not logged in, show login screen
        return const LoginScreen();
      },
      loading: () {
        // While checking auth state, show a loading screen
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      error: (error, stackTrace) {
        // Error checking auth state, show login screen as fallback
        debugPrint('Auth state error: $error');
        return const LoginScreen();
      },
    );
  }
}

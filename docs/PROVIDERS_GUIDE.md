# State Management with Riverpod Providers

This guide explains how to use the new provider-based state management in `yalla_nemshi`.

## Overview

Instead of directly calling services in screens, we now use **Riverpod providers** to manage state and dependencies. This makes code more testable, reusable, and reactive.

---

## Core Providers

### 1. **Auth Provider** (`lib/providers/auth_provider.dart`)

**Providers available:**
- `authProvider` — Stream of current Firebase user
- `isAuthenticatedProvider` — Boolean: is user signed in?
- `currentUserIdProvider` — Current user's UID
- `currentUserEmailProvider` — Current user's email

**Example usage in a screen:**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current user ID
    final userId = ref.watch(currentUserIdProvider);
    
    return Text(userId ?? 'Not signed in');
  }
}
```

### 2. **Theme Provider** (`lib/providers/theme_provider.dart`)

**Providers available:**
- `themeModeProvider` — Current ThemeMode (Light/Dark)

**Example usage:**

```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return Switch(
      value: themeMode == ThemeMode.dark,
      onChanged: (_) {
        ref.read(themeModeProvider.notifier).toggleTheme();
      },
    );
  }
}
```

### 3. **Preferences Provider** (`lib/providers/preferences_provider.dart`)

**Read-only providers:**
- `userCityProvider` — User's saved city
- `walkRemindersEnabledProvider` — Reminders toggle state
- `nearbyAlertsEnabledProvider` — Nearby alerts toggle state
- `weeklyGoalProvider` — Weekly goal in km

**Mutable providers:**
- `userCityNotifierProvider` — Update/set user city
- `walkRemindersNotifierProvider` — Toggle walk reminders

**Example usage (read):**

```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCity = ref.watch(userCityProvider);
    
    return userCity.when(
      data: (city) => Text('Your city: ${city ?? "Not set"}'),
      loading: () => const CircularProgressIndicator(),
      error: (err, st) => Text('Error: $err'),
    );
  }
}
```

**Example usage (write):**

```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        await ref.read(userCityNotifierProvider.notifier).setUserCity('Cairo');
      },
      child: const Text('Set City to Cairo'),
    );
  }
}
```

### 4. **Notification Provider** (`lib/providers/notification_provider.dart`)

**Providers available:**
- `notificationServiceProvider` — Singleton NotificationService
- `notificationsProvider` — List of all notifications
- `unreadNotificationsCountProvider` — Count of unread notifications

**Example usage:**

```dart
class NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    
    return unreadCount.when(
      data: (count) => Badge(
        label: Text('$count'),
        child: const Icon(Icons.notifications),
      ),
      loading: () => const Icon(Icons.notifications),
      error: (_, __) => const Icon(Icons.notifications),
    );
  }
}
```

---

## Migration Guide

### Before (Direct Service Calls)

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late String _userCity;
  
  @override
  void initState() {
    super.initState();
    _loadCity();
  }
  
  Future<void> _loadCity() async {
    final city = await AppPreferences.getUserCity();
    setState(() {
      _userCity = city ?? 'Not set';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(_userCity);
  }
}
```

### After (Riverpod Providers)

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCity = ref.watch(userCityProvider);
    
    return userCity.when(
      data: (city) => Text(city ?? 'Not set'),
      loading: () => const CircularProgressIndicator(),
      error: (err, st) => Text('Error: $err'),
    );
  }
}
```

**Benefits:**
- No `StatefulWidget` boilerplate
- Automatic caching & invalidation
- Built-in error/loading handling
- Automatic disposal

---

## Common Patterns

### 1. **Watching Multiple Providers**

```dart
class DashboardWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final userCity = ref.watch(userCityProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    
    return Column(
      children: [
        Text('User: $userId'),
        Text('City: $userCity'),
        Text('Unread: $unreadCount'),
      ],
    );
  }
}
```

### 2. **Invalidating Cache on Action**

```dart
class CreateWalkButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        // Create walk...
        await createWalk(/* ... */);
        
        // Refresh walks list
        ref.refresh(walksProvider);
      },
      child: const Text('Create Walk'),
    );
  }
}
```

### 3. **Combining Providers**

```dart
final userCityWithWalksProvider = FutureProvider((ref) async {
  final city = await ref.watch(userCityProvider.future);
  final walks = await ref.watch(walksProvider.future);
  
  return walks.where((w) => w.city == city).toList();
});
```

---

## Refactoring Checklist

Use this when converting a screen to providers:

- [ ] Change `StatefulWidget` → `ConsumerWidget`
- [ ] Change `State<T>` → `ConsumerState<T>` (if using StatefulWidget)
- [ ] Replace `AppPreferences.get*()` with `ref.watch(someProvider)`
- [ ] Replace `AppPreferences.set*()` with `ref.read(someNotifierProvider.notifier).method()`
- [ ] Replace `setState()` with `ref.refresh()` or `ref.invalidate()`
- [ ] Remove `initState` / `dispose` (providers handle it)
- [ ] Test with `flutter test`

---

## Screens to Refactor Next

1. `lib/screens/home_screen.dart` — Use `userCityProvider`, `walksProvider`
2. `lib/screens/profile_screen.dart` — Use `currentUserIdProvider`, preferences
3. `lib/screens/create_walk_screen.dart` — Use `userCityNotifierProvider`
4. `lib/screens/settings_screen.dart` — Use theme/preference notifiers

---

## Testing Providers

Example test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lib/providers/auth_provider.dart';

void main() {
  test('isAuthenticatedProvider returns false when no user', () async {
    final container = ProviderContainer();
    
    final isAuth = container.read(isAuthenticatedProvider);
    
    expect(isAuth, false);
  });
}
```

---

## Troubleshooting

### "Provider is being watched outside of a widget tree"
- **Fix:** Only call `ref.watch()` inside `build()`, not in methods.

### "ProviderException: Could not determine the type"
- **Fix:** Add explicit type to provider: `FutureProvider<String>(...)`

### Changes not reflecting
- **Fix:** Use `ref.refresh(provider)` or `ref.invalidate(provider)` to bust the cache.

---

## Resources

- [Riverpod Docs](https://riverpod.dev)
- [Flutter Riverpod Overview](https://docs.flutter.dev/data-and-backend/state-mgmt/options)

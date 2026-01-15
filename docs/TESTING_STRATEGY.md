# Testing Strategy

## Testing Framework & Best Practices

This document defines how to test the Yalla Nemshi app at different levels.

---

## 🧪 Test Pyramid

```
        ╱╲
       ╱  ╲          E2E Tests (5-10)
      ╱────╲         Device/simulator tests
     ╱      ╲        Real Firebase, real network
    ╱────────╲

   ╱╲        ╱╲
  ╱  ╲      ╱  ╲     Integration Tests (20-50)
 ╱────╲    ╱────╲    Multiple components
╱      ╲  ╱      ╲   Mock external services
────────────────────

╱╲  ╱╲  ╱╲  ╱╲  ╱╲  Widget Tests (50-100)
╱  ╱  ╱  ╱  ╱  ╱  ╱  Single screen behavior
───────────────────  Form validation, taps, navigation

╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲  Unit Tests (100+)
╱  ╱  ╱  ╱  ╱  ╱  ╱  Smallest components
───────────────────  Providers, services, models
```

---

## 📋 Test Types

### **1. Unit Tests**
**Purpose:** Test individual functions/classes in isolation

**Examples:**
```dart
// test/services/location_service_test.dart
void main() {
  group('LocationService', () {
    test('parseCoordinates returns valid LatLng', () {
      final coords = LocationService.parseCoordinates('31.2357,29.9496');
      expect(coords.latitude, 31.2357);
      expect(coords.longitude, 29.9496);
    });

    test('calculateDistance returns correct value', () {
      const start = LatLng(31.2357, 29.9496);
      const end = LatLng(31.2361, 29.9500);
      final distance = LocationService.calculateDistance(start, end);
      expect(distance, lessThan(1)); // Less than 1 km
    });
  });
}
```

**Run:**
```bash
flutter test test/services/location_service_test.dart
```

**Coverage:**
- Validators (email, password, phone)
- Formatters (date, currency, distance)
- Calculators (distance, age, stats)
- Model methods (toJson, fromJson, copyWith)

---

### **2. Widget Tests**
**Purpose:** Test UI components and screen behavior

**Examples:**
```dart
// test/screens/login_screen_test.dart
void main() {
  group('LoginScreen', () {
    testWidgets('shows error when email is invalid', 
      (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(child: LoginScreen())
      );
      
      // Enter invalid email
      await tester.enterText(
        find.byType(TextField).first, 
        'notanemail'
      );
      
      // Tap login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      
      // Verify error message
      expect(
        find.text('Please enter a valid email'),
        findsOneWidget,
      );
    });

    testWidgets('navigates to home on successful login',
      (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      
      // Mock successful login
      when(mockAuthService.login(
        email: 'test@test.com',
        password: 'password123'
      )).thenAnswer((_) async => User(uid: '123'));
      
      // Perform login
      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      
      // Verify navigation
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
```

**Run:**
```bash
flutter test test/screens/login_screen_test.dart
```

**Coverage:**
- User interactions (tap, scroll, enter text)
- Form validation display
- Loading/error states
- Navigation triggers
- Widget rendering

---

### **3. Integration Tests**
**Purpose:** Test multiple components working together

**Examples:**
```dart
// test/integration/join_walk_flow_test.dart
void main() {
  group('Join Walk Flow Integration', () {
    testWidgets('user can join a walk from home screen',
      (WidgetTester tester) async {
      // Setup
      final testWalk = createTestWalk(id: 'walk_1');
      when(mockFirestore.getWalks()).thenAnswer(
        (_) => Stream.value([testWalk])
      );
      
      // Run app
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Verify home screen loads
      expect(find.byType(HomeScreen), findsOneWidget);
      
      // Tap walk card
      await tester.tap(find.byType(WalkCard).first);
      await tester.pumpAndSettle();
      
      // Verify details screen
      expect(find.byType(WalkDetailsScreen), findsOneWidget);
      
      // Tap join button
      when(mockRepository.joinWalk(
        walkId: 'walk_1',
        userId: 'user_1'
      )).thenAnswer((_) async => true);
      
      await tester.tap(find.byText('Join Walk'));
      await tester.pumpAndSettle();
      
      // Verify success state
      expect(find.byText('Joined ✓'), findsOneWidget);
    });
  });
}
```

**Run:**
```bash
flutter test test/integration/
```

**Coverage:**
- Multi-screen flows
- State changes across multiple providers
- Mock Firebase interactions
- User journeys

---

### **4. End-to-End Tests (E2E)**
**Purpose:** Test on real device with real Firebase

**Setup:**
```bash
flutter drive --target=test_driver/app.dart
```

**Example (test_driver/e2e_test.dart):**
```dart
void main() {
  group('E2E - Full User Journey', () {
    testWidgets('user can login and join a walk',
      (WidgetTester tester) async {
      // Run app
      final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
      
      // Actual Firebase (not mocked)
      await Firebase.initializeApp();
      
      // Perform real login
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle(Duration(seconds: 2));
      
      // Enter credentials
      await tester.enterText(find.byKey(Key('email_field')), 'test@test.com');
      await tester.enterText(find.byKey(Key('password_field')), 'Test123!@');
      
      // Wait for actual Firebase auth
      await tester.tap(find.byText('Login'));
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Verify home screen loaded (real data from Firestore)
      expect(find.byType(HomeScreen), findsOneWidget);
      
      // Find a real walk and join
      await tester.tap(find.byType(WalkCard).first);
      await tester.pumpAndSettle();
      
      await tester.tap(find.byText('Join Walk'));
      await tester.pumpAndSettle(Duration(seconds: 2));
      
      // Verify joined (actual Firestore update)
      expect(find.byText('Joined ✓'), findsOneWidget);
      
      // Take screenshot for debugging
      await binding.takeScreenshot('joined_walk');
    });
  });
}
```

**Run on Device:**
```bash
# Start emulator/device
flutter emulators launch android_emulator

# Run E2E tests
flutter drive --target=test_driver/app.dart --device-id emulator-5554
```

**Coverage:**
- Real Firebase authentication
- Real Firestore data
- Real notifications (if configured)
- Performance on actual hardware
- Real network conditions

---

## 🔧 Mocking Strategies

### **Mock Firebase Services**
```dart
// test/mocks/mock_firebase.dart
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {
  @override
  String get uid => 'test_user_123';
}

// Usage in tests
final mockAuth = MockFirebaseAuth();
when(mockAuth.signInWithEmailAndPassword(
  email: 'test@test.com',
  password: 'password123'
)).thenAnswer((_) async => UserCredential(user: MockUser()));
```

### **Mock Riverpod Providers**
```dart
// test/utils/test_helpers.dart
final mockAuthProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
  (ref) => AuthNotifier(mockAuthService),
);

// Usage in tests
await tester.pumpWidget(
  ProviderContainer(
    overrides: [
      authProvider.overrideWithProvider(mockAuthProvider),
    ],
    child: MyApp(),
  ).widget,
);
```

### **Mock Location Services**
```dart
// test/mocks/mock_location.dart
class MockGeolocator extends Mock implements Geolocator {}

when(mockGeolocator.getCurrentPosition())
  .thenAnswer((_) async => Position(
    latitude: 31.2357,
    longitude: 29.9496,
    timestamp: DateTime.now(),
    // ... other required fields
  ));
```

---

## ✅ Test Checklist by Component

### **Authentication Service**
- [ ] Valid email/password login returns user
- [ ] Invalid credentials throw error
- [ ] Google sign-in works
- [ ] Logout clears user
- [ ] Token refresh works
- [ ] Signup creates new user in Firestore

### **Location Service**
- [ ] Requests permission when needed
- [ ] Gets current location
- [ ] Converts lat/lng to address
- [ ] Calculates distance between points
- [ ] Handles permission denied

### **Notification Service**
- [ ] Requests iOS/Android permissions
- [ ] Gets FCM token
- [ ] Stores token in Firestore
- [ ] Handles token refresh
- [ ] Cleans up on logout
- [ ] Deep links work on tap

### **Walk Management**
- [ ] Fetch walks for city
- [ ] Filter by gender/pace
- [ ] Create new walk
- [ ] Join/leave walk
- [ ] Update walk details
- [ ] Cancel walk

### **Chat**
- [ ] Send message
- [ ] Receive messages in real-time
- [ ] Delete message (if allowed)
- [ ] Display messages in order

### **User Profile**
- [ ] Display user stats
- [ ] Update profile picture
- [ ] Update bio
- [ ] View ratings
- [ ] Follow/unfollow user

---

## 📊 Running Tests Locally

### **Run All Tests**
```bash
flutter test
```

### **Run Tests in Specific File**
```bash
flutter test test/services/auth_service_test.dart
```

### **Run Tests Matching Pattern**
```bash
flutter test --name="LocationService"
```

### **Run Tests with Coverage**
```bash
flutter test --coverage
# View coverage report
open coverage/lcov.html  # macOS
start coverage/lcov.html # Windows
```

### **Run Tests on Multiple Devices**
```bash
# Terminal 1: Start emulator
flutter emulators launch android_emulator

# Terminal 2: Run tests
flutter test -d emulator-5554
```

### **Run with Watch Mode**
```bash
flutter test --watch
# Tests re-run on file changes
```

---

## 🚀 CI/CD Integration (GitHub Actions)

### **Expected Setup** (future)
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: |
          bash <(curl -s https://codecov.io/bash) \
            -f coverage/lcov.info
```

**Track coverage** over time at [codecov.io](https://codecov.io)

---

## 📈 Test Metrics

### **Targets**
| Metric | Target | Current |
|--------|--------|---------|
| Line Coverage | > 80% | TBD |
| Unit Tests | > 100 | 0 |
| Widget Tests | > 50 | 0 |
| Integration Tests | > 20 | 0 |
| Build Time | < 3 min | ~4 min |

### **Tracking**
- Run `flutter test --coverage` before commits
- Check `coverage/lcov.info` for uncovered lines
- Aim to increase coverage with each feature

---

## 🐛 Common Testing Issues

### **Issue: "Null safety errors in tests"**
```dart
// ❌ Wrong
test('does something', () {
  final result = functionThatReturnsNull();
  expect(result, null); // Can crash if wrong type
});

// ✅ Right
test('does something', () {
  final result = functionThatReturnsNull();
  expect(result, isNull); // Type-safe
});
```

### **Issue: "Provider not found in test"**
```dart
// ❌ Wrong - Provider not overridden
await tester.pumpWidget(createTestApp());

// ✅ Right - Override provider
await tester.pumpWidget(
  ProviderContainer(
    overrides: [
      authProvider.overrideWithValue(AsyncValue.data(mockUser)),
    ],
    child: MyApp(),
  ).widget,
);
```

### **Issue: "Async/await timing issues"**
```dart
// ❌ Wrong - Doesn't wait for async operations
await tester.tap(find.byType(ElevatedButton));
expect(find.byText('Success'), findsOneWidget);

// ✅ Right - Wait for rebuilds
await tester.tap(find.byType(ElevatedButton));
await tester.pumpAndSettle(); // Wait for all async operations
expect(find.byText('Success'), findsOneWidget);
```

### **Issue: "Firebase emulator not starting"**
```bash
# Make sure Java is installed
java -version

# Start Firebase emulator
firebase emulators:start

# Use in tests with environment variable
export FIRESTORE_EMULATOR_HOST=localhost:8080
flutter test
```

---

## 🎯 Pre-Commit Test Strategy

### **Before Pushing Code**
```bash
# 1. Run analyzer (no warnings)
flutter analyze

# 2. Run tests (all pass)
flutter test

# 3. Check coverage (aim > 80% on changed files)
flutter test --coverage
grep -o 'lines\.\.\.: [0-9]*' coverage/lcov.info
```

### **Git Hook** (optional - auto-run tests before commit)
```bash
#!/bin/bash
# .git/hooks/pre-commit
flutter analyze || exit 1
flutter test || exit 1
```

---

## 📚 Test File Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:yalla_nemshi/services/example_service.dart';

// Create mocks
class MockDependency extends Mock implements Dependency {}

void main() {
  group('ExampleService', () {
    late ExampleService service;
    late MockDependency mockDep;

    setUp(() {
      mockDep = MockDependency();
      service = ExampleService(mockDep);
    });

    tearDown(() {
      // Cleanup if needed
    });

    test('does something when condition is met', () {
      // Arrange
      when(mockDep.getValue()).thenReturn(42);
      
      // Act
      final result = service.processValue();
      
      // Assert
      expect(result, 42);
      verify(mockDep.getValue()).called(1);
    });
  });
}
```

---

## 🔍 Example Test Suite

See test files:
- `test/services/` - Service unit tests
- `test/screens/` - Screen widget tests
- `test/integration/` - Multi-component tests
- `test_driver/` - E2E tests (for future use)

---

## 📚 Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Integration Testing Guide](https://flutter.dev/docs/testing/integration-tests)
- [Firebase Testing Best Practices](https://firebase.google.com/docs/emulator-suite/connect_firestore)

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team

# Monitoring & Troubleshooting Guide

## Debugging, Monitoring, and Problem Resolution

This document helps developers diagnose and fix issues in development and production.

---

## 🔍 Local Development Debugging

### **1. Flutter DevTools**

**Start DevTools:**
```bash
flutter pub global activate devtools
dart devtools
```

**Access:**
- Open `http://localhost:9100` in browser
- Or connect from VS Code: `Debug → Open DevTools`

**Features:**
| Tab | Use Case |
|-----|----------|
| Inspector | Widget tree, layout debugging |
| Performance | Frame rate, janky frames |
| Memory | Memory leaks, heap snapshots |
| Logging | View all print/log statements |
| Network | HTTP requests (if applicable) |
| Debugger | Set breakpoints, step through code |

### **2. Logging Best Practices**

```dart
// ✅ Use logger with levels
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug: User ID = $userId');        // Debug
logger.i('Info: Walk created');              // Info
logger.w('Warning: Token expired');          // Warning
logger.e('Error: Auth failed', error: e);    // Error

// ❌ Avoid
print('Something happened');  // Hard to filter
```

**View logs in DevTools:**
1. Open DevTools
2. Go to "Logging" tab
3. Filter by level or search term

### **3. Setting Breakpoints**

```dart
// Method 1: IDE breakpoint
// Click line number in VS Code to set breakpoint

// Method 2: Programmatic breakpoint
void myFunction() {
  debugger();  // Breaks here when debugging
  // ... code continues
}

// Method 3: Conditional breakpoint
if (userId == null) {
  debugger();  // Only breaks if condition is true
}
```

### **4. Hot Reload Debugging**

```bash
# Hot reload while debugging
# Press 'r' in terminal to reload code (keep state)
# Press 'R' to hot restart (reset state)

# Common issues:
# "Hot reload failed" → Code has syntax errors
# "Hot reload didn't work" → Made changes that can't be hot reloaded
#   (e.g., changed main(), removed providers)
```

---

## 🔴 Common Issues & Fixes

### **Issue 1: "Bad State: No Firebase App '[DEFAULT]' has been created"**

**Cause:** Firebase not initialized before app start

**Fix:**
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase FIRST
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }
  
  // Then init services
  await NotificationService.instance.init();
  
  // Finally run app
  runApp(const MyApp());
}
```

**Debug:**
```bash
flutter pub get
flutter clean
flutter pub get
flutter run
```

---

### **Issue 2: "Null Safety Error: The value of 'value' can't be null"**

**Cause:** Accessing property on null object

**Example (Bad):**
```dart
final user = authProvider.watch(ref);
print(user.displayName);  // ❌ Crashes if user is null
```

**Fix:**
```dart
final user = authProvider.watch(ref);

// Option 1: Null check
if (user != null) {
  print(user.displayName);
}

// Option 2: Use ?? operator
print(user?.displayName ?? 'Anonymous');

// Option 3: Check AsyncValue
user.when(
  data: (userData) => print(userData.displayName),
  loading: () => print('Loading...'),
  error: (err, _) => print('Error: $err'),
);
```

---

### **Issue 3: "Permission Denied" in Firestore**

**Cause:** Security rules blocking operation

**Debug Steps:**
```bash
# 1. Check if user is authenticated
# In app, verify: FirebaseAuth.instance.currentUser != null

# 2. Check Firestore rules in Firebase Console
# Firestore → Rules tab

# 3. Test rules with Firestore emulator
firebase emulators:start
# Then run app with:
# export FIRESTORE_EMULATOR_HOST=localhost:8080
```

**Example Issue:**
```javascript
// ❌ Wrong - Blocks all non-admin users
match /walks/{walkId} {
  allow read, write: if request.auth.token.admin == true;
}

// ✅ Right - Allow authenticated users
match /walks/{walkId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
               resource.data.hostUid == request.auth.uid;
}
```

**Firestore Console Debug:**
1. Open Firebase Console
2. Firestore → Data
3. Try to read a document
4. Click "Test this rule" button
5. Select your user UID
6. See if rule allows/denies

---

### **Issue 4: "FCM Token Not Storing / Notifications Not Working"**

**Cause Chain:**
```
1. Cloud Functions not deployed → Notifications don't trigger
2. Permissions not granted → Can't get FCM token
3. User logged out → Tokens deleted
4. Emulator running → FCM disabled on emulator
```

**Debug:**
```dart
// In NotificationService.init():
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');  // Should print token

// Check if token is in Firestore
FirebaseFirestore.instance
  .collection('users')
  .doc(FirebaseAuth.instance.currentUser!.uid)
  .collection('fcmTokens')
  .get()
  .then((docs) => print('Tokens: ${docs.docs.map((d) => d.id)}'));

// Check if permissions granted
final permission = await FirebaseMessaging.instance.requestPermission();
print('Permission: $permission');  // Should be AuthorizationStatus.authorized
```

**Fix Steps:**
```
1. Deploy Cloud Functions:
   firebase deploy --only functions

2. Grant permissions (manual on device):
   Settings → App → Notifications → Toggle ON

3. Verify token stored:
   Firebase Console → Firestore → users → [userID] → fcmTokens

4. Test on real device (not emulator):
   flutter run -d [device_id]
```

---

### **Issue 5: "Location Permission Denied"**

**Cause:** Location not requested before use

**iOS Fix:**
```
1. Xcode → Runner → Signing & Capabilities
2. Click "+ Capability"
3. Add "Location When In Use Usage Description"
4. Add description: "Yalla Nemshi uses your location to show nearby walks"
```

**Android Fix (Already done):**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**Runtime Permission (Code):**
```dart
final permission = await Permission.location.request();
if (permission.isDenied) {
  print('Location permission denied');
} else if (permission.isGranted) {
  final location = await Geolocator.getCurrentPosition();
  print('Location: ${location.latitude}, ${location.longitude}');
}
```

---

### **Issue 6: "Google Sign-In Not Working"**

**Android:**
```
1. Get SHA-1 fingerprint:
   ./gradlew signingReport
   
2. Copy "SHA1" value

3. Firebase Console → Settings → Add Fingerprint

4. Download new google-services.json

5. Replace file: android/app/google-services.json

6. flutter clean && flutter pub get
```

**iOS:**
```
1. Xcode → Runner → Signing & Capabilities
2. Add "Google Sign-In" capability
3. Configure URL scheme: [REVERSE_CLIENT_ID]
   (Find in GoogleService-Info.plist)
```

---

## 📊 Firebase Monitoring

### **1. Check Firestore Usage**

**Location:** Firebase Console → Firestore → Analytics

```
Monitor:
- Read operations (target: < 5K/day)
- Write operations (target: < 2K/day)
- Storage usage (target: < 1GB)
```

**If exceeding limits:**
```
1. Check for infinite loops (batch writes)
2. Add Firestore indexes
3. Implement pagination (load 10 walks at a time)
4. Archive old walks
```

### **2. Check Cloud Function Logs**

```bash
# View logs in real-time
firebase functions:log --tail

# View errors only
firebase functions:log | grep -i error

# Search specific function
firebase functions:log | grep onWalkJoined
```

**Expected logs:**
```
Successfully sent notification to user_123
Token cleanup: removed 2 invalid tokens
onWalkCancelled triggered for walk_456
```

**Error logs to investigate:**
```
Permission denied reading users collection
Failed to send FCM notification: invalid token
Timeout waiting for Firestore update
```

### **3. Check Crashlytics**

**Location:** Firebase Console → Crashlytics

```
Shows:
- App crashes (Android/iOS only)
- Error traces
- Affected users
- Version breakdown
```

**How to test:**
```dart
// In debug build, trigger crash
ElevatedButton(
  onPressed: () {
    throw Exception('Test crash');
  },
  child: Text('Crash App'),
)

// Crashlytics won't catch debug crashes
// Deploy to release build and test
```

### **4. Check Authentication Issues**

**Location:** Firebase Console → Authentication → Users

```
Monitor:
- New user signups
- Failed login attempts
- User deletion
```

**Debug auth problems:**
```dart
FirebaseAuth.instance.authStateChanges().listen((user) {
  if (user == null) {
    print('User logged out');
  } else {
    print('User logged in: ${user.email}');
  }
});

// Check auth errors
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  print('Auth error: ${e.code} - ${e.message}');
  // user-not-found, wrong-password, invalid-email, etc.
}
```

---

## 🔧 Performance Optimization

### **1. Identify Jank (Slow Frames)**

**Using DevTools:**
```
1. Open DevTools → Performance tab
2. Run app action (e.g., scroll walks list)
3. Look at frame rate graph
4. Frames below 60 FPS = janky
```

**Common causes:**
```
- Expensive widget rebuilds (use Consumer)
- Synchronous I/O (use async/await)
- Large lists without pagination (use ListView.builder)
- Image loading without caching
```

### **2. Profile Memory Usage**

```
DevTools → Memory tab:
1. Take heap snapshot
2. Look for large objects
3. Check for memory leaks (allocations that don't decrease)
```

**Common leaks:**
```
- Streams not closed
- Listeners not unsubscribed
- Images not disposed
- Timers not cancelled
```

### **3. Optimize Firestore Queries**

**❌ Bad (fetches all walks):**
```dart
final allWalks = await FirebaseFirestore.instance
  .collection('walks')
  .get();
// Then filter in app
final filtered = allWalks.docs.where((w) => w['city'] == city);
```

**✅ Good (filters in Firestore):**
```dart
final walks = await FirebaseFirestore.instance
  .collection('walks')
  .where('city', isEqualTo: city)
  .where('dateTime', isGreaterThan: Timestamp.now())
  .orderBy('dateTime')
  .limit(20)
  .get();
```

**Create indexes for complex queries:**
```bash
# In Firebase Console or via CLI
firebase firestore:indexes:create --collection=walks \
  --field=city:Asc --field=dateTime:Desc
```

---

## 🐛 Debugging Specific Features

### **Walk Join Issue**

```dart
// Debug: Verify walk exists
final walk = await FirebaseFirestore.instance
  .collection('walks')
  .doc(walkId)
  .get();
print('Walk exists: ${walk.exists}');

// Debug: Check current user
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');

// Debug: Verify join record created
final participation = await FirebaseFirestore.instance
  .collection('users')
  .doc(user!.uid)
  .collection('walks')
  .doc(walkId)
  .get();
print('Join record exists: ${participation.exists}');

// Debug: Check walk's joinedUserUids
final updatedWalk = await FirebaseFirestore.instance
  .collection('walks')
  .doc(walkId)
  .get();
print('Joined users: ${updatedWalk['joinedUserUids']}');
```

### **Notification Not Showing**

```dart
// Debug: Check permissions
final permission = await FirebaseMessaging.instance.requestPermission();
print('Permission: ${permission.name}');  // authorized, denied, provisional

// Debug: Check token
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Debug: Verify token in Firestore
final doc = await FirebaseFirestore.instance
  .collection('users')
  .doc(user!.uid)
  .collection('fcmTokens')
  .doc(token)
  .get();
print('Token stored: ${doc.exists}');

// Debug: Manually send test notification (Firebase Console)
// Messaging → Create campaign → Send test
```

### **Login Not Working**

```dart
// Debug: Check email format
final email = 'test@test.com';
final isValid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
print('Email valid: $isValid');

// Debug: Check Firebase auth state
final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
print('Login result: ${result.user?.uid}');

// Debug: Check user created in Firestore
final userDoc = await FirebaseFirestore.instance
  .collection('users')
  .doc(result.user!.uid)
  .get();
print('User doc exists: ${userDoc.exists}');

// Debug: Check any error messages
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  print('Error code: ${e.code}');
  print('Error message: ${e.message}');
}
```

---

## 📈 Monitoring Checklist

### **Daily Checks**
- [ ] Cloud Functions deployed and running (no errors in logs)
- [ ] No spike in error rates
- [ ] Firestore usage within expected range

### **Weekly Checks**
- [ ] Review user feedback/crash reports
- [ ] Check Crashlytics for new error patterns
- [ ] Monitor authentication issues

### **Monthly Checks**
- [ ] Analyze usage trends
- [ ] Optimize slow queries
- [ ] Review performance metrics
- [ ] Plan optimizations for next month

---

## 🚨 Production Emergency Response

### **Scenario 1: App Keeps Crashing**

```
1. Check Crashlytics for error
2. Identify affected version
3. Hotfix locally
4. Build and deploy new version
5. Users must update app to get fix
```

### **Scenario 2: Notifications Not Sending**

```
1. Verify Cloud Functions are deployed
   firebase functions:log --tail
   
2. Check Firestore rules allow token writes
   firebase firestore:indexes
   
3. Test with manual Firebase Console test
   Messaging → Create campaign
   
4. If still broken, disable notifications temporarily
   Remove notification code, deploy hotfix
```

### **Scenario 3: Authentication Broken**

```
1. Check Firebase Auth status
   Firebase Console → Authentication → Settings
   
2. Verify security rules
   Firestore → Rules
   
3. Test in emulator
   firebase emulators:start
   
4. If broken, roll back to previous version
   Revert to last known working commit
```

---

## 📚 Related Documentation

- [Firebase Setup Guide](./FIREBASE_SETUP.md) - Configuration reference
- [API Documentation](./API_DOCUMENTATION.md) - Function details
- [Architecture Overview](./ARCHITECTURE.md) - System design
- [Testing Strategy](./TESTING_STRATEGY.md) - How to test

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team  
**Supported Platforms:** Android, iOS, Web  
**Firebase Console:** https://console.firebase.google.com/project/yallanemshiapp

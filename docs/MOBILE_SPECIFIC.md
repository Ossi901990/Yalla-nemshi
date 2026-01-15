# Mobile-Specific Considerations

## Platform-Specific Development & Deployment

This document covers Android, iOS, and Web-specific configurations and gotchas.

---

## 📱 Android-Specific Guide

### **Project Structure**
```
android/
├── app/
│   ├── build.gradle.kts           ← App-level config
│   ├── google-services.json       ← Firebase config (DO NOT COMMIT)
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml ← Permissions & services
│           ├── kotlin/             ← Native code (if any)
│           └── res/
│               └── mipmap-*/       ← App icons
├── build.gradle.kts               ← Project-level config
├── gradle.properties              ← Gradle settings
└── local.properties               ← Local SDK path (DO NOT COMMIT)
```

### **Firebase Configuration**

**Getting google-services.json:**
```
1. Firebase Console → Project settings
2. Click "Google-services.json" download
3. Place in: android/app/google-services.json
4. Never commit to git (already in .gitignore)
```

**Updating Dependencies:**
```bash
# In android/app/build.gradle.kts
dependencies {
  // Firebase
  implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
  implementation("com.google.firebase:firebase-messaging")
  
  // Google Services
  implementation("com.google.android.gms:play-services-maps:18.2.0")
  implementation("com.google.android.gms:play-services-location:21.1.0")
}

# After changes
flutter clean
flutter pub get
flutter run -d android
```

### **AndroidManifest.xml Setup**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application>
        <!-- Firebase Cloud Messaging -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <!-- Notification Channel (required for Android 8.0+) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="yalla_nemshi_default_channel" />
        
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/primary" />

        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### **Testing on Android Emulator**

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators launch Pixel_5_API_31

# Run app
flutter run -d emulator-5554

# Debug with DevTools
flutter run -d emulator-5554
# Then open DevTools in another terminal
dart devtools
```

**Common Emulator Issues:**
```
Issue: Emulator won't start
Fix: 
  - Ensure KVM enabled (Linux): kvm-ok
  - Check RAM availability
  - Restart Android Studio

Issue: No internet in emulator
Fix:
  - Check WiFi settings in emulator
  - Restart emulator with: -netdelay none

Issue: Notifications not working
Fix:
  - Use real device (emulator FCM unreliable)
  - Update Google Play Services in emulator
```

### **Building for Release (Android)**

```bash
# Build APK
flutter build apk --split-per-abi

# Build App Bundle (for Play Store)
flutter build appbundle

# Output locations:
# APK: build/app/outputs/flutter-apk/
# Bundle: build/app/outputs/bundle/release/

# Sign with key (already done if key exists):
# android/app/build.gradle.kts has signingConfigs configured
```

**First Time Release Setup:**
```bash
# Generate signing key (one time)
keytool -genkey -v -keystore ~/yalla_nemshi.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias yalla_nemshi

# Add to android/app/build.gradle.kts:
signingConfigs {
  release {
    keyAlias = "yalla_nemshi"
    keyPassword = "your_password"
    storeFile = file("~/yalla_nemshi.jks")
    storePassword = "your_password"
  }
}
```

### **Runtime Permissions (Android 6.0+)**

```dart
// Already handled in NotificationService.dart
// But here's manual example:

import 'package:permission_handler/permission_handler.dart';

void requestLocationPermission() async {
  final status = await Permission.location.request();
  
  switch (status) {
    case PermissionStatus.granted:
      print('Location permission granted');
      break;
    case PermissionStatus.denied:
      print('Location permission denied');
      break;
    case PermissionStatus.restricted:
      print('Location permission restricted by system');
      break;
    case PermissionStatus.limited:
      print('Location permission limited');
      break;
    case PermissionStatus.provisional:
      print('Location permission provisional (iOS 14+)');
      break;
  }
}
```

---

## 🍎 iOS-Specific Guide

### **Project Structure**
```
ios/
├── Runner/
│   ├── GeneratedPluginRegistrant.h     ← Auto-generated (don't edit)
│   ├── GeneratedPluginRegistrant.m     ← Auto-generated (don't edit)
│   ├── Info.plist                      ← App permissions & settings
│   ├── GoogleService-Info.plist        ← Firebase config (DO NOT COMMIT)
│   └── Runner.xcodeproj/
│       └── project.pbxproj             ← Xcode project config
├── Runner.xcworkspace/                  ← CocoaPods workspace
└── Podfile                              ← CocoaPods dependencies
```

### **Firebase Configuration**

**Getting GoogleService-Info.plist:**
```
1. Firebase Console → Project settings
2. Download "GoogleService-Info.plist"
3. Drag into Xcode → Runner folder
4. Ensure "Copy items if needed" is checked
5. Never commit to git (already in .gitignore)
```

**Updating CocoaPods:**
```bash
# Update pod dependencies
cd ios
pod repo update
pod install --repo-update
cd ..

flutter clean
flutter pub get
flutter run -d ios
```

### **Xcode Configuration**

**Minimum Deployment Target:**
```
Runner → Build Settings → Minimum Deployments Target
Should be: 11.0 or higher (Firebase requirement)
```

**Capabilities (Signing & Capabilities):**
```
1. Select Runner project
2. Select Runner target
3. Click "Signing & Capabilities"
4. Add these capabilities:
   - Background Modes (if needed)
   - Push Notifications
   - Sign In with Apple (if using SSO)
   - Location (for GPS)
```

**Info.plist Permissions:**
```xml
<!-- ios/Runner/Info.plist -->
<dict>
  <!-- Location Permissions -->
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Yalla Nemshi uses your location to show nearby walks</string>
  
  <!-- Camera (for photo upload) -->
  <key>NSCameraUsageDescription</key>
  <string>Yalla Nemshi uses your camera to capture walk photos</string>
  
  <!-- Photo Library -->
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Yalla Nemshi accesses photos to upload from your library</string>
  
  <key>NSPhotoLibraryAddOnlyUsageDescription</key>
  <string>Yalla Nemshi saves walk photos to your library</string>
  
  <!-- Maps (if using Web Maps) -->
  <key>NSBonjourServiceTypes</key>
  <array>
    <string>_http._tcp</string>
    <string>_https._tcp</string>
  </array>
</dict>
```

### **APNs Certificate Setup**

**One-time Setup (required for push notifications):**

```
1. Apple Developer Portal → Certificates, IDs & Profiles
2. Create App ID (if not exists)
3. Create APNs certificate:
   - Keys → App IDs → Select app
   - Edit → APNs → Create certificate
4. Download certificate (.cer file)
5. Convert to .p8 format:
   openssl x509 -inform DER -outform PEM -in aps_production.cer -out aps_production.pem
6. Upload to Firebase Console:
   - Project settings → Cloud Messaging
   - APNs certificates → Upload certificate
```

### **Testing on iOS Simulator**

```bash
# List available simulators
xcrun simctl list devices

# Launch simulator
open -a Simulator

# Run app
flutter run -d iPhone\ 15

# Debug with DevTools
flutter run -d iPhone\ 15
dart devtools
```

**Common iOS Issues:**

```
Issue: "Pod install fails"
Fix:
  cd ios
  rm Podfile.lock
  pod repo update
  pod install --repo-update
  cd ..

Issue: "Swift/Objective-C linking errors"
Fix:
  - Ensure minimum deployment target ≥ 11.0
  - Clean build folder: Cmd+Shift+K
  - Delete derived data: ~/Library/Developer/Xcode/DerivedData

Issue: "Notifications don't work in simulator"
Fix:
  - Use real device for testing push notifications
  - Simulator can receive local notifications only

Issue: "Map doesn't load in simulator"
Fix:
  - Ensure API keys configured
  - Check Google Maps iOS SDK configuration
```

### **Building for Release (iOS)**

```bash
# Build for release
flutter build ios --release

# Then in Xcode:
# 1. Product → Archive
# 2. Distribute App
# 3. Choose "Ad Hoc" or "TestFlight"
# 4. Sign with certificate
# 5. Submit to App Store

# Or use Xcode directly:
open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

**First Time Release Setup:**
```
1. Apple Developer Program → Certificates, IDs & Profiles
2. Create App ID
3. Create Signing Certificates (Development & Production)
4. Create Provisioning Profiles (Development & Distribution)
5. In Xcode:
   - Signing & Capabilities → Team selection
   - Configure signing certificate and provisioning profile
```

### **iOS Runtime Permissions**

```dart
// Already handled in NotificationService.dart
// Manual example for location:

import 'package:permission_handler/permission_handler.dart';

void requestLocationPermission() async {
  final status = await Permission.location.request();
  
  // On iOS:
  // - First request shows system dialog
  // - User can grant "Always", "While Using", or "Never"
  // - Info.plist message: "Yalla Nemshi uses your location..."
}
```

---

## 🌐 Web-Specific Guide

### **Project Structure**
```
web/
├── index.html              ← HTML entry point
├── favicon.ico             ← Browser tab icon
├── manifest.json           ← PWA manifest
└── icons/                  ← App icons for web
```

### **Web Firebase Configuration**

**In lib/main.dart:**
```dart
import 'firebase_options.dart';  // Already generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    // Web-specific Firebase options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // Native (Android/iOS) Firebase options
    await Firebase.initializeApp();
  }
  
  runApp(const MyApp());
}
```

**Web APIs Limited:**
```dart
// ❌ These don't work on web:
geolocator.getCurrentPosition();  // No GPS on web
permission_handler.request();     // No permission system on web
image_picker.pickImage();         // Limited file access on web

// ✅ Workarounds:
// - Use Geolocation API (browser native)
// - Use file_picker instead of image_picker
// - Gracefully degrade features on web
```

### **Building for Web**

```bash
# Build web version
flutter build web --release

# Output: build/web/

# Run web locally
flutter run -d chrome

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### **PWA (Progressive Web App) Configuration**

**Edit web/manifest.json:**
```json
{
  "name": "Yalla Nemshi",
  "short_name": "Yalla",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#2196F3",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

**Web Hosting (Firebase):**
```bash
# Deploy to Firebase Hosting
firebase deploy --only hosting

# Access at: https://yallanemshiapp.web.app
```

### **Browser Compatibility**

| Feature | Chrome | Firefox | Safari | Edge |
|---------|--------|---------|--------|------|
| Flutter Web | ✅ | ✅ | ✅ | ✅ |
| Firebase Auth | ✅ | ✅ | ✅ | ✅ |
| Firestore | ✅ | ✅ | ✅ | ✅ |
| Geolocation | ✅ | ✅ | ✅ | ✅ |
| FCM (Push) | ✅ | ⚠️ | ❌ | ✅ |
| Image Picker | ✅ | ✅ | ✅ | ✅ |

**Workarounds for Limited Browsers:**
```dart
if (kIsWeb) {
  // Check browser capabilities
  if (html.window.navigator.geolocation != null) {
    // Use Geolocation API
  } else {
    // Fall back to manual location entry
  }
}
```

---

## 🔄 Cross-Platform Conditionals

### **Platform Detection**

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

// Check platform
if (kIsWeb) {
  // Web only
} else if (Platform.isAndroid) {
  // Android only
} else if (Platform.isIOS) {
  // iOS only
}

// Combined check
if (!kIsWeb) {
  // Mobile (Android or iOS)
}

// Debug mode check
if (kDebugMode) {
  print('Debug build - showing verbose logs');
}
```

### **Platform-Specific Widget Example**

```dart
Widget buildPlatformButton() {
  if (kIsWeb) {
    return ElevatedButton(
      onPressed: () {},
      child: const Text('Web Button'),
    );
  } else if (Platform.isIOS) {
    return CupertinoButton(
      onPressed: () {},
      child: const Text('iOS Button'),
    );
  } else {
    return ElevatedButton(
      onPressed: () {},
      child: const Text('Android Button'),
    );
  }
}
```

### **Conditional Dependencies**

```dart
// In services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;

class NotificationService {
  Future<void> init() async {
    if (kIsWeb) {
      // Web: FCM configured in web/index.html
      // Skip mobile permission requests
      return;
    }
    
    if (Platform.isIOS) {
      // iOS: Request user permission
      await requestiOSPermission();
    } else if (Platform.isAndroid) {
      // Android: Runtime permissions
      await requestAndroidPermission();
    }
    
    // Common: Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    await storeTokenToFirestore(token);
  }
}
```

---

## 📱 Testing on Multiple Devices

### **Testing Strategy**

```
Unit Tests (PC/Mac only)
  ↓
Widget Tests (PC/Mac only)
  ↓
Android Emulator + Real Android Device
  ↓
iOS Simulator + Real iOS Device
  ↓
Web (Chrome, Safari, Firefox)
  ↓
Release Build Testing
  ↓
Beta Testing (TestFlight, Play Store)
  ↓
Production Release
```

### **Quick Testing on All Platforms**

```bash
# Android Emulator
flutter emulators launch Pixel_5_API_31
flutter run -d emulator-5554

# iOS Simulator
open -a Simulator
flutter run -d iPhone\ 15

# Web
flutter run -d chrome

# Real Android Device
adb devices
flutter run -d <device_id>

# Real iOS Device (requires provisioning profile)
flutter run -d <device_name>
```

---

## 🚀 Deployment Checklist

### **Before Each Release**

```
Android:
  [ ] Version bumped in pubspec.yaml
  [ ] Build number incremented
  [ ] Signing certificate valid
  [ ] google-services.json up to date
  [ ] Tested on real Android device
  [ ] APK/AAB builds without errors
  [ ] Play Store release notes prepared

iOS:
  [ ] Version bumped in pubspec.yaml
  [ ] Build number incremented
  [ ] Provisioning profile valid
  [ ] GoogleService-Info.plist up to date
  [ ] APNs certificate valid
  [ ] Tested on real iOS device
  [ ] App Store release notes prepared
  [ ] Screenshots updated for App Store

Web:
  [ ] Version bumped in pubspec.yaml
  [ ] Build completes: flutter build web --release
  [ ] Tested on Chrome, Firefox, Safari
  [ ] Firebase Hosting deployment tested
  [ ] SEO tags updated in web/index.html

General:
  [ ] All tests passing: flutter test
  [ ] No lint warnings: flutter analyze
  [ ] CHANGELOG.md updated
  [ ] Git tagged with version: git tag v1.2.0
  [ ] Partner notified of changes
```

---

## 📚 Related Documentation

- [Firebase Setup Guide](./FIREBASE_SETUP.md) - Backend configuration
- [Monitoring & Troubleshooting](./MONITORING_TROUBLESHOOTING.md) - Debug guide
- [Architecture Overview](./ARCHITECTURE.md) - System design

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team  
**Tested Platforms:** Android 7.0+, iOS 11.0+, Web (modern browsers)

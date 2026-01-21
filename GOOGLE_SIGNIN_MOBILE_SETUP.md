# 🔐 Google Sign-In Mobile Setup Guide

**Issue:** Google Sign-In works on web but not on Android/iOS mobile devices.

**Root Cause:** The code intentionally disables Google Sign-In on mobile (see `lib/screens/login_screen.dart` lines 70-79). This was done because the SHA-1 fingerprint needs to be registered in Firebase Console for Android.

---

## ✅ What's Already Configured

1. **Dependencies installed** ✅
   - `google_sign_in: ^7.2.0` in pubspec.yaml
   - `firebase_auth: ^6.1.2`

2. **google-services.json exists** ✅
   - Located at `android/app/google-services.json`
   - Package name: `com.example.yalla_nemshi`

3. **OAuth Client ID exists** ✅
   - Android client ID in google-services.json
   - Web client ID for web platform

---

## 🔧 What Needs to Be Done

### STEP 1: Get Your SHA-1 Fingerprint

You need to register your app's SHA-1 fingerprint in Firebase Console so Google knows your app is authentic.

#### Option A: Using Android Studio (Easiest)
1. Open Android Studio
2. Open the `android` folder as a project
3. Click **Gradle** panel on right side
4. Navigate to: **yalla_nemshi → android → Tasks → android → signingReport**
5. Double-click `signingReport`
6. Look for output like:
   ```
   Variant: debug
   SHA1: 1F:D4:EB:50:59:45:79:74:24:AE:95:1E:79:1A:78:29:39:19:04:74
   ```
7. **Copy that SHA1 value**

#### Option B: Using Command Line (if keytool is available)
```bash
# Windows
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android

# Mac/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for the SHA1 line and copy it.

#### Option C: Already in google-services.json
I can see one SHA-1 already registered:
```
"certificate_hash": "1fd4eb505945797424ae951e791a782939190474"
```

This might be from an old setup. **You should verify this matches your current debug keystore**.

---

### STEP 2: Add SHA-1 to Firebase Console

1. **Go to Firebase Console**
   - Open: https://console.firebase.google.com
   - Select project: **yalla-nemshi-app**

2. **Navigate to Project Settings**
   - Click the gear icon ⚙️ (top left)
   - Click "Project Settings"

3. **Find Your Android App**
   - Scroll down to "Your apps" section
   - Click on the Android app (`com.example.yalla_nemshi`)

4. **Add SHA-1 Fingerprint**
   - Scroll down to "SHA certificate fingerprints"
   - Click "Add fingerprint"
   - Paste your SHA-1 from Step 1
   - Click "Save"

5. **Download NEW google-services.json**
   - After adding SHA-1, click "Download google-services.json"
   - **Replace** `android/app/google-services.json` with the new file
   - This ensures OAuth credentials are updated

---

### STEP 3: Update Android Manifest (if needed)

Open `android/app/src/main/AndroidManifest.xml` and ensure these permissions exist:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these if missing -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application ...>
        <!-- Your existing content -->
    </application>
</manifest>
```

---

### STEP 4: Enable Google Sign-In in Code

I'll update the code to enable mobile Google Sign-In now.

**Current code (lines 70-79 of login_screen.dart):**
```dart
// Non-web: Google sign-in disabled for now (keep mobile changes undone)
if (!kIsWeb) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Google sign-in is available on web only for now.'),
    ),
  );
  return;
}
```

**This needs to be replaced with proper mobile implementation.**

---

### STEP 5: iOS Setup (If Testing on iPhone)

1. **Add GoogleService-Info.plist** ✅ (Already exists at `ios/Runner/GoogleService-Info.plist`)

2. **Update Info.plist**
   Open `ios/Runner/Info.plist` and add:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
         <string>com.googleusercontent.apps.403871427941-5040kbvfht5ambvf1348eoo1s2aakgh9</string>
       </array>
     </dict>
   </array>
   ```

3. **Find REVERSED_CLIENT_ID**
   Open `ios/Runner/GoogleService-Info.plist` and look for:
   ```xml
   <key>REVERSED_CLIENT_ID</key>
   <string>com.googleusercontent.apps.YOUR-ID-HERE</string>
   ```
   Use that value in Info.plist above.

---

## 🚀 After Setup - Testing

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   cd android
   ./gradlew clean
   cd ..
   flutter run
   ```

2. **Test on real device** (emulator may have issues)

3. **Expected behavior:**
   - Click "Sign in with Google" button
   - Google account picker appears
   - Select your Google account
   - Should sign in successfully

---

## 🐛 Troubleshooting

### Error: "Sign in failed: API not enabled"
- Go to Google Cloud Console: https://console.cloud.google.com
- Enable "Google Sign-In API" for your project

### Error: "Developer Error" or "10: "
- SHA-1 not registered correctly in Firebase
- Re-download google-services.json after adding SHA-1
- Rebuild app completely

### Error: "Sign in cancelled by user" (but you didn't cancel)
- OAuth client ID mismatch
- Check package name matches in:
  - `android/app/build.gradle.kts` → `applicationId`
  - `google-services.json` → `package_name`
  - Firebase Console → Android app package name

### Works in debug but not release
- You need to add **RELEASE SHA-1** fingerprint too
- Release builds use a different keystore
- Generate release SHA-1 from your release keystore

---

## 📋 Quick Checklist

Before asking me to enable the code:

- [ ] I have the SHA-1 fingerprint from my debug keystore
- [ ] I added SHA-1 to Firebase Console (Project Settings → Android app)
- [ ] I downloaded the NEW google-services.json and replaced the old one
- [ ] Package name matches everywhere (`com.example.yalla_nemshi`)
- [ ] For iOS: I added REVERSED_CLIENT_ID to Info.plist

**Once you complete these steps, let me know and I'll enable Google Sign-In in the code!**

---

## 📖 Reference Links

- Firebase Android Setup: https://firebase.google.com/docs/android/setup
- Google Sign-In Flutter: https://pub.dev/packages/google_sign_in
- SHA-1 Guide: https://developers.google.com/android/guides/client-auth

---

**Last Updated:** January 21, 2026

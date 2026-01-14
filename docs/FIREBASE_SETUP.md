# Firebase Project Setup Guide

## Project: yallanemshiapp

This document explains the Firebase configuration for Yalla Nemshi and helps new developers understand the backend structure.

---

## 🔑 Quick Facts

- **Project ID:** yallanemshiapp
- **Region:** us-central1 (Cloud Functions)
- **Plan:** Blaze (Pay-as-you-go) - Required for Cloud Functions
- **Status:** Production

---

## ✅ Services Enabled

### **1. Firebase Authentication**
- **Type:** Email/Password + Google Sign-In
- **Location:** Firebase Console → Authentication → Sign-in method
- **Configuration:**
  - Email/Password: Enabled
  - Google Sign-In: Requires `google-services.json` on Android
  - Anonymous: Disabled

### **2. Cloud Firestore (Database)**
- **Database ID:** (default)
- **Location:** us-central1
- **Collections:** See Firestore Collections section below

### **3. Firebase Storage**
- **Bucket:** yallanemshiapp.firebasestorage.app
- **Paths:**
  - `user_profiles/{userId}/avatar` - Profile photos
  - `walk_photos/{walkId}/photo_0..photo_9` - Walk photos
  - `reviews/{reviewId}/photos` - Review photos

### **4. Firebase Cloud Messaging (FCM)**
- **Status:** Configured and ready
- **Token Storage:** `/users/{userId}/fcmTokens`
- **Notifications:** Automated via Cloud Functions

### **5. Cloud Functions**
- **Runtime:** Node.js 20
- **Trigger Type:** Firestore document writes + Cloud Pub/Sub
- **Functions:**
  - `onWalkJoined` - Triggers when walk participation recorded
  - `onWalkCancelled` - Triggers when walk marked cancelled
  - `onWalkUpdated` - Triggers on important walk field changes
  - `onChatMessage` - Triggers on new chat messages

### **6. Firebase Crashlytics**
- **Status:** Enabled
- **Data Sent:** Crash reports, error traces
- **Native:** Android + iOS only (not web)

---

## 📊 Firestore Collections Structure

```
/walks
├── {walkId}
│   ├── title: string
│   ├── dateTime: timestamp
│   ├── distanceKm: number (optional)
│   ├── gender: string (Mixed|Women|Men)
│   ├── pace: string (Relaxed|Normal|Brisk)
│   ├── hostUid: string
│   ├── hostName: string
│   ├── hostPhotoUrl: string (optional)
│   ├── joinedUserUids: array
│   ├── joinedCount: number
│   ├── city: string (auto-detected)
│   ├── visibility: string (open|private)
│   ├── shareCode: string (if private)
│   ├── cancelled: boolean
│   ├── createdAt: timestamp
│   ├── meetingLat/Lng: number
│   ├── startLat/Lng: number (optional)
│   ├── endLat/Lng: number (optional)
│   ├── photoUrls: array
│   │
│   ├── allowed (subcollection) - Private walk access
│   │   └── {userId}
│   │       ├── uid: string
│   │       ├── redeemedAt: timestamp
│   │
│   └── messages (subcollection) - Chat messages
│       └── {messageId}
│           ├── userId: string
│           ├── text: string
│           ├── createdAt: timestamp
│           ├── userName: string

/reviews
├── {reviewId}
│   ├── walkId: string
│   ├── userId: string
│   ├── userName: string
│   ├── userProfileUrl: string (optional)
│   ├── rating: number (1-5)
│   ├── reviewText: string (≤500 chars)
│   ├── createdAt: timestamp
│   ├── helpfulCount: number
│   ├── helpfulBy: array

/users
├── {userId}
│   ├── uid: string
│   ├── email: string
│   ├── displayName: string
│   ├── photoURL: string (optional)
│   ├── bio: string (optional)
│   ├── createdAt: timestamp
│   ├── lastUpdated: timestamp
│   │
│   ├── stats (subcollection)
│   │   ├── walkStats (document)
│   │   │   ├── totalWalksCompleted: number
│   │   │   ├── totalWalksHosted: number
│   │   │   ├── totalDistanceKm: number
│   │   │   ├── averageDistanceKm: number
│   │   │   ├── totalWalkMinutes: number
│   │   │   ├── monthlyStats: map
│   │   │   └── lastUpdated: timestamp
│   │   │
│   │   └── hostRating (document)
│   │       ├── rating: number (1-5)
│   │       ├── reviewCount: number
│   │       ├── totalRatingPoints: number
│   │       └── lastUpdated: timestamp
│   │
│   ├── walks (subcollection) - Participation history (CP-4)
│   │   └── {walkId}
│   │       ├── userId: string
│   │       ├── joinedAt: timestamp
│   │       ├── completed: boolean
│   │       ├── leftEarly: boolean
│   │       ├── actualDistanceKm: number
│   │       └── notes: string (optional)
│   │
│   ├── fcmTokens (subcollection) - Push notification tokens (CP-3)
│   │   └── {token}
│   │       ├── token: string
│   │       ├── createdAt: timestamp
│   │       └── platform: string (android|ios|web)
│   │
│   └── badges (subcollection)
│       └── {badgeId}
│           ├── name: string
│           ├── description: string
│           └── unlockedAt: timestamp
```

---

## 🔐 Security Model (firestore.rules)

### **Key Principles:**
1. **Authentication Required:** Most operations require `request.auth != null`
2. **User Isolation:** Users can only read/write their own documents
3. **Walk Visibility:**
   - Public walks: Anyone can read
   - Private walks: Only host or allowed users can read
4. **Participation Tracking:** Users can record their walk participation
5. **Stats & Ratings:** Automatically maintained by Cloud Functions

### **Key Rules:**
```
/users/{userId}
  - GET: If user is authenticated
  - CREATE: If creating own user (uid == request.auth.uid)
  - UPDATE: If updating own user
  - DELETE: Server-side only (not allowed via client)

/walks/{walkId}
  - GET: If walk is open OR user is host OR user has access
  - CREATE: If user is host (hostUid == request.auth.uid)
  - UPDATE: If user is host
  - DELETE: Not allowed (use cancelled flag instead)

/users/{userId}/walks/{walkId}
  - CREATE/UPDATE: If user is authenticated (tracking own participation)

/users/{userId}/stats/*
  - READ: If user is authenticated
  - WRITE: Server-side only (Cloud Functions write these)

/reviews
  - READ: Anyone (public reviews)
  - CREATE: If user is authenticated
  - UPDATE: If user created the review
```

---

## 🚀 Environment Variables (.env)

**Location:** `d:\yalla_nemshi\.env` (create this file locally)

```env
# Google Maps API
GOOGLE_MAPS_API_KEY=your_api_key_here

# Firebase (web only - native uses google-services.json)
FIREBASE_API_KEY=AIzaSyBNZj_FBNB1L3V8UAVUScTrjpCWDc8lTT8
FIREBASE_AUTH_DOMAIN=yallanemshiapp.firebaseapp.com
FIREBASE_PROJECT_ID=yallanemshiapp
FIREBASE_STORAGE_BUCKET=yallanemshiapp.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=695876088604
FIREBASE_APP_ID=1:695876088604:web:d7b5d37c1ff68131dcc0d9

# Google Sign-In (Android)
GOOGLE_SIGN_IN_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
```

**⚠️ IMPORTANT:** Never commit `.env` to git! It's in `.gitignore`.

---

## 📱 Platform-Specific Configuration

### **Android** (`android/app/google-services.json`)
- Provided by Firebase Console
- Contains signing certificates
- Referenced in `android/app/build.gradle.kts`
- Do not commit to git (sensitive data)

### **iOS** (`ios/Runner` project)
- Firebase pod installed via CocoaPods
- APNs certificate required for push notifications
- Configure in Xcode: Runner → Signing & Capabilities

### **Web**
- Firebase config hardcoded in `lib/main.dart`
- No google-services.json needed
- .env file used for sensitive keys

---

## 🔔 Cloud Functions Deployment

### **Prerequisites:**
- Firebase project on **Blaze plan** (pay-as-you-go)
- Firebase CLI installed: `npm install -g firebase-tools`
- Authenticated: `firebase login`

### **Deploy:**
```bash
cd d:\yalla_nemshi
firebase deploy --only functions
```

### **What Gets Deployed:**
1. **onWalkJoined** - Notify host when user joins
2. **onWalkCancelled** - Notify participants when walk cancelled
3. **onWalkUpdated** - Notify when walk details change
4. **onChatMessage** - Notify chat participants

### **Function Triggers:**
```
onWalkJoined      → Firestore write to /users/{userId}/walks/{walkId}
onWalkCancelled   → Firestore update to /walks/{walkId} (cancelled=true)
onWalkUpdated     → Firestore update to /walks/{walkId} (selected fields)
onChatMessage     → Firestore write to /walks/{walkId}/messages/{messageId}
```

---

## 💰 Firestore Pricing (Blaze Plan)

### **Free Tier (Included Monthly):**
- 50K read operations
- 20K write operations  
- 20K delete operations
- 1GB storage
- 1GB network egress
- 2M Cloud Function invocations
- 40K GB-seconds

### **Estimated Costs at Scale:**
| Monthly Active Users | Estimated Cost |
|---------------------|-----------------|
| 1,000 | $0 |
| 10,000 | $2-5 |
| 50,000 | $10-15 |
| 100,000 | $20-30 |

**Note:** Most apps stay in free tier for 6-12 months.

---

## 🔍 Monitoring & Debugging

### **In Firebase Console:**
- **Firestore Usage:** Analytics → Query Stats
- **Cloud Functions:** Functions → Logs
- **Crashes:** Crashlytics → Dashboard
- **Performance:** Performance monitoring (optional)

### **Local Testing with Emulator:**
```bash
firebase emulators:start
```

Then in Flutter:
```dart
// Use emulator for local development
if (kDebugMode && !kIsWeb) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

---

## 🆘 Common Issues

### **Issue:** "Cloud Functions not available"
**Cause:** Project on Spark plan
**Fix:** Upgrade to Blaze plan (requires credit card, but stays free under limits)

### **Issue:** "Permission denied" on Firestore write
**Cause:** Security rules blocking operation
**Fix:** Check `firestore.rules` - ensure user is authenticated and authorized

### **Issue:** "FCM token not storing"
**Cause:** Cloud Functions not deployed yet
**Fix:** Deploy functions: `firebase deploy --only functions`

### **Issue:** "Service account key exposed in git"
**Status:** Already fixed! See git history for remediation
**Prevention:** Added `secrets/` folder and `*firebase-adminsdk*.json` to `.gitignore`

---

## 📚 Related Documentation

- [Firestore Security Rules](../firestore.rules)
- [Cloud Functions Code](../functions/index.js)
- [Notification Service](../lib/services/notification_service.dart)
- [ERROR_HANDLING_GUIDE.md](./ERROR_HANDLING_GUIDE.md)
- [PROVIDERS_GUIDE.md](./PROVIDERS_GUIDE.md)

---

**Last Updated:** January 14, 2026  
**Maintained By:** Yalla Nemshi Team

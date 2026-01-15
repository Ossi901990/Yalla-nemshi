# Architecture Overview

## System Design & Component Structure

This document describes the high-level architecture of Yalla Nemshi and how different components interact.

---

## 🏗️ System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          User Devices                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Android    │  │     iOS      │  │     Web      │               │
│  │    App       │  │     App      │  │  (Browser)   │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
└─────────┼───────────────────┼────────────────┼─────────────────────┘
          │                   │                │
          └───────────────────┼────────────────┘
                              │
          ┌───────────────────┴────────────────┐
          │   Firebase SDK (Dart/Flutter)      │
          │   - Auth, Firestore, Storage, FCM  │
          └───────────────────┬────────────────┘
                              │
          ┌───────────────────┴────────────────┐
          │                                    │
      ┌───▼──────┐                  ┌─────────▼─────┐
      │ Firebase │                  │  Google APIs  │
      │   Core   │                  │               │
      │          │                  │  - Maps       │
      │ - Auth   │                  │  - Geolocation│
      │ - Store  │                  │  - Sign-In    │
      │ - Msg    │                  └───────────────┘
      └───┬──────┘
          │
      ┌───▼──────────────────────────┐
      │   Cloud Functions (Node.js)   │
      │   - onWalkJoined              │
      │   - onWalkCancelled           │
      │   - onWalkUpdated             │
      │   - onChatMessage             │
      └───────────────────────────────┘
```

---

## 📦 App Layer Architecture

### **Presentation Layer (UI)**
```
┌─────────────────────────────────────────┐
│ Screens (lib/screens/)                   │
├─────────────────────────────────────────┤
│ LoginScreen                             │
│ SignupScreen                            │
│ HomeScreen          ← Main walk list     │
│ WalkDetailsScreen   ← Walk info & chat   │
│ ProfileScreen       ← User stats & bio   │
│ SettingsScreen      ← Preferences        │
│ MapScreen           ← Walk route display │
└─────────────────────────────────────────┘
          ↑
          │ (reads/listens to state)
          │
┌─────────────────────────────────────────┐
│ Widgets (lib/widgets/)                   │
├─────────────────────────────────────────┤
│ WalkCard        ← Reusable walk tile     │
│ UserAvatar      ← Profile picture        │
│ RatingBar       ← Star rating display    │
│ ChatBubble      ← Message display        │
│ CustomButton    ← Styled button          │
└─────────────────────────────────────────┘
```

### **State Management (Riverpod)**
```
┌─────────────────────────────────────────┐
│ Providers (lib/providers/)               │
├─────────────────────────────────────────┤
│ AuthProvider        ← User login state   │
│ WalksProvider       ← Walks list         │
│ UserProvider        ← Current user data  │
│ LocationProvider    ← GPS location       │
│ ThemeProvider       ← Light/dark mode    │
│ NotificationProvider ← Pref toggles     │
└─────────────────────────────────────────┘
          ↑
          │ (watches/updates)
          │
┌─────────────────────────────────────────┐
│ Services (lib/services/)                 │
├─────────────────────────────────────────┤
│ AuthService         ← Email/Google auth │
│ LocationService     ← GPS + geocoding    │
│ NotificationService ← FCM + permissions │
│ StorageService      ← Photos upload      │
│ AppPreferences      ← Local storage      │
└─────────────────────────────────────────┘
          ↑
          │ (calls)
          │
┌─────────────────────────────────────────┐
│ Repositories (lib/models/repositories/) │
├─────────────────────────────────────────┤
│ FirestoreRepository ← Walk & user data   │
│ AuthRepository      ← Auth operations    │
│ StorageRepository   ← Photo upload       │
└─────────────────────────────────────────┘
          ↑
          │ (reads/writes)
          │
    Firebase SDK
```

---

## 🔄 Data Flow Examples

### **User Login Flow:**
```
1. LoginScreen
   ├─ User enters email + password
   ├─ Taps "Login" button
   └─ Calls AuthProvider.login()
   
2. AuthProvider (Riverpod)
   ├─ Calls AuthService.loginWithEmail()
   └─ Updates state: loading → authenticated
   
3. AuthService
   ├─ Calls FirebaseAuth.signInWithEmailAndPassword()
   ├─ Gets user UID
   └─ Returns user data
   
4. LoginScreen (rebuilds)
   ├─ Watches AuthProvider
   ├─ Sees authenticated = true
   └─ Navigates to HomeScreen
```

### **Fetch Walks List Flow:**
```
1. HomeScreen
   ├─ Renders initially
   ├─ Watches WalksProvider
   └─ Shows loading spinner
   
2. WalksProvider (Riverpod)
   ├─ Fetches from FirestoreRepository
   ├─ Listens to realtime updates
   └─ Emits: loading → data
   
3. FirestoreRepository
   ├─ Queries Firestore: /walks
   ├─ Filters by city (auto-detected)
   ├─ Filters by date (future only)
   ├─ Streams results
   └─ Returns List<WalkEvent>
   
4. HomeScreen (rebuilds)
   ├─ Receives walk list
   ├─ Maps to WalkCard widgets
   └─ User can see all walks
```

### **Join Walk Flow:**
```
1. WalkDetailsScreen
   ├─ User views walk
   ├─ Taps "Join Walk"
   └─ Calls WalksProvider.joinWalk(walkId)
   
2. WalksProvider
   ├─ Calls FirestoreRepository.joinWalk()
   └─ Emits: loading → joined
   
3. FirestoreRepository
   ├─ Creates: /users/{userId}/walks/{walkId}
   ├─ Updates: /walks/{walkId} (increment joinedCount)
   └─ Returns success
   
4. Cloud Function: onWalkJoined (auto-triggered)
   ├─ Detects new participation record
   ├─ Fetches host FCM tokens
   ├─ Sends FCM: "Ahmed joined your walk"
   └─ Host's device shows notification
   
5. WalksProvider (rebuilds)
   ├─ Listens to Firestore updates
   ├─ Sees new participant
   └─ Updates UI: "Joined ✓"
```

---

## 📊 Data Models

### **Walk Model** (lib/models/walk_event.dart)
```dart
class WalkEvent {
  String id;                    // Unique walk ID
  String title;                 // Walk name
  DateTime dateTime;            // When walk happens
  double? distanceKm;           // Expected distance
  String gender;                // Mixed | Women | Men
  String pace;                  // Relaxed | Normal | Brisk
  String hostUid;               // Who created walk
  String hostName;              // Host's display name
  String? hostPhotoUrl;         // Host's profile pic
  List<String> joinedUserUids;  // Who joined
  int joinedCount;              // Participant count
  String city;                  // Auto-detected location
  String visibility;            // open | private
  String? shareCode;            // If private walk
  bool cancelled;               // Is walk cancelled?
  Timestamp createdAt;          // When created
  double meetingLat, meetingLng; // Meeting location
  double? startLat, startLng;   // Optional route start
  double? endLat, endLng;       // Optional route end
  List<String> photoUrls;       // Walk photos
  
  // Subcollections (not in main doc):
  // - messages/{messageId}     ← Chat messages
  // - allowed/{userId}         ← Private walk access
}
```

### **User Model** (lib/models/firestore_user.dart)
```dart
class FirestoreUser {
  String uid;                   // Firebase UID
  String email;                 // User email
  String displayName;           // Full name
  String? photoURL;             // Profile picture URL
  String? bio;                  // User bio (≤160 chars)
  Timestamp createdAt;          // Account creation date
  Timestamp lastUpdated;        // Last profile update
  
  // Subcollections (not in main doc):
  // - stats/walkStats          ← Walk statistics
  // - stats/hostRating         ← Host rating
  // - walks/{walkId}           ← Participation history
  // - fcmTokens/{token}        ← Push notification tokens
  // - badges/{badgeId}         ← Achievements
}
```

### **Message Model** (lib/models/chat_message.dart)
```dart
class ChatMessage {
  String userId;                // Who sent message
  String userName;              // Sender's display name
  String text;                  // Message content
  Timestamp createdAt;          // When sent
  
  // Stored in: /walks/{walkId}/messages/{messageId}
}
```

### **Review Model** (lib/models/review.dart)
```dart
class Review {
  String id;                    // Review ID
  String walkId;                // Which walk
  String userId;                // Who reviewed
  String userName;              // Reviewer's name
  String? userProfileUrl;       // Reviewer's pic
  int rating;                   // 1-5 stars
  String reviewText;            // Review comment (≤500 chars)
  Timestamp createdAt;          // When posted
  int helpfulCount;             // Upvotes
  List<String> helpfulBy;       // Who upvoted
}
```

---

## 🌳 Folder Structure Explained

```
lib/
├── main.dart                   ← Entry point, Firebase init, routes
│
├── theme_controller.dart       ← Global theme provider
│
├── screens/                    ← UI screens (one per file)
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart
│   ├── walk_details_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   └── map_screen.dart
│
├── widgets/                    ← Reusable UI components
│   ├── walk_card.dart
│   ├── user_avatar.dart
│   ├── rating_bar.dart
│   ├── chat_bubble.dart
│   └── custom_button.dart
│
├── models/                     ← Data classes
│   ├── walk_event.dart         ← Walk data model
│   ├── firestore_user.dart     ← User data model
│   ├── chat_message.dart       ← Chat message model
│   ├── review.dart             ← Review model
│   └── repositories/
│       ├── firestore_repository.dart  ← Firestore CRUD
│       └── auth_repository.dart       ← Auth operations
│
├── providers/                  ← Riverpod state management
│   ├── auth_provider.dart      ← Login/signup state
│   ├── walks_provider.dart     ← Walks list state
│   ├── user_provider.dart      ← Current user state
│   └── location_provider.dart  ← GPS state
│
├── services/                   ← Platform integrations
│   ├── notification_service.dart ← FCM + permissions
│   ├── location_service.dart     ← GPS + geocoding
│   ├── storage_service.dart      ← Photo upload
│   ├── auth_service.dart         ← Email/Google auth
│   └── app_preferences.dart      ← Local storage
│
└── utils/                      ← Helper functions
    ├── constants.dart          ← App constants
    ├── validators.dart         ← Input validation
    └── extensions.dart         ← Dart extensions
```

---

## 🔌 External Dependencies

### **Firebase (Backend)**
```yaml
firebase_core: ^4.2.1          # Firebase initialization
firebase_auth: ^4.6.1          # Email/password + Google auth
cloud_firestore: ^6.1.0        # Realtime database
firebase_storage: ^11.1.0      # Photo uploads
firebase_messaging: ^16.0.4    # Push notifications
firebase_crashlytics: ^3.2.0   # Crash reporting
```

### **UI & State Management**
```yaml
flutter_riverpod: ^2.4.0       # State management
riverpod_generator: ^2.3.0     # Riverpod code gen
google_maps_flutter: ^2.3.0    # Maps integration
```

### **Platform & Device**
```yaml
geolocator: ^10.0.0            # GPS location
geocoding: ^2.1.0              # Address lookup
google_sign_in: ^6.1.0         # Google login
image_picker: ^1.0.0           # Photo selection
flutter_local_notifications: ^14.0.0 # Local notifications
permission_handler: ^11.4.0    # Device permissions
```

### **Utilities**
```yaml
flutter_dotenv: ^5.1.0         # .env file support
intl: ^0.19.0                  # Date/time formatting
```

---

## 🚀 Key Design Patterns

### **1. Repository Pattern**
```
UI Screen
   ↓
Provider (Riverpod)
   ↓
Service (e.g., AuthService)
   ↓
Repository (e.g., AuthRepository)
   ↓
Firebase SDK
```

**Benefit:** Easy to mock services for testing, clean separation of concerns

### **2. Provider/Consumer Pattern (Riverpod)**
```dart
// Define provider
final walksProvider = StreamProvider<List<WalkEvent>>((ref) {
  return repo.streamWalks();
});

// Use in UI
Consumer(
  builder: (context, ref, child) {
    final walks = ref.watch(walksProvider);
    // Automatically rebuilds when walks change
  }
)
```

**Benefit:** Automatic caching, dependency injection, easy testing

### **3. Singleton Services**
```dart
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._();
  
  // Access globally
  NotificationService.instance.init();
}
```

**Benefit:** Single instance throughout app lifecycle, easy access

### **4. Model Classes with Freezed (Optional)**
```dart
@freezed
class WalkEvent with _$WalkEvent {
  const factory WalkEvent({
    required String id,
    required String title,
    required DateTime dateTime,
  }) = _WalkEvent;
  
  factory WalkEvent.fromJson(Map<String, dynamic> json) =>
      _$WalkEventFromJson(json);
}
```

**Benefit:** Automatic copyWith, equality, toString (if used)

---

## 🔐 Security Architecture

### **Authentication Flow**
```
User enters credentials → AuthService.login()
   ↓
FirebaseAuth.signInWithEmailAndPassword()
   ↓
Firebase validates credentials
   ↓
Returns User (UID + email + metadata)
   ↓
Store in local secure storage (via Riverpod)
   ↓
Subsequent requests include UID in headers
```

### **Firestore Security**
```
Every read/write goes through firestore.rules:
   ├─ Is user authenticated? (request.auth != null)
   ├─ Can user access this resource? (userId check)
   ├─ Is operation allowed? (read/write permissions)
   └─ Return allowed/denied
```

### **FCM Token Management**
```
User logs in → NotificationService.init()
   ↓
Request iOS/Android permissions
   ↓
Get FCM token from Firebase Cloud Messaging
   ↓
Store in Firestore: /users/{userId}/fcmTokens/{token}
   ↓
Token auto-refreshes → Stored in Firestore
   ↓
Cloud Functions fetch tokens and send notifications
   ↓
User logs out → NotificationService.deleteToken()
   ├─ Remove tokens from Firestore
   └─ Prevent notifications after logout
```

---

## 📈 Scaling Considerations

### **Current Architecture Limits**
| Component | Limit | Status |
|-----------|-------|--------|
| Firestore reads | 50K/day free | Plenty for MVP |
| Firestore writes | 20K/day free | Sufficient |
| FCM messages | 2M/month free | 66K/day possible |
| Cloud Functions | 2M invocations/month | Enough for 60+ walks/day |
| Storage | 5GB free | Photos stored efficiently |

### **When to Optimize**
- **> 1,000 concurrent users:** Consider Firestore indexes
- **> 10,000 walks/month:** Implement walk archive/deletion
- **> 100K messages/month:** Consider chat pagination
- **> 50GB storage:** Implement photo compression

### **Optimization Strategies**
1. **Firestore Indexes** - Already created for common queries
2. **Caching** - Riverpod providers cache data automatically
3. **Pagination** - Load walks 10 at a time (not all)
4. **Photo Compression** - Resize before upload (see StorageService)
5. **Cloud Functions Optimization** - Batch notifications when possible

---

## 🧪 Testing Architecture

```
Unit Tests (lib services/models)
   ├─ Auth logic
   ├─ Location processing
   └─ Data validation

Widget Tests (screens/widgets)
   ├─ Button actions
   ├─ Form validation
   └─ Navigation

Integration Tests (full flows)
   ├─ Login → Home → Join Walk
   ├─ Chat message send
   └─ Settings save/load

E2E Tests (on real device)
   ├─ Full user journey
   ├─ Notification delivery
   └─ Performance benchmarks
```

See [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) for details.

---

## 📚 Related Documentation

- [Firebase Setup Guide](./FIREBASE_SETUP.md) - Backend configuration
- [API Documentation](./API_DOCUMENTATION.md) - Cloud Functions reference
- [Git Workflow](./GIT_WORKFLOW.md) - Development process
- [Testing Strategy](./TESTING_STRATEGY.md) - How to test
- [Monitoring & Troubleshooting](./MONITORING_TROUBLESHOOTING.md) - Debug guide

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team

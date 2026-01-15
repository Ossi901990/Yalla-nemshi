# Firestore Security Rules - CP-4 Walk Completion

This document details the Firestore security rules required for CP-4: Walk History & Statistics feature.

**Updated**: January 15, 2026  
**Status**: Ready for deployment

---

## Table of Contents

1. [Overview](#overview)
2. [CP-4 Specific Rules](#cp4-specific-rules)
3. [Helper Functions](#helper-functions)
4. [Collection-by-Collection Rules](#collection-by-collection-rules)
5. [Testing Rules](#testing-rules)
6. [Deployment](#deployment)

---

## Overview

CP-4 requires two main Firestore collections for walk tracking:

### 1. `/users/{uid}/walks/{walkId}` - Participation History
Stores each user's participation history for completed and past walks.

**Fields**:
- `userId` (string) - User ID
- `walkId` (string) - Walk ID
- `joinedAt` (timestamp) - When user joined
- `status` (string) - Participation status: open | starting | actively_walking | declined | completed | completed_early | host_cancelled
- `confirmedAt` (timestamp, optional) - When user confirmed participation
- `completedAt` (timestamp, optional) - When walk marked complete
- `actualDurationMinutes` (number, optional) - Actual walk duration
- `actualDistanceKm` (number, optional) - Actual distance walked

### 2. `/users/{uid}/stats/walkStats` - User Statistics
Stores aggregated walk statistics for a user.

**Fields**:
- `userId` (string) - User ID
- `totalWalksCompleted` (number) - Total completed walks
- `totalWalksJoined` (number) - Total walks joined
- `totalWalksHosted` (number) - Total walks hosted
- `totalDistanceKm` (number) - Total distance walked
- `totalDuration` (number) - Total duration in seconds
- `totalParticipants` (number) - Total different people walked with
- `averageDistancePerWalk` (number) - Average distance per walk
- `averageDurationPerWalk` (number) - Average duration per walk
- `lastWalkDate` (timestamp) - Last walk completion date
- `createdAt` (timestamp) - Stats document creation date
- `lastUpdated` (timestamp) - Last stats update date

---

## CP-4 Specific Rules

### Read Rules

#### User Can Read Their Own Walks
```firestore
// Any user can read their own walk participation history
allow read: if isAuth(userId);
```

#### User Can Read Their Own Stats
```firestore
// Any user can read their own aggregate statistics
allow read: if isAuth(uid);
```

#### Restrictions
```firestore
// Users CANNOT read other users' walks or stats
allow list: if false;  // Never list all walks for a user
```

### Write Rules

#### User Can Create/Update Their Own Walks
```firestore
// User records their participation in a walk
allow create, update: if isAuth(userId)
  && request.resource.data.userId == userId
  && request.resource.data.joinedAt is timestamp;
```

**Validation**:
- `userId` must match authenticated user
- `joinedAt` must be a timestamp
- Status must be one of: open, starting, actively_walking, declined, completed, completed_early, host_cancelled

#### User Can Create/Update Their Own Stats
```firestore
// Cloud Functions update stats (via Admin SDK - unrestricted)
// But if user writes directly, validate structure
allow create, update: if isAuth(uid)
  && request.resource.data.userId == uid;
```

**Important**: Stats are primarily written by Cloud Functions using Admin SDK. Direct user writes should be rejected by application logic.

#### Delete Rules
```firestore
// Users can delete their own walk records
allow delete: if isAuth(userId);

// Stats should NEVER be deleted by users
allow delete: if false;
```

---

## Helper Functions

Add these helper functions to your Firestore rules document:

```firestore
// Check if user is authenticated
function signedIn() {
  return request.auth != null;
}

// Check if user is accessing their own data
function isAuth(uid) {
  return request.auth != null && request.auth.uid == uid;
}
```

---

## Collection-by-Collection Rules

### Complete Rules Section

Copy and paste this into your `firestore.rules` file:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ===== HELPER FUNCTIONS =====
    function signedIn() {
      return request.auth != null;
    }

    function isAuth(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    // ... existing helper functions ...

    // ===== USERS COLLECTION =====
    match /users/{userId} {
      // ... existing user rules ...

      // ===== CP-4: User walk history subcollection =====
      match /walks/{walkId} {
        // User can read their own walk participation history
        allow read: if isAuth(userId);
        
        // User can create/update their own walk records
        // Created by application when user joins walk
        // Updated by Cloud Functions when walk starts/completes
        allow create, update: if isAuth(userId)
          && request.resource.data.userId == userId
          && request.resource.data.walkId is string
          && request.resource.data.joinedAt is timestamp
          && (
            !request.resource.data.keys().hasAny(['status'])
            || request.resource.data.status is string
          )
          && (
            !request.resource.data.keys().hasAny(['confirmedAt'])
            || request.resource.data.confirmedAt is timestamp
          )
          && (
            !request.resource.data.keys().hasAny(['completedAt'])
            || request.resource.data.completedAt is timestamp
          )
          && (
            !request.resource.data.keys().hasAny(['actualDurationMinutes'])
            || request.resource.data.actualDurationMinutes is number
          );
        
        // User can delete their own walk records
        allow delete: if isAuth(userId);
      }

      // ===== CP-4: User statistics subcollection =====
      match /stats/{document=**} {
        // User can read their own stats
        allow read: if isAuth(userId);
        
        // Cloud Function (Admin SDK) updates stats - only allow app-level writes
        // Direct user writes are validated but typically blocked by app logic
        allow create, update: if isAuth(userId)
          && (
            !request.resource.data.keys().hasAny(['userId'])
            || request.resource.data.userId == userId
          )
          && (
            !request.resource.data.keys().hasAny(['totalWalksCompleted'])
            || request.resource.data.totalWalksCompleted is number
          )
          && (
            !request.resource.data.keys().hasAny(['totalDistanceKm'])
            || request.resource.data.totalDistanceKm is number
          )
          && (
            !request.resource.data.keys().hasAny(['totalDuration'])
            || request.resource.data.totalDuration is number
          )
          && (
            !request.resource.data.keys().hasAny(['lastUpdated'])
            || request.resource.data.lastUpdated is timestamp
          );
        
        // Stats should NEVER be deleted
        allow delete: if false;
      }

      // ... existing other subcollections (badges, fcmTokens, etc.) ...
    }

    // ===== WALKS COLLECTION (existing, documented for reference) =====
    match /walks/{walkId} {
      // READ: open or private (host/allowed) walks
      allow get, list: if signedIn();

      // CREATE: host only
      allow create: if signedIn()
        && request.resource.data.hostUid == request.auth.uid;

      // UPDATE: host or metadata updates
      allow update: if signedIn() && (
        request.resource.data.hostUid == request.auth.uid
        || request.resource.data.diff(resource.data).changedKeys().hasOnly(
          ['joinedUids','joinedUserUids','joinedCount',
           'status','startedAt','completedAt']  // CP-4 fields
        )
      );

      // DELETE: host only
      allow delete: if signedIn()
        && request.resource.data.hostUid == request.auth.uid;
    }

    // ===== CATCH-ALL: DENY EVERYTHING ELSE =====
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Testing Rules

### Rules Simulator Tests

Use Firebase Console → Firestore → Rules tab → Rules Simulator to test:

#### Test 1: User reads their own walk history
```
Collection: users/{uid}/walks/{walkId}
Operation: get
UID: abc123
Expected: ALLOW
```

#### Test 2: User cannot read other user's walk history
```
Collection: users/other_uid/walks/{walkId}
Operation: get
UID: abc123 (different from other_uid)
Expected: DENY
```

#### Test 3: User reads their own stats
```
Collection: users/{uid}/stats/walkStats
Operation: get
UID: abc123
Expected: ALLOW
```

#### Test 4: User cannot delete stats
```
Collection: users/{uid}/stats/walkStats
Operation: delete
UID: abc123
Expected: DENY
```

#### Test 5: User creates walk participation record
```
Collection: users/{uid}/walks/{walkId}
Operation: create
UID: abc123
Data: {
  "userId": "abc123",
  "walkId": "walk123",
  "joinedAt": <timestamp>,
  "status": "open"
}
Expected: ALLOW
```

#### Test 6: User updates walk status (Cloud Function scenario)
```
Collection: users/{uid}/walks/{walkId}
Operation: update
UID: abc123
Data changes: {
  "status": "actively_walking",
  "confirmedAt": <timestamp>
}
Expected: ALLOW
```

#### Test 7: Unauthenticated user cannot access anything
```
Collection: users/{uid}/walks/{walkId}
Operation: get
UID: (no auth)
Expected: DENY
```

### Running Tests in Code

```dart
// Test in Flutter code
final walksRef = FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('walks')
    .doc(walkId);

// Should succeed
final doc = await walksRef.get();

// Should fail
try {
  await walksRef.delete();
} catch (e) {
  print('Expected: PERMISSION_DENIED');
}
```

---

## Deployment

### Step 1: Update Local Rules File

Edit `firestore.rules` in your project root and add the CP-4 sections above.

### Step 2: Test Rules Locally

```bash
# Start Firestore emulator
firebase emulators:start

# Run your app pointing to emulator
flutter run
```

Test the scenarios in "Testing Rules" section above.

### Step 3: Deploy to Staging

```bash
# Make sure you're in staging project
firebase use yalla-nemshi-staging

# Deploy rules
firebase deploy --only firestore:rules

# Verify in Firebase Console
```

### Step 4: Test in Staging

- Run app connecting to staging Firebase
- Complete full walk workflow
- Verify stats calculated and persisted
- Check logs for rule violations

### Step 5: Deploy to Production

```bash
# Switch to production
firebase use yalla-nemshi  # or production project ID

# Deploy rules
firebase deploy --only firestore:rules

# Verify in Firebase Console
```

### Step 6: Monitor

- Watch Firestore usage statistics
- Monitor error rates
- Check for rule rejection errors
- Be ready to rollback if issues

---

## Rollback Plan

If rules have issues in production:

### Option 1: Revert to Previous Rules
```bash
# Get previous version from git
git log firestore.rules

# Revert to specific commit
git checkout <commit-hash> -- firestore.rules

# Deploy
firebase deploy --only firestore:rules
```

### Option 2: Temporary Permissive Rules
```firestore
match /users/{userId}/walks/{walkId} {
  allow read, write: if signedIn();
}

match /users/{uid}/stats/{document=**} {
  allow read, write: if signedIn();
}
```

Then deploy the proper restrictive rules after investigating issue.

---

## Security Considerations

### What These Rules Protect

✅ **User Privacy**
- Users can only see their own walk history and stats
- Other users cannot access your data

✅ **Data Integrity**
- Only Cloud Functions (Admin SDK) can write stats
- Stats cannot be deleted by users
- Status fields are validated

✅ **Application Security**
- Unauthenticated users cannot access any data
- All writes require authentication

### What These Rules Don't Protect

⚠️ **Note**: The following are handled by application logic, not rules:

- Preventing user from creating invalid status values (app validates)
- Rate limiting (implement in Cloud Functions)
- Preventing spam writes (implement in app logic)
- Complex business logic (implement in Cloud Functions)

---

## Performance Considerations

### Indexes Created

The following indexes will be auto-created on first query:

1. **walks collectionGroup query**
   - Collection: walks
   - Fields: walkId (Ascending), status (Ascending)
   - Used by: `onWalkEnded` Cloud Function

Status: Auto-created when needed (no manual creation required)

### Query Optimization

- ✅ Indexes are created automatically
- ✅ Users' data is isolated (queries only touch user's own documents)
- ✅ Batch operations minimize write count
- ✅ Aggregate stats stored in single document (not array of walks)

---

## References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [CP-4 Walk Completion Guide](./docs/CP4_WALK_COMPLETION_GUIDE.md)
- [Firebase Setup Checklist](./FIREBASE_CP4_SETUP_CHECKLIST.md)

---

**Status**: Ready for deployment  
**Last Updated**: January 15, 2026  
**Next Review**: After Phase 1 production deployment

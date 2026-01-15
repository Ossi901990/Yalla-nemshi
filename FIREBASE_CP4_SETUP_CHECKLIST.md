# Firebase Setup Checklist for CP-4

Complete this checklist to deploy CP-4: Walk History & Statistics to your Firebase project.

**Date**: January 15, 2026  
**Feature**: CP-4 Walk Completion & Statistics Tracking  
**Estimated Time**: 30-45 minutes

---

## 📋 Pre-Deployment Checklist

### Phase 1: Code Review ✅
- [x] All Dart code compiles without errors
- [x] All Cloud Functions created and validated
- [x] All services implemented
- [x] UI components added to screens
- [x] Documentation complete

### Phase 2: Firebase Project Setup

#### 2.1 Cloud Functions Deployment
- [ ] Navigate to `functions/` directory
- [ ] Run `npm install` to install dependencies (if needed)
- [ ] Verify `cp4_walk_completion.js` exists with all 4 functions:
  - [ ] `onWalkStarted`
  - [ ] `onWalkEnded`
  - [ ] `onUserLeftWalkEarly`
  - [ ] `onWalkAutoComplete`
- [ ] Deploy functions:
  ```bash
  cd functions
  npm install
  firebase deploy --only functions:onWalkStarted
  firebase deploy --only functions:onWalkEnded
  firebase deploy --only functions:onUserLeftWalkEarly
  firebase deploy --only functions:onWalkAutoComplete
  ```
- [ ] Verify deployment successful in Firebase Console → Cloud Functions
  - All 4 functions show status: ✓ Active (green checkmark)
  - Memory allocated: 256MB minimum
  - Timeout: 60 seconds minimum
- [ ] Check function logs for any initialization errors

#### 2.2 Firestore Security Rules
- [ ] Open Firebase Console → Firestore Database → Rules
- [ ] Verify existing rules include:
  ```
  match /users/{userId}/walks/{walkId} {
    allow read: if isAuth(userId);
    allow create, update: if isAuth(userId)
      && request.resource.data.userId == userId
      && request.resource.data.joinedAt is timestamp;
    allow delete: if isAuth(userId);
  }
  ```
- [ ] Add/verify stats subcollection rules:
  ```
  match /users/{uid}/stats/{document=**} {
    allow read: if isAuth(uid);
    allow create, update: if isAuth(uid);
    allow delete: if false;
  }
  ```
- [ ] Deploy rules (click "Publish" in console)
- [ ] Test read/write permissions in Rules Simulator:
  - [ ] Test: User can read own stats
  - [ ] Test: User can write own stats
  - [ ] Test: User cannot read other user's stats
  - [ ] Test: User cannot delete stats

#### 2.3 Firestore Indexes
Firestore will auto-create needed indexes on first query, or create manually:

**Index 1: For onWalkEnded collectionGroup query**
- [ ] Collection: `walks`
- [ ] Fields indexed:
  - `walkId` (Ascending)
  - `status` (Ascending)
- [ ] Query scope: Collection
- **Status**: Will be auto-created on first `onWalkEnded` trigger

**Index 2: For getActiveParticipantCount query**
- [ ] Collection: `walks` (via collectionGroup)
- [ ] Fields indexed:
  - `walkId` (Ascending)
  - `status` (Ascending)
- **Status**: Auto-created with Index 1

**Verification**:
- [ ] Firebase Console → Firestore → Indexes
- [ ] Check indexes are in "Enabled" status (not "Building" or "Error")
- [ ] Wait for all indexes to complete building before proceeding

#### 2.4 Firebase Cloud Messaging (FCM)
- [ ] Verify FCM is enabled: Firebase Console → Cloud Messaging
- [ ] Check notification credentials configured:
  - [ ] Android Firebase Config (google-services.json)
  - [ ] iOS Firebase Config (GoogleService-Info.plist)
  - [ ] Web FCM config (in main.dart)
- [ ] Test token registration:
  - [ ] Run app on Android device
  - [ ] Check Firestore: `/users/{uid}/fcmTokens` collection has entries
  - [ ] Run app on iOS device
  - [ ] Verify iOS tokens also appear in `/users/{uid}/fcmTokens`

---

## 🧪 Testing Phase

### Phase 3: Local Testing (Emulator)

#### 3.1 Firebase Emulator Suite Setup
- [ ] Install Firebase Emulator Suite:
  ```bash
  npm install -g firebase-tools
  firebase emulators:start
  ```
- [ ] Emulator UI runs on `http://localhost:4000`
- [ ] Firestore Emulator: `localhost:8080`
- [ ] Functions Emulator: `localhost:5001`
- [ ] Verify all emulators start successfully

#### 3.2 Local App Testing
- [ ] Connect Flutter app to emulator:
  - [ ] Android: Edit `lib/main.dart` to use emulator (if emulator detection code exists)
  - [ ] iOS: Configure emulator connection
  - [ ] Web: Configure emulator connection
- [ ] Run app: `flutter run`
- [ ] Verify app connects to emulator (check logs)

#### 3.3 Test Walk Completion Flow
**Scenario 1: Host starts and completes walk**
- [ ] Host creates a walk (existing functionality)
- [ ] Host presses "Start Walk" button
  - [ ] Check Firestore Emulator: walk `status` changed to "starting"
  - [ ] Check Functions Emulator logs: `onWalkStarted` triggered
  - [ ] (Mock FCM - actual notifications won't work in emulator)
- [ ] Participant (different user) confirms participation
  - [ ] Check: `/users/{participantId}/walks/{walkId}` has `status: "actively_walking"`
  - [ ] Check: `confirmedAt` timestamp recorded
- [ ] Host presses "End Walk" button
  - [ ] Check: walk `status` changed to "completed"
  - [ ] Check Functions logs: `onWalkEnded` executed
  - [ ] Check: `/users/{participantId}/stats/walkStats` was created/updated
  - [ ] Verify stats contain:
    - [ ] `totalWalksCompleted` incremented
    - [ ] `totalDistanceKm` updated
    - [ ] `totalDuration` updated
    - [ ] `lastWalkDate` set to now

**Scenario 2: Participant declines**
- [ ] Host starts walk
- [ ] Participant presses "Decline" button
  - [ ] Check: status changed to "declined"
  - [ ] Check: not counted in active participants
- [ ] Host ends walk
  - [ ] Check: declined user not in stats update

**Scenario 3: Early departure**
- [ ] Participant confirms and starts walking
- [ ] Participant presses "Leave Walk" early
  - [ ] Check: status changed to "completed_early"
  - [ ] Check Functions logs: `onUserLeftWalkEarly` triggered
  - [ ] Check: stats updated with partial duration

#### 3.4 Profile Screen Stats Display
- [ ] Navigate to ProfileScreen
- [ ] Check "Lifetime stats" section visible (if user has completed walks)
- [ ] Verify displaying:
  - [ ] Total walks: 1
  - [ ] Distance: matches walk distance
  - [ ] Time: matches actual walk time
  - [ ] Average distance: calculated correctly
- [ ] Complete another walk
- [ ] Check stats update in real-time on ProfileScreen

---

## 🚀 Staging Environment Testing

### Phase 4: Staging Firebase Project

#### 4.1 Deploy to Staging
- [ ] Ensure you have staging Firebase project configured
- [ ] Switch to staging Firebase project:
  ```bash
  firebase use yalla-nemshi-staging  # or your staging project ID
  ```
- [ ] Deploy Cloud Functions:
  ```bash
  firebase deploy --only functions
  ```
- [ ] Verify functions deployed successfully
- [ ] Deploy Firestore rules:
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] Verify rules deployed

#### 4.2 Staging App Build
- [ ] Build and run staging app pointing to staging Firebase:
  - [ ] Verify Firebase project ID in code is staging project
  - [ ] Run on Android device: `flutter run --release`
  - [ ] Run on iOS device: `flutter run --release --ios`
- [ ] Create test user account in staging
- [ ] Verify FCM tokens being registered:
  - [ ] Firebase Console → Firestore → `users/{uid}/fcmTokens`
  - [ ] Should see token entries

#### 4.3 End-to-End Testing on Real Devices
- [ ] Test on Android device:
  - [ ] Start walk
  - [ ] Receive FCM notification
  - [ ] Confirm participation
  - [ ] End walk
  - [ ] Verify stats on profile
  
- [ ] Test on iOS device:
  - [ ] Request notification permissions
  - [ ] Start walk
  - [ ] Receive FCM notification
  - [ ] Confirm participation
  - [ ] End walk
  - [ ] Verify stats on profile

#### 4.4 Multi-Device Testing
- [ ] Test with 2+ devices simultaneously:
  - [ ] User A (host) starts walk
  - [ ] User B receives notification
  - [ ] User B confirms
  - [ ] Real-time participant count updates for User A
  - [ ] User A ends walk
  - [ ] Both users see updated stats

#### 4.5 Edge Cases
- [ ] Host cancels walk before start
  - [ ] Check: all participants marked as "host_cancelled"
- [ ] Host loses connection during walk
  - [ ] Try "Complete Walk Early" button
  - [ ] Check: stats still calculated correctly
- [ ] Participant joins without confirming
  - [ ] User doesn't press confirm/decline
  - [ ] Host ends walk
  - [ ] Check: user not marked as completed
- [ ] High participant count
  - [ ] Create walk with 10+ participants (test data)
  - [ ] Start walk
  - [ ] Check: all get notifications
  - [ ] End walk
  - [ ] Check: all stats calculated correctly (check logs)

---

## ⚠️ Common Issues & Troubleshooting

### Cloud Functions Not Triggering
- [ ] Check Cloud Function logs in Firebase Console
- [ ] Verify Firestore document is updated with correct path
- [ ] Verify trigger condition matches (e.g., `status: "starting"`)
- [ ] Check if function has required permissions (should auto-grant)
- [ ] Try manually triggering by updating Firestore document

### FCM Notifications Not Arriving
- [ ] Check FCM tokens registered in `/users/{uid}/fcmTokens`
- [ ] Verify Firebase Console → Cloud Messaging credentials configured
- [ ] Check device notification settings (not disabled in OS)
- [ ] Try uninstall/reinstall app to refresh token
- [ ] Check Cloud Function logs for send errors
- [ ] Test with real device (emulator won't receive notifications)

### Stats Not Updating
- [ ] Check Cloud Function `onWalkEnded` logs
- [ ] Verify Firestore rules allow write to `/users/{uid}/stats/walkStats`
- [ ] Check participant status is exactly `"actively_walking"` (case-sensitive)
- [ ] Manually test by creating test documents in Firestore Console
- [ ] Verify indexes are in "Enabled" state

### Firestore Rules Errors
- [ ] Test specific permission in Rules Simulator:
  - [ ] Use correct `userId` and `uid`
  - [ ] Simulate as authenticated user
  - [ ] Check "Explain" output for denial reasons
- [ ] Common issue: Missing `isAuth()` helper function
- [ ] Verify rules syntax with Firebase documentation

---

## ✅ Sign-Off Checklist

### Before Production Release
- [ ] All emulator tests passed ✅
- [ ] Staging environment fully tested ✅
- [ ] Real device testing completed (Android + iOS) ✅
- [ ] Multi-device scenarios tested ✅
- [ ] Edge cases handled ✅
- [ ] Cloud Function logs clean (no errors) ✅
- [ ] Firestore indexes in "Enabled" state ✅
- [ ] Security rules tested in simulator ✅
- [ ] FCM notifications working end-to-end ✅
- [ ] Stats displaying correctly in profile ✅
- [ ] Performance acceptable (response times < 2s) ✅
- [ ] No security issues found ✅

### Production Deployment
- [ ] Switch to production Firebase project
- [ ] Deploy Cloud Functions to production
- [ ] Deploy Firestore rules to production
- [ ] Verify production functions are active
- [ ] Monitor logs for first 24 hours
- [ ] Have rollback plan ready (backup of old functions)

---

## 📞 Support & Escalation

| Issue | Check | Action |
|-------|-------|--------|
| Function not triggering | Cloud Function logs | Check trigger path and condition |
| Notifications not arriving | FCM tokens collection | Verify tokens and permissions |
| Stats not saving | Firestore rules | Test in Rules Simulator |
| High latency | Function memory/timeout | Increase to 512MB / 120s |
| Database quota exceeded | Cloud Functions logs | Optimize batch writes |

---

## 📝 Notes

- Keep this checklist handy for debugging
- Update as you encounter issues
- Share findings with team
- Update documentation if new issues discovered

---

**Status**: Ready for testing  
**Last Updated**: January 15, 2026  
**Next Review**: After production deployment

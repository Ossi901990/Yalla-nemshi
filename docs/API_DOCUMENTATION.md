# API Documentation - Cloud Functions

## Overview

This document describes the backend APIs implemented via Firebase Cloud Functions for the Yalla Nemshi app.

---

## 🔄 Function Triggers & Data Flow

All functions are **Firestore-triggered** and execute automatically when documents are written/updated.

### **Architecture Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│                      Mobile App (Flutter)                    │
│  (user joins walk, sends message, host cancels walk, etc)   │
└─────────────────────────────────────────────────────────────┘
                           ↓
                   Firestore Document Write
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   Cloud Functions (Node.js)                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ 1. onWalkJoined (participation created)                 ││
│  │ 2. onWalkCancelled (walk.cancelled = true)              ││
│  │ 3. onWalkUpdated (walk details changed)                 ││
│  │ 4. onChatMessage (new message in walk chat)             ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              Firebase Cloud Messaging (FCM)                   │
│           (notifies all relevant users in real-time)         │
└─────────────────────────────────────────────────────────────┘
                           ↓
              ┌─────────────────────────┐
              │  Android/iOS/Web Client │
              │  (user sees notification)│
              └─────────────────────────┘
```

---

## 📨 Function 1: `onWalkJoined`

### **Trigger:**
```
Event: Document CREATE
Path:  /users/{userId}/walks/{walkId}
When:  User adds their uid to walk participation list
```

### **Fired After:**
```dart
// In app code:
walks.doc(walkId).update({
  'joinedUserUids': FieldValue.arrayUnion([currentUserId]),
  'joinedCount': FieldValue.increment(1),
});
```

### **Payload (Document that triggered):**
```json
{
  "userId": "user_123",
  "walkId": "walk_456",
  "joinedAt": "2026-01-15T10:30:00Z"
}
```

### **What It Does:**
1. ✅ Fetch walk details (title, time, location)
2. ✅ Fetch joiner's profile (name, photo)
3. ✅ Fetch host's FCM tokens
4. ✅ Skip notification if joiner is the host
5. ✅ Send notification: "**{joinerName}** joined your walk"
6. ✅ Clean up invalid/old tokens

### **Notification Details:**

**Title:** `{joinerName} joined your walk`

**Body:** `"{walkTitle}" at {location}`

**Data Payload:**
```json
{
  "action": "walk_joined",
  "walkId": "walk_456",
  "userId": "user_123"
}
```

**Tap Action:** Opens walk details screen with walkId

### **Error Handling:**
- **Walk not found:** Function exits silently (no notification)
- **Host has no tokens:** Notification skipped
- **Token invalid:** Token removed from Firestore, try next token
- **Network timeout:** Firestore logs error, Cloud Monitoring alerts

### **Performance:**
- Execution time: 500ms - 2s typical
- Cost: ~$0.00025 per invocation
- Timeout: 60 seconds

### **Code Location:**
[functions/index.js](../functions/index.js#L50-L100) - `onWalkJoined`

---

## 🚫 Function 2: `onWalkCancelled`

### **Trigger:**
```
Event: Document UPDATE
Path:  /walks/{walkId}
When:  Host sets cancelled = true
```

### **Fired After:**
```dart
// In app code:
walks.doc(walkId).update({
  'cancelled': true,
  'cancelledAt': Timestamp.now(),
});
```

### **Payload (Updated Document):**
```json
{
  "title": "Morning Walk in Downtown",
  "cancelled": true,
  "cancelledAt": "2026-01-15T09:00:00Z",
  "hostUid": "host_789",
  "joinedUserUids": ["user_123", "user_456", "user_789"],
  "joinedCount": 3
}
```

### **What It Does:**
1. ✅ Verify walk has been marked cancelled
2. ✅ Fetch all participant FCM tokens
3. ✅ Send notification to all **except host**
4. ✅ Message: "**{walkTitle}** has been cancelled"
5. ✅ Clean up invalid tokens

### **Notification Details:**

**Title:** `Walk cancelled: {walkTitle}`

**Body:** `The host has cancelled this walk. [Tap to view]`

**Data Payload:**
```json
{
  "action": "walk_cancelled",
  "walkId": "walk_456"
}
```

**Tap Action:** Opens home screen (walk is now marked cancelled)

### **Multi-User Scenario:**
```
Walk has 5 participants (including host):
- Host: no notification sent
- 4 participants: each receives notification in parallel
- Each notified: "Morning Walk Downtown cancelled"
```

### **Error Handling:**
- **No participants:** Function completes silently
- **Invalid tokens:** Removed from Firestore, continues with valid ones
- **Partial failure:** Some users notified, errors logged
- **Timeout:** Function stops at 60s, some users may not get notified

### **Performance:**
- Execution time: 1s - 3s (parallel notifications)
- Cost: ~$0.00025 × participant_count
- Timeout: 60 seconds

### **Code Location:**
[functions/index.js](../functions/index.js#L100-L160) - `onWalkCancelled`

---

## 📝 Function 3: `onWalkUpdated`

### **Trigger:**
```
Event: Document UPDATE
Path:  /walks/{walkId}
When:  Important fields change
```

### **Monitored Fields (Important):**
```javascript
const importantFields = ['title', 'dateTime', 'location'];
```

### **Ignored Fields (Not Important):**
```javascript
// These don't trigger notification:
- joinedUserUids         (see onWalkJoined instead)
- joinedCount            (derived from above)
- cancelled              (see onWalkCancelled instead)
- photoUrls              (visual enhancement only)
- visibility             (already set at creation)
```

### **Fired After:**
```dart
// In app code - DOES trigger onWalkUpdated:
walks.doc(walkId).update({'dateTime': newDateTime});  // ✅

// DOESN'T trigger onWalkUpdated:
walks.doc(walkId).update({'photoUrls': newPhotos});   // ❌
```

### **Payload (Updated Document):**
```json
{
  "title": "New Title - Riverside Walk",
  "dateTime": "2026-01-20T09:00:00Z",
  "location": "New location: Corniche",
  "previousTitle": "Morning Walk",
  "previousDateTime": "2026-01-15T09:00:00Z",
  "previousLocation": "Old location: Downtown"
}
```

### **What It Does:**
1. ✅ Compare with previous document values
2. ✅ Identify which field(s) changed
3. ✅ Fetch all participant tokens (except host)
4. ✅ Send specific change notification
5. ✅ Message: "**{walkTitle}** {changeDescription}"

### **Notification Examples:**

**If Title Changed:**
- Message: `"Morning Walk" changed to "Riverside Walk"`

**If Time Changed:**
- Message: `Walk time changed to Jan 20 at 9:00 AM`

**If Location Changed:**
- Message: `Meeting location changed to Corniche`

### **Data Payload:**
```json
{
  "action": "walk_updated",
  "walkId": "walk_456",
  "changeType": "title|dateTime|location"
}
```

### **Error Handling:**
- **Not important field:** Function exits silently
- **Same value:** Function exits silently (no real change)
- **No changes detected:** Function exits silently

### **Performance:**
- Execution time: 1s - 2.5s (sequential checks)
- Cost: ~$0.00025 × participant_count
- Timeout: 60 seconds

### **Code Location:**
[functions/index.js](../functions/index.js#L160-L220) - `onWalkUpdated`

---

## 💬 Function 4: `onChatMessage`

### **Trigger:**
```
Event: Document CREATE
Path:  /walks/{walkId}/messages/{messageId}
When:  User sends message in walk chat
```

### **Fired After:**
```dart
// In app code:
db.collection('walks')
    .doc(walkId)
    .collection('messages')
    .add({
      'userId': currentUserId,
      'text': 'See you there!',
      'createdAt': Timestamp.now(),
      'userName': currentUserName,
    });
```

### **Payload (New Document):**
```json
{
  "userId": "user_123",
  "userName": "Ahmed",
  "text": "See you there! Excited for the walk tomorrow",
  "createdAt": "2026-01-15T14:30:00Z"
}
```

### **What It Does:**
1. ✅ Fetch walk to get all participants
2. ✅ Fetch all participant FCM tokens (except sender)
3. ✅ Truncate message to 100 characters max
4. ✅ Send notification: "**{senderName}**: {message_preview}..."
5. ✅ Clean up invalid tokens

### **Notification Details:**

**Title:** `New message: {walkTitle}`

**Body:** `${senderName}: ${messagePreview(text, maxChars=100)}`

**Example:**
- Body: `Ahmed: See you there! Excited for the walk tomorrow`

**Data Payload:**
```json
{
  "action": "new_chat_message",
  "walkId": "walk_456",
  "messageId": "msg_789"
}
```

**Tap Action:** Opens walk chat screen

### **Message Preview Logic:**
```javascript
// If message is 150 chars:
"This is a very long message that I want to share with everyone..."
// Truncated to:
"This is a very long message that I want to share with everyone..."
// Max 100 chars shown, "..." appended if truncated
```

### **Multi-User Scenario:**
```
Walk has 5 participants:
- Sender (Ahmed): no notification sent to self
- 4 others: each gets notification
- All get: "Ahmed: See you there! Excited..."
```

### **Error Handling:**
- **Walk not found:** Function exits silently
- **User not found (sender):** Message still sent with generic "Someone"
- **Invalid tokens:** Removed, continues with valid ones
- **Very long message:** Truncated gracefully with "..."

### **Performance:**
- Execution time: 1s - 2s (parallel notifications)
- Cost: ~$0.00025 × (participant_count - 1)
- Timeout: 60 seconds
- **High volume:** If 10 messages/minute in a chat, 10 function invocations/minute

### **Code Location:**
[functions/index.js](../functions/index.js#L220-L280) - `onChatMessage`

---

## 🛠️ Helper Function: `sendNotificationToUser`

### **Purpose:**
Shared logic for all 4 functions to send FCM notifications

### **Signature:**
```javascript
async function sendNotificationToUser(
  userId,           // target user to notify
  title,            // notification title
  body,             // notification body
  data,             // custom data payload
  admin             // Firebase admin SDK
)
```

### **Process:**
1. Fetch all FCM tokens for user from `/users/{userId}/fcmTokens`
2. Try sending to each token in parallel
3. If token fails (invalid, expired), remove it from Firestore
4. Log successes and failures
5. Return count of successful sends

### **Return Value:**
```javascript
{
  success: true,
  sent: 2,           // number of successful sends
  failed: 0,         // number of failed tokens
  errors: []         // error details if any
}
```

### **Error Recovery:**
```
If sending to token fails:
  1. Check error type
  2. If "registration token is invalid": DELETE from Firestore
  3. If network error: Log but DON'T delete (retry next time)
  4. If timeout: Log and continue
```

### **Code Location:**
[functions/index.js](../functions/index.js#L1-L50) - `sendNotificationToUser`

---

## 📊 Common Data Flows

### **User Joins Walk:**
```
User taps "Join" in HomeScreen
    ↓
writeParticipation(walkId, userId)
    ↓
Firestore: /users/{userId}/walks/{walkId} created
    ↓
onWalkJoined trigger fires
    ↓
Function fetches: walk details + joiner profile + host tokens
    ↓
FCM: Host gets "Ahmed joined your walk"
    ↓
Host's device shows notification (if app open or in background)
    ↓
Host taps → opens WalkDetailsScreen with walk_456
```

### **Host Cancels Walk:**
```
Host taps "Cancel Walk" in WalkDetailsScreen
    ↓
updateWalk(walkId, { cancelled: true })
    ↓
Firestore: /walks/{walkId} updated with cancelled: true
    ↓
onWalkCancelled trigger fires
    ↓
Function fetches: all participant tokens (except host)
    ↓
FCM: Sends "Morning Walk - Cancelled" to 5 other participants in parallel
    ↓
All participants' devices show notification
    ↓
Tap → returns to HomeScreen (walk no longer visible)
```

### **User Sends Chat Message:**
```
User types message in walk chat, taps Send
    ↓
db.collection('walks/{walkId}/messages').add({...})
    ↓
Firestore: /walks/{walkId}/messages/{messageId} created
    ↓
onChatMessage trigger fires
    ↓
Function fetches: walk participants + all their tokens
    ↓
FCM: Sends "Ahmed: See you there!" to 4 other participants
    ↓
All other participants get notification
    ↓
Tap → opens WalkChatScreen with walkId
```

---

## ⚠️ Known Limitations & Considerations

### **Cold Start Times:**
- First function invocation: 2-5 seconds (cold start)
- Subsequent: 500ms - 1s (warm)
- **Impact:** User may not see notification immediately on first event

### **Cost Scaling:**
- 100 walks × 5 people each = 500 notifications/day = ~$0.00013/day
- Scale to 10,000 events/day = ~$0.003/day = $0.09/month

### **FCM Token Expiry:**
- Tokens can become invalid after app reinstall
- Helper function cleans them up on failed send
- Old tokens don't accumulate (auto-cleaned)

### **Message Ordering:**
- FCM does NOT guarantee message order
- Chat messages from user A then B might arrive in wrong order
- UI should display by timestamp, not arrival order

### **Duplicate Prevention:**
- No deduplication in current implementation
- If function retries, user may get duplicate notification
- **Mitigation:** Firebase ensures at-least-once delivery (some retries possible)

### **No Offline Queueing:**
- If user has no tokens (offline), notification is lost
- When user comes online, they see walk in UI (not via notification)
- This is acceptable for current use case

---

## 🚀 Deployment

### **Prerequisites:**
- Firebase project on Blaze plan
- Firebase CLI installed
- Node.js 20+ runtime

### **Deploy All Functions:**
```bash
cd functions
firebase deploy --only functions
```

### **Deploy Single Function:**
```bash
firebase deploy --only functions:onWalkJoined
```

### **Monitor After Deploy:**
```bash
firebase functions:log
```

---

## 🔍 Debugging & Testing

### **View Logs:**
```bash
firebase functions:log --tail
```

### **Simulate Trigger (Local Emulator):**
```bash
firebase emulators:start
# Then in another terminal:
firebase functions:shell
> onWalkJoined({userId: "test_123", walkId: "test_456"})
```

### **Check FCM Tokens:**
```bash
# In Firebase Console:
# Firestore → users → [userId] → fcmTokens
# See all active tokens and their creation dates
```

### **Test Notification Delivery:**
```bash
# Send test notification via Firebase Console
# Messaging → Create your first campaign
# Select web or device
```

---

## 📚 Related Files

- [functions/index.js](../functions/index.js) - Complete implementation
- [firestore.rules](../firestore.rules) - Security & access control
- [lib/services/notification_service.dart](../lib/services/notification_service.dart) - Client-side FCM setup
- [FIREBASE_SETUP.md](./FIREBASE_SETUP.md) - Firebase project configuration

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team  
**Last Deployed:** [Check Firebase Console for latest deployment date]

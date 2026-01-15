# CP-4: Walk History & Statistics Guide

## Overview

CP-4 implements a complete walk tracking system with user confirmation flow, automatic statistics calculation, and lifetime walk history. This feature transforms walk participation into quantifiable user achievements and provides detailed analytics.

**Status**: ✅ Implementation Complete (Phase 1: Foundation)

---

## Table of Contents

1. [User Flow](#user-flow)
2. [Architecture](#architecture)
3. [Data Models](#data-models)
4. [Services](#services)
5. [Cloud Functions](#cloud-functions)
6. [UI Components](#ui-components)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## User Flow

### Walk Completion Scenario (3-Stage Process)

#### Stage 1: Host Initiates Walk ("Start Walk")
```
Host in EventDetailsScreen
  ↓
Presses "Start Walk" button (green, play icon)
  ↓
WalkControlService.startWalk(walkId) called
  ↓
Walk status: "open" → "starting"
  ↓
onWalkStarted Cloud Function triggered
  ↓
FCM prompts sent to all participants: "Walk has started! Join now?"
```

#### Stage 2: Participants Confirm Participation
```
Participant receives FCM notification
  ↓
EventDetailsScreen shows confirmation buttons:
  • "Confirm - I'm Joining Now" (green)
  • "Decline - I'm Not Coming" (outline)
  ↓
If CONFIRM:
  WalkHistoryService.confirmParticipation(walkId)
  status: "open" → "actively_walking"
  confirmedAt: timestamp recorded
  
If DECLINE:
  WalkHistoryService.declineParticipation(walkId)
  status: "open" → "declined"
  declinedAt: timestamp recorded
```

#### Stage 3: Host Ends Walk ("End Walk")
```
Host presses "End Walk" button (orange, stop icon)
  ↓
WalkControlService.endWalk(walkId) called
  ↓
Walk status: "starting"/"active" → "completed"
  ↓
onWalkEnded Cloud Function triggered
  ↓
For each "actively_walking" participant:
  1. Mark status: "completed"
  2. Record completedAt: timestamp
  3. Calculate actualDurationMinutes
  4. Persist to /users/{uid}/walks/{walkId}
  
For each user:
  1. Recalculate lifetime stats
  2. Update /users/{uid}/stats/walkStats
```

### Early Departure Scenario

```
Participant decides to leave during walk:
  ↓
Presses "Leave Walk" (logout/back action)
  ↓
WalkHistoryService.leaveWalkEarly(walkId)
  ↓
Status: "actively_walking" → "completed_early"
completedAt: timestamp recorded
  ↓
onUserLeftWalkEarly Cloud Function:
  Calculate partial duration (actual vs planned)
  Update user stats with partial credit
```

### Safety Net: Auto-Complete After Grace Period

```
Host forgets to press "End Walk" button:
  ↓
Walk remains in "starting"/"active" status
  ↓
Grace period: planned_duration + 30 minutes
  ↓
onWalkAutoComplete Cloud Function (scheduled):
  Auto-completes walk
  Marks all "actively_walking" as "completed"
  Status: "starting" → "completed"
```

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│  EventDetailsScreen  │  ProfileScreen  │  WalkChatScreen   │
└───────────────┬──────────────────────────────────────────────┘
                │
        ┌───────┴────────────────────────────┐
        ↓                                    ↓
┌──────────────────────────┐    ┌──────────────────────────┐
│  WalkControlService      │    │ WalkHistoryService       │
│  (Host actions)          │    │ (Participant tracking)   │
├──────────────────────────┤    ├──────────────────────────┤
│ • startWalk()            │    │ • confirmParticipation() │
│ • endWalk()              │    │ • declineParticipation() │
│ • cancelWalk()           │    │ • leaveWalkEarly()       │
│ • completeWalkEarly()    │    │ • getUserWalkStats()     │
│ • getParticipantCount()  │    │ • watchUserWalkStats()   │
└──────────────┬───────────┘    └──────────────┬───────────┘
               │                              │
               └──────────────┬───────────────┘
                              ↓
                    ┌─────────────────────────┐
                    │  Firestore Database     │
                    ├─────────────────────────┤
                    │ /walks/{walkId}         │ (status, times)
                    │ /users/{uid}/walks/{id} │ (participation)
                    │ /users/{uid}/stats/     │ (aggregate stats)
                    │   walkStats             │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        ↓                        ↓                        ↓
   ┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐
   │ onWalkStarted│    │ onWalkEnded      │    │onUserLeftWalkEarly
   │   Function   │    │   Function       │    │    Function     │
   └──────────────┘    └──────────────────┘    └─────────────────┘
   Send FCM prompts    Calculate stats      Mark early departure
```

---

## Data Models

### WalkEvent (`lib/models/walk_event.dart`)

**CP-4 Fields Added**:

```dart
class WalkEvent {
  // ... existing fields ...
  
  // CP-4: Walk control fields
  final String status;           // 'open' | 'starting' | 'active' | 'completed' | 'cancelled'
  final DateTime? startedAt;     // When host pressed "Start Walk"
  final String? startedByUid;    // Host UID who started
  final DateTime? completedAt;   // When host pressed "End Walk"
  final int? plannedDurationMinutes;   // Host-set expected duration
  final int? actualDurationMinutes;    // Calculated actual duration
}
```

**Status Lifecycle**:
```
open → starting → (active) → completed
  ↓
  └→ cancelled (if host cancels before start)
```

### WalkParticipation (`lib/models/walk_participation.dart`)

**CP-4 Fields Added**:

```dart
class WalkParticipation {
  // ... existing fields ...
  
  // CP-4: Confirmation tracking
  final String status;              // 'open' | 'starting' | 'actively_walking' | 'declined' | 'completed' | 'completed_early'
  final DateTime? confirmedAt;      // When user confirmed at walk start
  final DateTime? declinedAt;       // When user declined the prompt
  final DateTime? completedAt;      // When walk marked complete by host
  final int? actualDurationMinutes; // Calculated actual participation duration
}
```

**Status Lifecycle** (per participant):
```
open (joined) → confirmation_prompt → actively_walking → completed
              → declined (declined prompt)
              → completed_early (left mid-walk)
              → host_cancelled (host cancelled walk)
```

### Walk Statistics (`/users/{uid}/stats/walkStats`)

**Document Structure**:

```json
{
  "userId": "uid123",
  "totalWalksCompleted": 24,
  "totalWalksJoined": 28,
  "totalWalksHosted": 5,
  "totalDistanceKm": 87.3,
  "totalDuration": 315600,          // seconds (87.5 hours)
  "totalParticipants": 156,
  "averageDistancePerWalk": 3.64,
  "averageDurationPerWalk": 13150,   // seconds (3.6 hours avg)
  "lastWalkDate": "2026-01-15T10:30:00Z",
  "createdAt": "2025-06-01T00:00:00Z",
  "lastUpdated": "2026-01-15T10:30:00Z"
}
```

---

## Services

### WalkControlService (`lib/services/walk_control_service.dart`)

**Purpose**: Host-only walk control operations

**Key Methods**:

#### `startWalk(walkId)`
- **Caller**: Host via EventDetailsScreen
- **Effect**: Changes walk status to "starting", triggers Cloud Function to send FCM prompts
- **Error Handling**: Validates host ownership
- **Returns**: Future<void>

```dart
await WalkControlService.instance.startWalk(walkId);
// Updates walk: { status: "starting", startedAt: now, startedByUid: uid }
```

#### `endWalk(walkId)`
- **Caller**: Host via EventDetailsScreen
- **Effect**: Changes walk status to "completed", triggers stats calculation
- **Calculation**: Automatic duration = now - startedAt
- **Error Handling**: Confirms with dialog, validates host ownership
- **Returns**: Future<void>

```dart
await WalkControlService.instance.endWalk(walkId);
// Updates walk: { status: "completed", completedAt: now, actualDurationMinutes: N }
```

#### `cancelWalk(walkId, reason)`
- **Caller**: Host before walk starts
- **Effect**: Changes walk status to "cancelled", marks all participants as cancelled
- **Error Handling**: Prevents cancellation if walk already started
- **Returns**: Future<void>

#### `getActiveParticipantCount(walkId)`
- **Caller**: EventDetailsScreen (for UI display)
- **Effect**: Queries count of "actively_walking" participants
- **Returns**: Future<int>

#### `getParticipationStatus(walkId)`
- **Caller**: Admin/analytics
- **Effect**: Returns map of userId → participationStatus for all participants
- **Returns**: Future<Map<String, String>>

---

### WalkHistoryService (`lib/services/walk_history_service.dart`)

**Purpose**: Participant-side walk tracking and stats retrieval

**CP-4 Methods Added**:

#### `confirmParticipation(walkId)`
- **Caller**: Participant via EventDetailsScreen
- **Effect**: Sets status to "actively_walking", records confirmedAt
- **Updates**: `/users/{uid}/walks/{walkId}`
- **Returns**: Future<void>

```dart
await WalkHistoryService.instance.confirmParticipation(walkId);
```

#### `declineParticipation(walkId)`
- **Caller**: Participant via EventDetailsScreen
- **Effect**: Sets status to "declined", records declinedAt
- **Updates**: `/users/{uid}/walks/{walkId}`
- **Returns**: Future<void>

#### `leaveWalkEarly(walkId)`
- **Caller**: Participant (implicit when leaving)
- **Effect**: Sets status to "completed_early"
- **Trigger**: Cloud Function recalculates partial stats
- **Returns**: Future<void>

#### `markParticipationComplete(walkId, actualDurationMinutes)`
- **Caller**: Cloud Function (onWalkEnded)
- **Effect**: Sets status to "completed", records completedAt
- **Internal**: Called by backend only
- **Returns**: Future<void>

#### `getUserWalkStats(userId)`
- **Caller**: ProfileScreen
- **Effect**: Retrieves persisted stats document for user
- **Returns**: Future<Map<String, dynamic>>

```dart
final stats = await WalkHistoryService.instance.getUserWalkStats(uid);
// Returns: {
//   totalWalksCompleted: 24,
//   totalDistanceKm: 87.3,
//   totalDuration: 315600,
//   averageDistancePerWalk: 3.64,
//   ...
// }
```

#### `watchUserWalkStats(userId)`
- **Caller**: ProfileScreen (for real-time updates)
- **Effect**: Returns Stream for listening to stats changes
- **Returns**: Stream<Map<String, dynamic>>

---

## Cloud Functions

### 1. `onWalkStarted` (Firestore Trigger)

**Trigger**: `/walks/{walkId}` updated with `status: "starting"`

**Flow**:
```
Get walk document (walkId, title, joinedUserUids, hostUid)
  ↓
For each participant EXCEPT host:
  ├─ Get FCM tokens from /users/{uid}/fcmTokens
  ├─ Send notification:
  │   title: "{walk.title} has started!"
  │   body: "Are you joining this walk now?"
  │   data: { action: "walk_confirmation_prompt", walkId, type: "confirmation_needed" }
  ├─ Clean up invalid tokens
  └─ Log success/failure
```

**Error Handling**:
- Gracefully skips users with no FCM tokens
- Removes stale/invalid tokens from database
- Logs errors without stopping other users

**Code Location**: `functions/cp4_walk_completion.js`

---

### 2. `onWalkEnded` (Firestore Trigger)

**Trigger**: `/walks/{walkId}` updated with `status: "completed"`

**Flow**:
```
Get walk document (startedAt, completedAt, distanceKm)
  ↓
Calculate actualDurationMinutes = (completedAt - startedAt) / 60
  ↓
Find all "actively_walking" participants:
  ├─ Query: collectionGroup("walks") where walkId and status == "actively_walking"
  ├─ For each participant:
  │   ├─ Calculate participantDurationMinutes = (completedAt - confirmedAt) / 60
  │   ├─ Update participation: status="completed", completedAt, actualDurationMinutes
  │   └─ Add to stats update queue
  ↓
For each participant to update stats:
  ├─ Get current stats document: /users/{uid}/stats/walkStats
  ├─ Add: totalWalksCompleted++, totalDistanceKm += distance, totalDuration += seconds
  ├─ Recalculate: averages = totals / completedWalks
  ├─ Update: lastWalkDate = now
  └─ Write back to Firestore
```

**Key Calculations**:

```javascript
// Per user
const confirmedAt = participation.confirmedAt || walkStartedAt;
const userDurationMinutes = Math.round((completedAt - confirmedAt) / 1000 / 60);
const userDurationSeconds = userDurationMinutes * 60;

// Updated stats
stats.totalWalksCompleted += 1;
stats.totalDistanceKm += walk.distanceKm;
stats.totalDuration += userDurationSeconds;
stats.averageDistancePerWalk = stats.totalDistanceKm / stats.totalWalksCompleted;
stats.averageDurationPerWalk = stats.totalDuration / stats.totalWalksCompleted;
stats.lastWalkDate = now;
```

**Error Handling**:
- Gracefully continues if individual user update fails
- Logs errors with userId for debugging
- Batch operations prevent race conditions

**Code Location**: `functions/cp4_walk_completion.js`

---

### 3. `onUserLeftWalkEarly` (Firestore Trigger)

**Trigger**: `/users/{uid}/walks/{walkId}` updated with `status: "completed_early"`

**Flow**:
```
Get participation document (confirmedAt, leftAt)
  ↓
If confirmedAt missing, abort (user never confirmed)
  ↓
Calculate partialDurationMinutes = (leftAt - confirmedAt) / 60
  ↓
Call updateUserStats(uid, partialDurationMinutes, distance, isPartialCredit: true)
  ↓
Update stats with partial credit
```

**Partial Credit Logic**:
- Record actual time walked (not full walk time)
- Count toward lifetime stats
- Mark in analytics for separate reporting

**Code Location**: `functions/cp4_walk_completion.js`

---

### 4. `onWalkAutoComplete` (Scheduled, Optional)

**Trigger**: Every 5 minutes (via Cloud Scheduler)

**Flow**:
```
Query all walks with status != "completed" and status != "cancelled"
  ↓
For each walk:
  ├─ Calculate plannedEndTime = dateTime + plannedDurationMinutes
  ├─ gracePeriod = plannedEndTime + 30 minutes
  ├─ If now > gracePeriod:
  │   ├─ Update walk: status = "completed"
  │   └─ Trigger onWalkEnded logic
  └─ Continue
```

**Status**: Placeholder only (requires Cloud Scheduler setup by DevOps)

**Code Location**: `functions/cp4_walk_completion.js`

---

## UI Components

### EventDetailsScreen Enhancements

#### Host Controls (if user is owner)

**Start Walk Button**:
- **Visible When**: Walk status is "open"
- **Style**: Green, play icon
- **Label**: "Start Walk"
- **Action**: Calls `WalkControlService.startWalk()`
- **Feedback**: Toast "✅ Walk started! Sending confirmation prompts..."

**End Walk Button**:
- **Visible When**: Walk status is "starting" or "active"
- **Style**: Orange, stop icon
- **Label**: "End Walk"
- **Action**: Shows confirmation dialog, then calls `WalkControlService.endWalk()`
- **Feedback**: Toast "✅ Walk ended! Stats calculated."

**Participant Counter**:
- **Visible When**: Walk has started
- **Display**: "X participants confirmed"
- **Real-time**: FutureBuilder that refreshes
- **Updates**: `WalkControlService.getActiveParticipantCount(walkId)`

#### Participant Controls (if user joined, walk starting)

**Confirmation Buttons** (shown when walk status is "starting"):

**Confirm Button**:
- **Style**: Green, check icon
- **Label**: "Confirm - I'm Joining Now"
- **Action**: `WalkHistoryService.confirmParticipation(walkId)`
- **Feedback**: Toast "✅ Confirmed! You're walking with us!"
- **Effect**: Status changes from "open" to "actively_walking"

**Decline Button**:
- **Style**: Outline, cancel icon
- **Label**: "Decline - I'm Not Coming"
- **Action**: `WalkHistoryService.declineParticipation(walkId)`
- **Feedback**: Toast "Declined. You can join another time!"
- **Effect**: Status changes from "open" to "declined"

---

### ProfileScreen Enhancements

#### New Section: "Lifetime stats"

**Display When**: User has completed at least 1 walk

**Content**: 2x2 Grid of Stats

| Icon | Label | Value | Source |
|------|-------|-------|--------|
| ✓ | Total walks | 24 | stats.totalWalksCompleted |
| 📍 | Distance | 87.3 km | stats.totalDistanceKm |
| ⏱️ | Time | 87h 32m | stats.totalDuration (seconds) |
| 📈 | Avg distance | 3.64 km | stats.averageDistancePerWalk |

**Empty State**: "No completed walks yet. Start walking to see your lifetime stats!"

**Real-time Updates**: Uses `WalkHistoryService.watchUserWalkStats()` Stream

---

## Testing

### Unit Tests

**File**: `test/services/walk_control_service_test.dart`

```dart
group('WalkControlService', () {
  test('startWalk updates status to starting', () async {
    // Arrange
    final mockWalkId = 'walk123';
    
    // Act
    await WalkControlService.instance.startWalk(mockWalkId);
    
    // Assert
    // Verify Firestore called with correct update
    verify(firestore
        .collection('walks')
        .doc(mockWalkId)
        .update({'status': 'starting', ...}));
  });

  test('endWalk only works for host', () async {
    // Should throw exception if current user is not host
  });

  test('getActiveParticipantCount returns correct number', () async {
    // Should query collectionGroup with correct filters
  });
});
```

### Integration Tests

**File**: `test/integration/walk_completion_flow_test.dart`

```dart
group('Walk Completion Flow', () {
  test('Complete 3-stage walk flow from start to stats', () async {
    // 1. Host starts walk → onWalkStarted triggers
    // 2. Participant confirms → status updates to actively_walking
    // 3. Host ends walk → onWalkEnded calculates stats
    // 4. Verify stats persisted at /users/{uid}/stats/walkStats
  });
});
```

---

## Troubleshooting

### Issue: "User is not host of walk" error

**Cause**: Non-host user trying to call `startWalk()` or `endWalk()`

**Solution**:
1. Verify `event.isOwner` is true before showing buttons
2. Check `FirebaseAuth.instance.currentUser?.uid` matches `walk.hostUid`
3. Refresh walk data if recently reassigned

---

### Issue: Participants not receiving confirmation prompt

**Cause**: Missing FCM tokens, Cloud Function failed silently

**Solution**:
1. Verify FCM tokens are registered: `/users/{uid}/fcmTokens`
2. Check Cloud Function logs in Firebase Console
3. Verify notification permissions granted on device
4. Check data object in notification: `walk_confirmation_prompt` action

---

### Issue: Stats not updating after walk completion

**Cause**: onWalkEnded Cloud Function didn't trigger or failed

**Solution**:
1. Verify walk document was updated with `status: "completed"`
2. Check Cloud Function logs for errors
3. Manually trigger stats recalculation via admin console
4. Verify Firestore rules allow write to `/users/{uid}/stats/walkStats`

---

### Issue: "No participants confirmed" but I joined

**Cause**: Participant never received confirmation prompt or declined

**Solution**:
1. Verify walk status changed to "starting" (check Firebase Console)
2. Check participant's notification settings
3. Re-join walk and try confirmation again
4. Check participant's walk status field in `/users/{uid}/walks/{walkId}`

---

## Future Enhancements (Phase 2)

- [ ] Weekly/monthly stats aggregation
- [ ] Leaderboards (top walkers, most distance, etc.)
- [ ] Achievement badges based on stats thresholds
- [ ] Walk export (CSV, PDF with stats)
- [ ] Social sharing of walk statistics
- [ ] Monthly email digest with stats
- [ ] Streak tracking (consecutive days walked)

---

## Related Documentation

- [API Documentation](API_DOCUMENTATION.md) - Cloud Functions reference
- [Architecture Guide](ARCHITECTURE.md) - System design overview
- [Firebase Setup](FIREBASE_SETUP.md) - Backend configuration
- [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) - Release process

---

**Last Updated**: January 15, 2026
**Status**: ✅ Complete for Phase 1
**Next Review**: After Phase 2 implementation

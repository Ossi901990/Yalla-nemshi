# CP-4 Quick Start Examples

Quick reference code snippets for using CP-4 services in your app.

---

## Host Operations

### Start a Walk

```dart
import 'package:yalla_nemshi/services/walk_control_service.dart';

// In EventDetailsScreen or any screen
Future<void> startWalk(String walkId) async {
  try {
    await WalkControlService.instance.startWalk(walkId);
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Walk started! Sending confirmation prompts...')),
    );
    
    // Refresh UI
    setState(() {});
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### End a Walk

```dart
Future<void> endWalk(String walkId) async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('End this walk?'),
      content: const Text('All participants will be marked as completed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep walking'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('End Walk'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await WalkControlService.instance.endWalk(walkId);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Walk ended! Stats calculated.')),
    );
    
    Navigator.pop(context); // Close dialog
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Cancel a Walk (Before Start)

```dart
Future<void> cancelWalk(String walkId) async {
  final reason = 'Weather too bad';
  
  try {
    await WalkControlService.instance.cancelWalk(walkId, reason: reason);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Walk cancelled')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Get Active Participant Count

```dart
// Use in FutureBuilder for real-time updates
FutureBuilder<int>(
  future: WalkControlService.instance.getActiveParticipantCount(walkId),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    
    final count = snapshot.data ?? 0;
    return Text('$count participants confirmed');
  },
)
```

---

## Participant Operations

### Confirm Participation (When Walk Starts)

```dart
import 'package:yalla_nemshi/services/walk_history_service.dart';

Future<void> confirmParticipation(String walkId) async {
  try {
    await WalkHistoryService.instance.confirmParticipation(walkId);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Confirmed! You\'re walking with us!')),
    );
    
    setState(() {});
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Decline Participation

```dart
Future<void> declineParticipation(String walkId) async {
  try {
    await WalkHistoryService.instance.declineParticipation(walkId);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Declined. You can join another time!')),
    );
    
    setState(() {});
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### Leave Walk Early

```dart
Future<void> leaveWalkEarly(String walkId) async {
  try {
    await WalkHistoryService.instance.leaveWalkEarly(walkId);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You\'ve left the walk')),
    );
    
    Navigator.pop(context); // Go back
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

---

## Statistics & Analytics

### Fetch User Walk Statistics

```dart
Future<void> loadUserStats() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final stats = await WalkHistoryService.instance.getUserWalkStats(uid);
    
    final totalWalks = stats['totalWalksCompleted'] as int? ?? 0;
    final totalDistance = stats['totalDistanceKm'] as double? ?? 0.0;
    final totalSeconds = stats['totalDuration'] as int? ?? 0;
    
    // Convert to readable format
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    
    print('Walks: $totalWalks');
    print('Distance: ${totalDistance.toStringAsFixed(1)} km');
    print('Time: ${hours}h ${minutes}m');
  } catch (e) {
    print('Error loading stats: $e');
  }
}
```

### Display Stats in Real-Time

```dart
// In build method or StreamBuilder
StreamBuilder<Map<String, dynamic>>(
  stream: WalkHistoryService.instance.watchUserWalkStats(userId),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    
    if (!snapshot.hasData || snapshot.data == null) {
      return const Text('No stats available');
    }
    
    final stats = snapshot.data!;
    final totalWalks = stats['totalWalksCompleted'] as int? ?? 0;
    final totalDistance = stats['totalDistanceKm'] as double? ?? 0.0;
    final avgDistance = stats['averageDistancePerWalk'] as double? ?? 0.0;
    
    return Column(
      children: [
        Text('Total Walks: $totalWalks'),
        Text('Distance: ${totalDistance.toStringAsFixed(1)} km'),
        Text('Average: ${avgDistance.toStringAsFixed(1)} km/walk'),
      ],
    );
  },
)
```

### Get Participant Confirmation Status

```dart
Future<void> checkParticipationStatus(String walkId) async {
  try {
    final statusMap = await WalkControlService.instance.getParticipationStatus(walkId);
    
    // statusMap: { userId1: "actively_walking", userId2: "declined", ... }
    
    final activeCount = statusMap.values.where((s) => s == 'actively_walking').length;
    final declinedCount = statusMap.values.where((s) => s == 'declined').length;
    
    print('Confirmed: $activeCount, Declined: $declinedCount');
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## UI Components

### Host Start/End Button Bar

```dart
// In EventDetailsScreen
if (event.isOwner && !event.cancelled)
  Column(
    children: [
      // Start Walk button
      if (event.status == 'open')
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _startWalk(context, event),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Walk'),
          ),
        ),
      
      // End Walk button
      if (event.status == 'starting' || event.status == 'active')
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _endWalk(context, event),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange[600],
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End Walk'),
          ),
        ),
    ],
  ),
```

### Participant Confirmation Buttons

```dart
// In EventDetailsScreen (when walk.status == "starting")
if (!event.isOwner && event.joined && event.status == 'starting')
  Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _confirmParticipation(context, event),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green[600],
          ),
          icon: const Icon(Icons.check_circle),
          label: const Text('Confirm - I\'m Joining Now'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _declineParticipation(context, event),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Decline - I\'m Not Coming'),
        ),
      ),
    ],
  ),
```

### Stats Display Card

```dart
// On ProfileScreen
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(height: 8),
                  Text('$totalWalks'),
                  const Text('Total walks'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Icon(Icons.route),
                  const SizedBox(height: 8),
                  Text('${totalDistance.toStringAsFixed(1)} km'),
                  const Text('Distance'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  ),
)
```

---

## Error Handling Patterns

### Try/Catch with User Feedback

```dart
try {
  await WalkControlService.instance.startWalk(walkId);
  
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('✅ Success')),
  );
} on Exception catch (e) {
  if (!context.mounted) return;
  
  // Parse error message for user
  String message = 'Something went wrong';
  if (e.toString().contains('host')) {
    message = 'Only the host can start the walk';
  } else if (e.toString().contains('not found')) {
    message = 'Walk not found';
  }
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('❌ $message')),
  );
}
```

### Validation Before Action

```dart
Future<void> safeStartWalk(String walkId) async {
  // Validate
  if (walkId.isEmpty) {
    _showError('Invalid walk ID');
    return;
  }
  
  // Check permissions
  final isHost = await WalkControlService.instance.isHostOfWalk(walkId);
  if (!isHost) {
    _showError('Only hosts can start walks');
    return;
  }
  
  // Execute
  await WalkControlService.instance.startWalk(walkId);
}

void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $message')),
  );
}
```

---

## Testing Scenarios

### Scenario 1: Complete Walk Flow

```dart
// 1. Host starts walk
await WalkControlService.instance.startWalk(walkId);

// 2. Participant confirms
await WalkHistoryService.instance.confirmParticipation(walkId);

// 3. Host ends walk
await WalkControlService.instance.endWalk(walkId);

// 4. Check stats were calculated
final stats = await WalkHistoryService.instance.getUserWalkStats(userId);
assert(stats['totalWalksCompleted'] > 0);
```

### Scenario 2: Early Departure

```dart
// 1. Participant confirms
await WalkHistoryService.instance.confirmParticipation(walkId);

// 2. Participant leaves early
await WalkHistoryService.instance.leaveWalkEarly(walkId);

// 3. Verify status changed
final participation = await WalkHistoryService.instance.getWalkParticipation(walkId);
assert(participation?.status == 'completed_early');
```

### Scenario 3: Declined Participant

```dart
// 1. Participant receives confirmation prompt
// (walk status changed to "starting")

// 2. Participant declines
await WalkHistoryService.instance.declineParticipation(walkId);

// 3. Verify not in active count
final count = await WalkControlService.instance.getActiveParticipantCount(walkId);
// Count should not include this user
```

---

## Common Issues & Solutions

### Issue: "User is not host of walk"
**Solution**: Check `event.isOwner` before showing start/end buttons
```dart
if (event.isOwner) {
  // Show host buttons
}
```

### Issue: Confirmation buttons not appearing
**Solution**: Check walk status is exactly 'starting'
```dart
if (event.status == 'starting' && event.joined && !event.isOwner) {
  // Show confirmation buttons
}
```

### Issue: Stats not updating after walk
**Solution**: Verify:
1. Walk status changed to 'completed'
2. Cloud Function `onWalkEnded` triggered (check logs)
3. Firestore rules allow write to `/users/{uid}/stats/walkStats`
4. Participant was in 'actively_walking' status

### Issue: FCM prompts not arriving
**Solution**:
1. Check device has valid FCM token
2. Verify notification permissions granted
3. Check Cloud Function logs for errors
4. Test with real device (emulator may not show notifications)

---

**For detailed information, see [CP4_WALK_COMPLETION_GUIDE.md](./docs/CP4_WALK_COMPLETION_GUIDE.md)**

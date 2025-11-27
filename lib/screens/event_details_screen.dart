// lib/screens/event_details_screen.dart
import 'package:flutter/material.dart';

import '../models/walk_event.dart';

class EventDetailsScreen extends StatelessWidget {
  final WalkEvent event;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onCancelHosted;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.onToggleJoin,
    required this.onToggleInterested,
    required this.onCancelHosted,
  });

  String _formatDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:$min';
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this walk?'),
        content: const Text(
          'Are you sure you want to cancel this walk? '
          'Participants will no longer see it as active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walk'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancel walk'),
          ),
        ],
      ),
    );

    if (ok == true) {
      onCancelHosted(event);
      Navigator.pop(context); // close details
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk cancelled')),
      );
    }
  }

  Future<void> _openReportDialog(BuildContext context) async {
    final noteController = TextEditingController();
    final reasons = [
      'Fake event',
      'Inappropriate behaviour or harassment',
      'User lied about their gender',
      'Unsafe location or behaviour',
      'Wrong location or time',
      'No-show / did not appear',
      'Other',
    ];
    String selectedReason = reasons.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Report walk or user'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.map(
                      (reason) => RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            selectedReason = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      // In future, send selectedReason + noteController.text to backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you. Your report was submitted: $selectedReason'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canJoin = !event.isOwner && !event.cancelled;
    final joinText = event.joined ? 'Leave walk' : 'Join walk';

    final canInterested = !event.isOwner && !event.cancelled;
    final interestedText = event.interested
        ? 'Remove from interested'
        : 'Mark as interested';

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + small interested chip if flagged
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (event.interested)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Interested',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Date & time
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(_formatDateTime(event.dateTime)),
              ],
            ),
            const SizedBox(height: 8),

            // Distance & gender chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.straighten, size: 16),
                  label: Text('${event.distanceKm.toStringAsFixed(1)} km'),
                ),
                Chip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: Text(event.gender),
                ),
                if (event.isOwner)
                  Chip(
                    avatar: const Icon(Icons.star, size: 16),
                    label: const Text('You are hosting'),
                  ),
                if (event.cancelled)
                  Chip(
                    avatar: const Icon(Icons.error_outline, size: 16),
                    label: const Text('Cancelled'),
                    backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Meeting point
            Text(
              'Meeting point',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (event.meetingPlaceName != null &&
                event.meetingPlaceName!.trim().isNotEmpty)
              Text(event.meetingPlaceName!)
            else
              Text(
                event.meetingLat != null && event.meetingLng != null
                    ? 'Lat: ${event.meetingLat!.toStringAsFixed(5)}, '
                        'Lng: ${event.meetingLng!.toStringAsFixed(5)}'
                    : 'Custom location (no coordinates)',
              ),
            const SizedBox(height: 16),

            // Description
            if (event.description != null &&
                event.description!.trim().isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(event.description!),
              const SizedBox(height: 16),
            ],

            // Host-only cancel button
            if (event.isOwner && !event.cancelled) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  onPressed: () => _confirmCancel(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel this walk'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Join / leave button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canJoin
                    ? () {
                        onToggleJoin(event);
                        Navigator.pop(context); // go back after action
                      }
                    : null,
                icon: Icon(
                  event.joined
                      ? Icons.check_circle_outline
                      : Icons.directions_walk,
                ),
                label: Text(
                  event.isOwner
                      ? "You're the host"
                      : (event.cancelled ? 'Walk cancelled' : joinText),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Interested button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: canInterested
                    ? () {
                        onToggleInterested(event);
                        Navigator.pop(context);
                      }
                    : null,
                icon: Icon(
                  event.interested
                      ? Icons.star
                      : Icons.star_border_outlined,
                  color: event.interested ? Colors.amber : null,
                ),
                label: Text(interestedText),
              ),
            ),
            const SizedBox(height: 16),

            // Report
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openReportDialog(context),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

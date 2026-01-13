// lib/screens/event_details_screen.dart
import 'package:flutter/material.dart';
import '../models/review.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'walk_chat_screen.dart';
import 'review_walk_screen.dart';
import '../models/walk_event.dart';
import '../services/review_service.dart';
import '../services/recurring_walk_service.dart';
import '../widgets/review_widgets.dart';

class EventDetailsScreen extends StatefulWidget {
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

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  String _formatDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy • $hh:$min';
  }

  // ✅ Match Nearby/Home “pill” style
  Widget _eventPill({
    required bool isDark,
    required ThemeData theme,
    required IconData icon,
    required String label,
    bool danger = false,
    Color? iconColorOverride,
  }) {
    final bg = danger
        ? theme.colorScheme.error.withAlpha(
            (isDark ? 0.14 : 0.10 * 255).round(),
          )
        : (isDark
              ? Colors.white.withAlpha((0.06 * 255).round())
              : theme.colorScheme.surface);

    final border = danger
        ? theme.colorScheme.error.withAlpha(
            (isDark ? 0.45 : 0.35 * 255).round(),
          )
        : (isDark
              ? Colors.white.withAlpha((0.18 * 255).round())
              : Colors.black.withAlpha((0.12 * 255).round()));

    final fg = danger
        ? theme.colorScheme.error
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColorOverride ?? fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
      if (!context.mounted) return;
      widget.onCancelHosted(widget.event);
      Navigator.pop(context); // close details
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Walk cancelled')));
    }
  }

  Future<void> _confirmCancelSingle(BuildContext context) async {
    final theme = Theme.of(context);
    final dateStr = '${widget.event.dateTime.day}/${widget.event.dateTime.month}/${widget.event.dateTime.year}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this occurrence?'),
        content: Text(
          'This will only cancel this single walk on $dateStr. '
          'Other walks in the series will remain active.',
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
            child: const Text('Cancel this occurrence'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;
      widget.onCancelHosted(widget.event);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk occurrence cancelled')),
      );
    }
  }

  Future<void> _confirmCancelAllFuture(BuildContext context) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel all future walks?'),
        content: const Text(
          'This will cancel all future walks in this recurring series. '
          'Past walks will remain visible. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep walks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cancel all future'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!context.mounted) return;
      
      final groupId = widget.event.recurringGroupId;
      if (groupId == null || groupId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No recurring group ID found')),
        );
        return;
      }

      try {
        await RecurringWalkService.cancelAllFutureInstances(groupId);
        if (!context.mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All future walks cancelled')),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling walks: $e')),
        );
      }
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
                      (reason) => ListTile(
                        title: Text(reason),
                        leading: Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        onTap: () {
                          setState(() {
                            selectedReason = reason;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you. Your report was submitted: $selectedReason',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Shortcuts to avoid widget. prefix everywhere
    final event = widget.event;
    final onToggleJoin = widget.onToggleJoin;
    final onToggleInterested = widget.onToggleInterested;

    final canJoin = !event.isOwner && !event.cancelled;
    final joinText = event.joined ? 'Leave walk' : 'Join walk';

    final canInterested = !event.isOwner && !event.cancelled;
    final interestedText = event.interested
        ? 'Remove from interested'
        : 'Mark as interested';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF4F925C),
      body: Column(
        children: [
          // ===== HEADER (match Home/Nearby sizing) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 64,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF294630), Color(0xFF4F925C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== MAIN AREA (same structure as other screens) =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF071B26), // top (dark blue)
                            Color(0xFF041016), // bottom (almost black)
                          ],
                        )
                      : null,
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

                  child: Card(
                    color: isDark
                        ? const Color(0xFF0C2430)
                        : const Color(0xFFFBFEF8),
                    elevation: isDark ? 0.0 : 0.6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withAlpha(
                          (0.06 * 255).round(),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title inside card
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                      ),
                                ),
                              ),
                              if (event.interested)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withAlpha(
                                      (0.15 * 255).round(),
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.amber.withAlpha(
                                        (0.35 * 255).round(),
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Interested',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber,
                                            ) ??
                                            const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.amber,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Date & time
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateTime(event.dateTime),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ✅ Pills (match Nearby look)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.straighten,
                                label:
                                    '${event.distanceKm.toStringAsFixed(1)} km',
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.directions_walk,
                                label: event.pace,
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.person,
                                label: event.gender,
                                iconColorOverride: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              if (event.isOwner)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.star,
                                  label: 'You are hosting',
                                  iconColorOverride: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              if (event.cancelled)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.error_outline,
                                  label: 'Cancelled',
                                  danger: true,
                                ),
                              if (event.isRecurring && !event.isRecurringTemplate)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.repeat,
                                  label: 'Recurring',
                                  iconColorOverride: theme.colorScheme.primary,
                                ),
                            ],
                          ),

                          if (event.isRecurring && !event.isRecurringTemplate && event.recurrence != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withAlpha((0.3 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha((0.3 * 255).round()),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.repeat,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Part of a recurring series',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    event.recurrence!.getDescription(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Meeting point
                          Text(
                            'Meeting point',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (event.meetingPlaceName != null &&
                              event.meetingPlaceName!.trim().isNotEmpty)
                            Text(
                              event.meetingPlaceName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            )
                          else if (event.startLat != null &&
                              event.startLng != null &&
                              event.endLat != null &&
                              event.endLng != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start: ${event.startLat!.toStringAsFixed(5)}, ${event.startLng!.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'End: ${event.endLat!.toStringAsFixed(5)}, ${event.endLng!.toStringAsFixed(5)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              event.meetingLat != null &&
                                      event.meetingLng != null
                                  ? 'Lat: ${event.meetingLat!.toStringAsFixed(5)}, '
                                        'Lng: ${event.meetingLng!.toStringAsFixed(5)}'
                                  : 'Custom location (no coordinates)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),

                          const SizedBox(height: 16),

                          // ===== HOSTED BY CARD =====
                          Text(
                            'Hosted by',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withAlpha((0.05 * 255).round())
                                  : Colors.black.withAlpha((0.03 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withAlpha((0.08 * 255).round()),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.colorScheme.primary
                                      .withAlpha((0.2 * 255).round()),
                                  backgroundImage: (event.hostPhotoUrl != null &&
                                          event.hostPhotoUrl!.isNotEmpty)
                                      ? NetworkImage(event.hostPhotoUrl!)
                                      : null,
                                  child: (event.hostPhotoUrl == null ||
                                          event.hostPhotoUrl!.isEmpty)
                                      ? Icon(
                                          Icons.person,
                                          size: 28,
                                          color: theme.colorScheme.primary,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    event.hostName ?? 'Host ${event.hostUid.substring(0, 6)}',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== PEOPLE JOINING =====
                          Text(
                            'People joining',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Overlapping avatars
                              SizedBox(
                                width: event.joinedUserPhotoUrls.isEmpty
                                    ? 88
                                    : (event.joinedUserPhotoUrls.length > 4
                                        ? 120
                                        : (event.joinedUserPhotoUrls.length * 24.0 + 16)),
                                height: 40,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (event.joinedUserPhotoUrls.isEmpty)
                                      // Show 3 placeholder avatars when no one joined
                                      ...[
                                        Positioned(
                                          left: 0,
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey
                                                .withAlpha((0.3 * 255).round()),
                                            child: Icon(
                                              Icons.person_outline,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 24,
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey
                                                .withAlpha((0.3 * 255).round()),
                                            child: Icon(
                                              Icons.person_outline,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 48,
                                          child: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey
                                                .withAlpha((0.3 * 255).round()),
                                            child: Icon(
                                              Icons.person_outline,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ]
                                    else
                                      // Show actual participant avatars (max 4)
                                      ...List.generate(
                                        event.joinedUserPhotoUrls.length > 4
                                            ? 4
                                            : event.joinedUserPhotoUrls.length,
                                        (index) {
                                          final photoUrl = event
                                              .joinedUserPhotoUrls[index];
                                          return Positioned(
                                            left: index * 24.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF0C2430)
                                                      : const Color(0xFFFBFEF8),
                                                  width: 2,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    theme.colorScheme.primary
                                                        .withAlpha(
                                                          (0.2 * 255).round(),
                                                        ),
                                                backgroundImage: photoUrl
                                                        .isNotEmpty
                                                    ? NetworkImage(photoUrl)
                                                    : null,
                                                child: photoUrl.isEmpty
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 20,
                                                        color: theme.colorScheme
                                                            .primary,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                event.joinedCount > 0
                                    ? (event.joinedCount > 4
                                        ? '+${event.joinedCount - 4} others joining'
                                        : event.joinedCount == 1
                                            ? '1 person joining'
                                            : '${event.joinedCount} people joining')
                                    : '+0 others joining',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Description
                          if (event.description != null &&
                              event.description!.trim().isNotEmpty) ...[
                            Text(
                              'Description',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              event.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Join / leave button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: canJoin
                                  ? () {
                                      onToggleJoin(event);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: const Color(0xFF14532D),
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                event.joined
                                    ? Icons.check_circle_outline
                                    : Icons.directions_walk,
                              ),
                              label: Text(
                                event.isOwner
                                    ? "You're the host"
                                    : (event.cancelled
                                          ? 'Walk cancelled'
                                          : joinText),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Group chat button
                          if ((event.joined || event.isOwner) &&
                              event.firestoreId.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  debugPrint(
                                    'OPEN WALK CHAT: walk_${event.id}',
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalkChatScreen(
                                        walkId: event.firestoreId,
                                        walkTitle: event.title,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text('Chat with participants'),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ✅ Reviews Section
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Reviews',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Reviews stats + button to write review
                          FutureBuilder(
                            future: ReviewService.getWalkReviewStats(
                              widget.event.id,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                );
                              }

                              final stats = snapshot.data;
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RatingStatsWidget(
                                    stats:
                                        stats ??
                                        ReviewStats(
                                          averageRating: 0,
                                          totalReviews: 0,
                                          ratingDistribution: {},
                                        ),
                                    onWriteReview: currentUser != null
                                        ? () async {
                                            final result =
                                                await Navigator.pushNamed(
                                                  context,
                                                  ReviewWalkScreen.routeName,
                                                  arguments: {
                                                    'walk': widget.event,
                                                    'userId': currentUser.uid,
                                                    'userName':
                                                        currentUser
                                                            .displayName ??
                                                        'Anonymous',
                                                  },
                                                );
                                            // Refresh if review was added
                                            if (result == true &&
                                                context.mounted) {
                                              setState(() {});
                                            }
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // List of recent reviews
                                  FutureBuilder(
                                    future:
                                        ReviewService.getWalkReviewsPaginated(
                                          widget.event.id,
                                          limit: 5,
                                        ),
                                    builder: (context, reviewSnapshot) {
                                      if (reviewSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 80,
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final reviews = reviewSnapshot.data ?? [];

                                      if (reviews.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Recent Reviews',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...reviews.map(
                                            (review) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12.0,
                                              ),
                                              child: ReviewCard(
                                                review: review,
                                                onDelete:
                                                    currentUser?.uid ==
                                                        review.userId
                                                    ? () async {
                                                        await ReviewService.deleteReview(
                                                          review.id,
                                                          widget.event.id,
                                                        );
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Review deleted',
                                                              ),
                                                              duration:
                                                                  Duration(
                                                                    seconds: 2,
                                                                  ),
                                                            ),
                                                          );
                                                          setState(() {});
                                                        }
                                                      }
                                                    : null,
                                                onHelpful: () async {
                                                  if (currentUser == null) {
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Please sign in to mark helpful',
                                                        ),
                                                        duration: Duration(
                                                          seconds: 2,
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  await ReviewService.markHelpful(
                                                    review.id,
                                                    currentUser.uid,
                                                  );
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Marked helpful',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                          if (reviews.length >= 5)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: TextButton(
                                                onPressed: () {
                                                  // Could navigate to full reviews screen
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'See all reviews feature coming soon',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Text(
                                                  'Load more reviews',
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // Host-only cancel button(s)
                          if (event.isOwner && !event.cancelled) ...[
                            if (event.isRecurring && !event.isRecurringTemplate && event.recurringGroupId != null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () => _confirmCancelSingle(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancel this occurrence'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () => _confirmCancelAllFuture(context),
                                  icon: const Icon(Icons.event_busy),
                                  label: const Text('Cancel all future walks'),
                                ),
                              ),
                            ] else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    foregroundColor: theme.colorScheme.error,
                                    side: BorderSide(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                  onPressed: () => _confirmCancel(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancel this walk'),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],

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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// lib/screens/event_details_screen.dart
import 'package:flutter/material.dart';
import 'walk_chat_screen.dart';
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
        ? theme.colorScheme.error.withOpacity(isDark ? 0.14 : 0.10)
        : (isDark ? Colors.white.withOpacity(0.06) : theme.colorScheme.surface);

    final border = danger
        ? theme.colorScheme.error.withOpacity(isDark ? 0.45 : 0.35)
        : (isDark
            ? Colors.white.withOpacity(0.18)
            : Colors.black.withOpacity(0.12));

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
      onCancelHosted(event);
      Navigator.pop(context); // close details
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Walk cancelled')));
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

    final canJoin = !event.isOwner && !event.cancelled;
    final joinText = event.joined ? 'Leave walk' : 'Join walk';

    final canInterested = !event.isOwner && !event.cancelled;
    final interestedText =
        event.interested ? 'Remove from interested' : 'Mark as interested';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071B26) : const Color(0xFF4F925C),
      body: Column(
        children: [
          // ===== HEADER (match Home/Nearby sizing) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16, // ✅ match Nearby/Home
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16, // ✅ match Nearby/Home
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
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF071B26) : const Color(0xFFF7F9F2),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                image: DecorationImage(
                  image: AssetImage(
                    isDark
                        ? 'assets/images/Dark_Grey_Background.png'
                        : 'assets/images/Light_Beige_background.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark ? Colors.black.withOpacity(0.35) : Colors.transparent,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.06),
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
                                  style: theme.textTheme.headlineSmall?.copyWith(
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
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.star,
                                          size: 14, color: Colors.amber),
                                      SizedBox(width: 6),
                                      Text(
                                        'Interested',
                                        style: TextStyle(
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
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
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
                                iconColorOverride:
                                    isDark ? Colors.white70 : Colors.black54,
                              ),
                              _eventPill(
                                isDark: isDark,
                                theme: theme,
                                icon: Icons.person,
                                label: event.gender,
                                iconColorOverride:
                                    isDark ? Colors.white70 : Colors.black54,
                              ),
                              if (event.isOwner)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.star,
                                  label: 'You are hosting',
                                  iconColorOverride:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              if (event.cancelled)
                                _eventPill(
                                  isDark: isDark,
                                  theme: theme,
                                  icon: Icons.error_outline,
                                  label: 'Cancelled',
                                  danger: true,
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Meeting point
                          Text(
                            'Meeting point',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? Colors.white : const Color(0xFF111827),
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
                          else
                            Text(
                              event.meetingLat != null && event.meetingLng != null
                                  ? 'Lat: ${event.meetingLat!.toStringAsFixed(5)}, '
                                      'Lng: ${event.meetingLng!.toStringAsFixed(5)}'
                                  : 'Custom location (no coordinates)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
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

                          // Host-only cancel button
                          if (event.isOwner && !event.cancelled) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  foregroundColor: theme.colorScheme.error,
                                  side:
                                      BorderSide(color: theme.colorScheme.error),
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
                                  debugPrint('OPEN WALK CHAT: walk_${event.id}');
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

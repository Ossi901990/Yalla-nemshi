// lib/widgets/walk_row.dart
//
// One walk in a list (Home "Coming up", Walks tab): day/time chip, title,
// "place · N going", and a join (+) / joined (✓) button.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/walk_event.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import 'ui/ui_kit.dart';

class WalkRow extends StatelessWidget {
  const WalkRow({
    super.key,
    required this.walk,
    required this.onOpen,
    required this.onJoin,
  });

  final WalkEvent walk;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  /// Chip colour by when the walk is: lime = today/tomorrow, coral = weekend,
  /// blue = other days.
  static Color chipColor(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final days = DateTime(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime(n.year, n.month, n.day)).inDays;
    if (days <= 1) return AppPalette.lime;
    if (t.weekday >= DateTime.saturday) return AppPalette.coral;
    return AppPalette.blue;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final daysAway = DateTime(
      walk.dateTime.year,
      walk.dateTime.month,
      walk.dateTime.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final place = (walk.meetingPlaceName ?? walk.city ?? '').trim();
    final subtitle = [
      // The chip only shows the weekday; add the date for walks further out.
      if (daysAway > 6) DateFormat('d MMM').format(walk.dateTime),
      if (place.isNotEmpty) place,
      walk.isOwner ? 'you host' : '${walk.joinedCount} going',
    ].join(' · ');

    final Widget trailing;
    if (walk.isOwner) {
      trailing = const SizedBox.shrink();
    } else if (walk.joined) {
      trailing = RoundIconButton(
        icon: Icons.check_rounded,
        onTap: onOpen,
        background: AppPalette.lime,
        foreground: AppPalette.ink,
        tooltip: "You're in",
        size: 48,
      );
    } else {
      trailing = RoundIconButton(
        icon: Icons.add_rounded,
        onTap: onJoin,
        // Dark: muted circle + lime icon; light: ink circle + lime icon.
        background: isDark ? p.surfaceMuted : AppPalette.ink,
        foreground: AppPalette.lime,
        tooltip: 'Join',
        size: 48,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Row(
        children: [
          TimeChip(
            day: DateFormat('EEE').format(walk.dateTime).toUpperCase(),
            time: DateFormat('HH:mm').format(walk.dateTime),
            color: chipColor(walk.dateTime),
            size: 64,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walk.title.isEmpty ? 'Untitled walk' : walk.title,
                  style: AppText.body(
                    16,
                    color: p.text,
                    weight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.body(14, color: p.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!walk.isOwner) ...[const SizedBox(width: AppSpace.sm), trailing],
        ],
      ),
    );
  }
}

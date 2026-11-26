// lib/screens/calendar_screen.dart
//
// "My calendar" (2026 style): the walks you host, joined or starred, laid out
// day by day. Pure UI fed by HomeScreen's already-loaded walks, so it costs no
// extra Firestore reads and can be tested without Firebase.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/walk_event.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/floating_nav_bar.dart';
import '../widgets/ui/ui_kit.dart';
import '../widgets/walk_row.dart';

/// Which of my walks the calendar shows.
enum CalendarFilter { all, hosting, joined, starred }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.walks,
    required this.onOpen,
    required this.onJoin,
    required this.onFindWalks,
    required this.onCreateWalk,
    this.now,
  });

  /// Every walk Home has loaded; the calendar picks out the user's own.
  final List<WalkEvent> walks;
  final void Function(WalkEvent) onOpen;
  final void Function(WalkEvent) onJoin;
  final VoidCallback onFindWalks;
  final VoidCallback onCreateWalk;

  /// For tests; defaults to the current time.
  final DateTime? now;

  /// How many days the strip at the top covers.
  static const stripDays = 14;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFilter _filter = CalendarFilter.all;

  /// A day picked in the strip; null shows everything coming up.
  DateTime? _day;

  DateTime get _now => widget.now ?? DateTime.now();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  static DateTime _dateOf(WalkEvent w) =>
      DateTime(w.dateTime.year, w.dateTime.month, w.dateTime.day);

  /// Upcoming (or still running) walks that are mine in some way.
  List<WalkEvent> get _mine {
    final cutoff = _now.subtract(const Duration(hours: 3));
    final list = widget.walks.where((w) {
      if (w.cancelled || w.status == 'completed' || w.status == 'ended') {
        return false;
      }
      if (!(w.isOwner || w.joined || w.interested)) return false;
      return w.status == 'active' || w.dateTime.isAfter(cutoff);
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  bool _matches(WalkEvent w) => switch (_filter) {
    CalendarFilter.all => true,
    CalendarFilter.hosting => w.isOwner,
    CalendarFilter.joined => w.joined && !w.isOwner,
    CalendarFilter.starred => w.interested && !w.joined && !w.isOwner,
  };

  /// Dot colour for a walk: coral = hosting, lime = joined, blue = starred.
  static Color _kindColor(WalkEvent w) => w.isOwner
      ? AppPalette.coral
      : w.joined
      ? AppPalette.lime
      : AppPalette.blue;

  String _dayLabel(DateTime d) {
    final diff = d.difference(_today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return DateFormat('EEEE').format(d);
    return DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final mine = _mine;
    final shown = mine
        .where(_matches)
        .where((w) => _day == null || _dateOf(w) == _day)
        .toList();

    // Group by day, in date order.
    final groups = <DateTime, List<WalkEvent>>{};
    for (final w in shown) {
      groups.putIfAbsent(_dateOf(w), () => []).add(w);
    }

    final weekEnd = _today.add(const Duration(days: 7));
    final thisWeek = mine.where((w) => _dateOf(w).isBefore(weekEnd)).length;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            0,
            AppSpace.lg,
            0,
            FloatingNavBar.reservedHeight,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calendar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: AppText.headlineScaler(context),
                    style: AppText.display(40, color: p.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thisWeek == 0
                        ? 'Nothing planned in the next 7 days'
                        : '$thisWeek walk${thisWeek == 1 ? '' : 's'} '
                              'in the next 7 days',
                    style: AppText.body(15, color: p.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            _DayStrip(
              start: _today,
              days: CalendarScreen.stripDays,
              selected: _day,
              dotsFor: (d) => [
                for (final w in mine.where(_matches))
                  if (_dateOf(w) == d) _kindColor(w),
              ],
              onSelect: (d) => setState(() => _day = _day == d ? null : d),
            ),
            const SizedBox(height: AppSpace.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Row(
                children: [
                  for (final (f, label, dot) in [
                    (CalendarFilter.all, 'All', null),
                    (CalendarFilter.hosting, 'Hosting', AppPalette.coral),
                    (CalendarFilter.joined, 'Joined', AppPalette.lime),
                    (CalendarFilter.starred, 'Starred', AppPalette.blue),
                  ]) ...[
                    _FilterPill(
                      label: label,
                      dot: dot,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: AppSpace.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            if (_day != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  0,
                  AppSpace.page,
                  AppSpace.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _day = null),
                    style: TextButton.styleFrom(foregroundColor: p.text),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(
                      'Show all days',
                      style: AppText.body(14, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                child: _EmptyCard(
                  dayPicked: _day != null,
                  onFindWalks: widget.onFindWalks,
                  onCreateWalk: widget.onCreateWalk,
                ),
              )
            else
              for (final MapEntry(key: day, value: walks) in groups.entries)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    0,
                    AppSpace.page,
                    AppSpace.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: Text(
                          _dayLabel(day),
                          textScaler: AppText.headlineScaler(context),
                          style: AppText.display(24, color: p.text),
                        ),
                      ),
                      for (final w in walks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: WalkRow(
                            walk: w,
                            onOpen: () => widget.onOpen(w),
                            onJoin: () => widget.onJoin(w),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Two weeks of days you can scroll sideways; dots mark days with walks.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.start,
    required this.days,
    required this.selected,
    required this.dotsFor,
    required this.onSelect,
  });

  final DateTime start;
  final int days;
  final DateTime? selected;
  final List<Color> Function(DateTime day) dotsFor;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // The day tiles keep a fixed size; their text doesn't grow with the
    // phone's text setting beyond a little (like badges elsewhere).
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
        itemCount: days,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) {
          final d = DateTime(start.year, start.month, start.day + i);
          final isSelected = selected == d;
          final isToday = i == 0;
          final dots = dotsFor(d);
          final fg = isSelected ? AppPalette.ink : p.text;
          return Semantics(
            button: true,
            selected: isSelected,
            label:
                DateFormat('EEEE d MMMM').format(d) +
                (dots.isEmpty
                    ? ''
                    : ', ${dots.length} walk${dots.length == 1 ? '' : 's'}'),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelect(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 60,
                decoration: BoxDecoration(
                  color: isSelected ? AppPalette.lime : p.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isToday && !isSelected ? p.text : p.border,
                    width: isToday && !isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(d).toUpperCase(),
                      textScaler: scaler,
                      style: AppText.body(
                        11,
                        color: isSelected ? AppPalette.ink : p.textMuted,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      textScaler: scaler,
                      style: AppText.display(22, color: fg),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in dots.take(3))
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: AppPalette.ink)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppPalette.lime : p.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppPalette.lime : p.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: AppPalette.ink, width: 1.5)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppText.body(
                    14,
                    color: selected ? AppPalette.ink : p.text,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.dayPicked,
    required this.onFindWalks,
    required this.onCreateWalk,
  });

  final bool dayPicked;
  final VoidCallback onFindWalks;
  final VoidCallback onCreateWalk;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayPicked ? 'Nothing on this day' : 'Nothing planned yet',
            textScaler: AppText.headlineScaler(context),
            style: AppText.display(26, color: p.text),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Walks you host, join or star show up here, day by day.',
            style: AppText.body(15, color: p.textMuted),
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              PillButton(
                label: 'Find a walk',
                icon: Icons.search_rounded,
                onPressed: onFindWalks,
                dark: false,
              ),
              PillButton(
                label: 'Create a walk',
                icon: Icons.add_rounded,
                onPressed: onCreateWalk,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

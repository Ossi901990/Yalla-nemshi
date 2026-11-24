// lib/screens/home/home_tab.dart
//
// Home tab of the 2026 redesign (docs/design/home-dark.png, home-light.png).
// Pure UI: all data and actions come from HomeScreen, which keeps the state
// and the Firestore logic.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/walk_event.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/floating_nav_bar.dart';
import '../../widgets/ui/ui_kit.dart';
import '../../widgets/user_avatar.dart';

/// What the big card at the top shows.
enum HomeHeroMode {
  /// You host a walk that's in progress.
  hostActive,

  /// You host the next walk (not started yet).
  hostUpcoming,

  /// A walk you joined is in progress.
  joinedActive,

  /// You joined the next walk (not started yet).
  joinedUpcoming,

  /// Nothing planned by you: suggest the next open walk ("I'm in").
  suggested,
}

class HomeTabActions {
  const HomeTabActions({
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onSearch,
    required this.onOpenWalk,
    required this.onJoin,
    required this.onStartHosted,
    required this.onConfirmHere,
    required this.onOpenActive,
    required this.onCreateWalk,
    required this.onBrowseWalks,
    required this.onRefresh,
  });

  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onSearch;
  final ValueChanged<WalkEvent> onOpenWalk;
  final ValueChanged<WalkEvent> onJoin;
  final ValueChanged<WalkEvent> onStartHosted;
  final ValueChanged<WalkEvent> onConfirmHere;
  final ValueChanged<WalkEvent> onOpenActive;
  final VoidCallback onCreateWalk;
  final VoidCallback onBrowseWalks;
  final Future<void> Function() onRefresh;
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.currentUid,
    required this.userName,
    required this.photoUrl,
    required this.unreadCount,
    required this.walks,
    required this.heroWalk,
    required this.heroMode,
    required this.canStartHosted,
    required this.heroBusy,
    required this.streakDays,
    required this.weeklyKm,
    required this.weeklyGoalKm,
    required this.actions,
    this.banners = const [],
  });

  /// Signed-in user's id (null when signed out).
  final String? currentUid;
  final String userName;
  final String? photoUrl;
  final int unreadCount;

  /// All walks loaded on the home list (upcoming/active, not cancelled).
  final List<WalkEvent> walks;
  final WalkEvent? heroWalk;
  final HomeHeroMode? heroMode;
  final bool canStartHosted;
  final bool heroBusy;
  final int streakDays;
  final double weeklyKm;
  final double weeklyGoalKm;
  final HomeTabActions actions;

  /// Offline / syncing / verify-email banners, shown above the content.
  final List<Widget> banners;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final open = walks.where((w) => !w.cancelled).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final upcoming = open
        .where((w) => w.dateTime.isAfter(now) && w != heroWalk)
        .toList();
    final nearbyCount = open
        .where((w) => !w.isOwner && w.dateTime.isAfter(now))
        .length;

    return ColoredBox(
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: actions.onRefresh,
          color: AppPalette.ink,
          backgroundColor: AppPalette.lime,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.lg,
              AppSpace.page,
              FloatingNavBar.reservedHeight,
            ),
            children: [
              ...banners,
              _Header(
                userName: userName,
                photoUrl: photoUrl,
                unreadCount: unreadCount,
                actions: actions,
              ),
              const SizedBox(height: AppSpace.xl),
              if (heroWalk != null && heroMode != null)
                _HeroCard(
                  currentUid: currentUid,
                  walk: heroWalk!,
                  mode: heroMode!,
                  canStart: canStartHosted,
                  busy: heroBusy,
                  actions: actions,
                )
              else
                _EmptyHero(actions: actions),
              const SizedBox(height: AppSpace.lg),
              _NearbyMapCard(count: nearbyCount, onTap: actions.onBrowseWalks),
              const SizedBox(height: AppSpace.xxl),
              SectionHeader(
                title: 'Coming up',
                action: upcoming.isEmpty ? null : 'See all',
                onAction: actions.onBrowseWalks,
              ),
              if (upcoming.isEmpty)
                _EmptyNote(
                  text: 'No other walks coming up nearby yet.',
                  actionLabel: 'Create one',
                  onAction: actions.onCreateWalk,
                )
              else
                for (final w in upcoming.take(3)) ...[
                  _ComingUpRow(walk: w, actions: actions),
                  const SizedBox(height: AppSpace.md),
                ],
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'This week'),
              _WeekStrip(walks: open),
              const SizedBox(height: AppSpace.lg),
              _StatCards(
                streakDays: streakDays,
                walkingWith: _peopleThisWeek(open, now, currentUid),
              ),
              const SizedBox(height: AppSpace.lg),
              _WeeklyGoal(km: weeklyKm, goalKm: weeklyGoalKm),
            ],
          ),
        ),
      ),
    );
  }

  /// Distinct people (other than me) in my walks this week.
  static int _peopleThisWeek(List<WalkEvent> walks, DateTime now, String? me) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final people = <String>{};
    for (final w in walks) {
      if (!(w.joined || w.isOwner)) continue;
      if (w.dateTime.isBefore(start) || !w.dateTime.isBefore(end)) continue;
      people.add(w.hostUid);
      people.addAll(w.joinedUserUids);
    }
    people.remove(me);
    people.remove('');
    return people.length;
  }
}

// ---------------------------------------------------------------- helpers

/// "Tonight · 19:30", "Tomorrow · 07:00", "Tue 24 Nov · 07:00".
String _whenLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final time = DateFormat('HH:mm').format(t);
  final diff = day.difference(today).inDays;
  if (diff == 0) return '${t.hour >= 17 ? 'Tonight' : 'Today'} · $time';
  if (diff == 1) return 'Tomorrow · $time';
  return '${DateFormat('EEE d MMM').format(t)} · $time';
}

/// "Starts in 40 min" / "Starts in 3 h" within a day; empty otherwise (the
/// date label already says "Tomorrow" etc.).
String _startsIn(DateTime t) {
  final d = t.difference(DateTime.now());
  if (d.isNegative) return 'Starting now';
  if (d.inMinutes < 60) return 'Starts in ${d.inMinutes} min';
  if (d.inHours < 24) return 'Starts in ${d.inHours} h';
  return '';
}

String _details(WalkEvent w) {
  final parts = <String>[
    if ((w.meetingPlaceName ?? '').trim().isNotEmpty)
      w.meetingPlaceName!.trim()
    else if ((w.city ?? '').trim().isNotEmpty)
      w.city!.trim(),
    if (w.distanceKm > 0) '${_km(w.distanceKm)} km',
    if (w.pace.trim().isNotEmpty) '${w.pace.toLowerCase()} pace',
  ];
  return parts.join(' · ');
}

String _km(double km) =>
    km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

/// Chip colour by when the walk is: lime = today/tomorrow, coral = weekend,
/// blue = other days.
Color _chipColor(DateTime t) {
  final now = DateTime.now();
  final days = DateTime(
    t.year,
    t.month,
    t.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days <= 1) return AppPalette.lime;
  if (t.weekday >= DateTime.saturday) return AppPalette.coral;
  return AppPalette.blue;
}

List<AvatarStackPerson> _people(WalkEvent w) => [
  for (var i = 0; i < w.joinedUserNames.length; i++)
    AvatarStackPerson(
      w.joinedUserNames[i],
      i < w.joinedUserPhotoUrls.length ? w.joinedUserPhotoUrls[i] : null,
    ),
];

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({
    required this.userName,
    required this.photoUrl,
    required this.unreadCount,
    required this.actions,
  });

  final String userName;
  final String? photoUrl;
  final int unreadCount;
  final HomeTabActions actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = userName.trim().split(RegExp(r'\s+')).first;

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundIconButton(
          icon: Icons.search_rounded,
          onTap: actions.onSearch,
          tooltip: 'Search walks',
          size: 48,
        ),
        const SizedBox(width: AppSpace.sm),
        RoundIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: actions.onOpenNotifications,
          badgeCount: unreadCount,
          tooltip: 'Notifications',
          size: 48,
        ),
        const SizedBox(width: AppSpace.sm),
        Semantics(
          button: true,
          label: 'Your profile',
          child: GestureDetector(
            onTap: actions.onOpenProfile,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.lime, width: 3),
              ),
              child: _InitialsAvatar(
                name: userName,
                photoUrl: photoUrl,
                background: p.limeSoft,
                foreground: isDark ? AppPalette.lime : AppPalette.ink,
              ),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 52 on a normal phone, smaller on narrow screens.
        final size = (constraints.maxWidth * 0.15).clamp(36.0, 52.0);
        // Shorter date on narrow phones so the pill isn't cut off.
        final date = DateFormat(
          constraints.maxWidth < 330 ? 'd MMM' : 'EEE · d MMM',
        ).format(DateTime.now()).toUpperCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PillLabel(text: date),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                buttons,
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'Yalla,\n${first.isEmpty ? 'walker' : first}!',
              style: AppText.display(size, color: p.text, height: 0.98),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

/// Initials (or photo) on a soft lime circle, as in the mock-up.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.name,
    required this.photoUrl,
    required this.background,
    required this.foreground,
  });

  final String name;
  final String? photoUrl;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 21,
      backgroundColor: background,
      foregroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        UserAvatar.initialsFor(name),
        style: AppText.body(16, color: foreground, weight: FontWeight.w800),
      ),
    );
  }
}

// ---------------------------------------------------------------- hero

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.currentUid,
    required this.walk,
    required this.mode,
    required this.canStart,
    required this.busy,
    required this.actions,
  });

  final String? currentUid;
  final WalkEvent walk;
  final HomeHeroMode mode;
  final bool canStart;
  final bool busy;
  final HomeTabActions actions;

  @override
  Widget build(BuildContext context) {
    final uid = currentUid;
    final needsConfirm =
        mode == HomeHeroMode.joinedActive &&
        (uid == null || walk.participantStates[uid] != 'confirmed');

    final (String pill, Color dot) = switch (mode) {
      HomeHeroMode.hostActive ||
      HomeHeroMode.joinedActive => ('Walk in progress', AppPalette.coral),
      HomeHeroMode.hostUpcoming => ("You're hosting", AppPalette.teal),
      HomeHeroMode.joinedUpcoming => ("You're in", AppPalette.teal),
      HomeHeroMode.suggested => (
        walk.dateTime.difference(DateTime.now()).inHours < 3
            ? 'Starting soon'
            : 'Next walk',
        AppPalette.coral,
      ),
    };

    final (String label, VoidCallback onTap, IconData? icon) = switch (mode) {
      HomeHeroMode.hostActive => (
        'Open walk',
        () => actions.onOpenActive(walk),
        null,
      ),
      HomeHeroMode.joinedActive =>
        needsConfirm
            ? ("I'm here", () => actions.onConfirmHere(walk), null)
            : ('Open walk', () => actions.onOpenActive(walk), null),
      HomeHeroMode.hostUpcoming =>
        canStart
            ? ('Start walk', () => actions.onStartHosted(walk), null)
            : ('Details', () => actions.onOpenWalk(walk), null),
      HomeHeroMode.joinedUpcoming => (
        "You're in",
        () => actions.onOpenWalk(walk),
        Icons.check_rounded,
      ),
      HomeHeroMode.suggested => ("I'm in", () => actions.onJoin(walk), null),
    };

    final people = _people(walk);
    final extra = (walk.joinedCount - people.take(3).length).clamp(0, 999);
    final countdown = mode == HomeHeroMode.hostUpcoming
        ? _startsIn(walk.dateTime)
        : '';
    final subtitle = [
      if (countdown.isNotEmpty) countdown,
      if (_details(walk).isNotEmpty) _details(walk),
    ].join(' · ');

    return AppCard(
      color: AppPalette.lime,
      shadowColor: AppPalette.coral,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      onTap: () => actions.onOpenWalk(walk),
      child: Stack(
        children: [
          const Positioned(
            right: -6,
            top: -6,
            width: 150,
            height: 120,
            child: IgnorePointer(child: CustomPaint(painter: _TrailPainter())),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.md,
                runSpacing: AppSpace.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PillLabel(
                    text: pill,
                    background: AppPalette.ink,
                    foreground: Colors.white,
                    dotColor: dot,
                  ),
                  Text(
                    _whenLabel(walk.dateTime),
                    style: AppText.body(
                      15,
                      color: AppPalette.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Padding(
                padding: const EdgeInsets.only(right: 40),
                child: Text(
                  walk.title.isEmpty ? 'Untitled walk' : walk.title,
                  style: AppText.display(
                    34,
                    color: AppPalette.ink,
                    height: 1.05,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  subtitle,
                  style: AppText.body(
                    15,
                    color: AppPalette.ink.withValues(alpha: 0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: people.isEmpty
                          ? Text(
                              walk.joinedCount == 0
                                  ? 'Be the first to join'
                                  : '${walk.joinedCount} going',
                              style: AppText.body(
                                14,
                                color: AppPalette.ink,
                                weight: FontWeight.w700,
                              ),
                            )
                          : AvatarStack(people: people, extra: extra),
                    ),
                  ),
                  PillButton(
                    label: label,
                    icon: icon,
                    onPressed: onTap,
                    busy: busy,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dotted route + end dot in the hero's top-right corner.
class _TrailPainter extends CustomPainter {
  const _TrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, size.height * 0.08)
      ..cubicTo(
        size.width * 0.55,
        size.height * 0.05,
        size.width * 0.62,
        size.height * 0.55,
        size.width * 0.32,
        size.height * 0.92,
      );
    final paint = Paint()
      ..color = const Color(0xFF8FB12A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 13) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.92),
      11,
      Paint()..color = AppPalette.ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.actions});
  final HomeTabActions actions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppPalette.lime,
      shadowColor: AppPalette.coral,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PillLabel(
            text: 'Nothing planned',
            background: AppPalette.ink,
            foreground: Colors.white,
            dotColor: AppPalette.coral,
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Where are we\nwalking next?',
            style: AppText.display(34, color: AppPalette.ink, height: 1.05),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Start your own walk or join one near you.',
            style: AppText.body(
              15,
              color: AppPalette.ink.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.md,
            children: [
              PillButton(
                label: 'Create a walk',
                onPressed: actions.onCreateWalk,
              ),
              TextButton(
                onPressed: actions.onBrowseWalks,
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.ink,
                  textStyle: AppText.body(16, weight: FontWeight.w800),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                ),
                child: const Text('Browse walks →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- map card

class _NearbyMapCard extends StatelessWidget {
  const _NearbyMapCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = switch (count) {
      0 => 'No walks near you yet',
      1 => '1 walk near you',
      _ => '$count walks near you',
    };
    return AppCard(
      color: isDark ? p.surface : p.surfaceMuted,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _MiniMapPainter(isDark: isDark)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.display(28, color: p.text, weight: 750),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Open the map →',
                    style: AppText.body(16, color: p.textMuted),
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

/// Decorative streets, river and walk pins.
class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final road = Paint()
      ..color = isDark ? const Color(0xFF1E3138) : Colors.white
      ..strokeWidth = 12;
    canvas.drawLine(Offset(w * 0.6, 0), Offset(w * 0.64, h), road);
    canvas.drawLine(Offset(w * 0.86, 0), Offset(w * 0.88, h), road);
    canvas.drawLine(Offset(0, h * 0.84), Offset(w, h * 0.9), road);
    canvas.drawLine(Offset(0, h * 0.27), Offset(w, h * 0.22), road);

    final river = Paint()
      ..color = isDark ? const Color(0xFF214A57) : const Color(0xFFBFDDE3)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, h * 1.05)
        ..cubicTo(w * 0.62, h * 0.85, w * 0.7, h * 0.6, w * 0.8, h * 0.45)
        ..cubicTo(w * 0.88, h * 0.35, w * 0.95, h * 0.38, w * 1.02, h * 0.36),
      river,
    );

    void pin(double x, double y, Color c) {
      canvas.drawCircle(Offset(x, y), 15, Paint()..color = AppPalette.ink);
      canvas.drawCircle(Offset(x, y), 11.5, Paint()..color = c);
    }

    pin(w * 0.7, h * 0.43, AppPalette.lime);
    pin(w * 0.85, h * 0.72, AppPalette.lime);
    pin(w * 0.92, h * 0.23, AppPalette.coral);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => old.isDark != isDark;
}

// ---------------------------------------------------------------- coming up

class _ComingUpRow extends StatelessWidget {
  const _ComingUpRow({required this.walk, required this.actions});
  final WalkEvent walk;
  final HomeTabActions actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final going = walk.joinedCount;
    final place = (walk.meetingPlaceName ?? walk.city ?? '').trim();
    final subtitle = [
      if (place.isNotEmpty) place,
      walk.isOwner ? 'you host' : '$going going',
    ].join(' · ');

    final Widget trailing;
    if (walk.isOwner) {
      trailing = const SizedBox.shrink();
    } else if (walk.joined) {
      trailing = RoundIconButton(
        icon: Icons.check_rounded,
        onTap: () => actions.onOpenWalk(walk),
        background: AppPalette.lime,
        foreground: AppPalette.ink,
        tooltip: "You're in",
        size: 48,
      );
    } else {
      trailing = RoundIconButton(
        icon: Icons.add_rounded,
        onTap: () => actions.onJoin(walk),
        // Dark mock-up: muted circle + lime icon; light: ink circle + lime icon.
        background: isDark ? p.surfaceMuted : AppPalette.ink,
        foreground: AppPalette.lime,
        tooltip: 'Join',
        size: 48,
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => actions.onOpenWalk(walk),
      child: Row(
        children: [
          TimeChip(
            day: DateFormat('EEE').format(walk.dateTime).toUpperCase(),
            time: DateFormat('HH:mm').format(walk.dateTime),
            color: _chipColor(walk.dateTime),
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
          const SizedBox(width: AppSpace.sm),
          trailing,
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: AppText.body(15, color: p.textMuted)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: p.text),
              child: Text(
                actionLabel!,
                style: AppText.body(15, weight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- this week

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.walks});
  final List<WalkEvent> walks;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Like the mock-up: today first, then the next six days.
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];

    bool hasMine(DateTime d) => walks.any(
      (w) => (w.joined || w.isOwner) && DateUtils.isSameDay(w.dateTime, d),
    );
    bool hasAny(DateTime d) =>
        walks.any((w) => DateUtils.isSameDay(w.dateTime, d));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Builder(
                builder: (context) {
                  final isToday = d == today;
                  final mine = hasMine(d);
                  final dot = mine
                      ? (isToday ? AppPalette.ink : AppPalette.lime)
                      : (hasAny(d) ? AppPalette.coral : null);
                  return Semantics(
                    label:
                        DateFormat('EEEE d').format(d) +
                        (mine
                            ? ', you have a walk'
                            : (dot != null ? ', walks nearby' : '')),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isToday ? AppPalette.lime : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(d).substring(0, 1),
                            style: AppText.body(
                              13,
                              color: isToday ? AppPalette.ink : p.text,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.day}',
                            style: AppText.display(
                              22,
                              color: isToday ? AppPalette.ink : p.text,
                              weight: 750,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dot ?? Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCards extends StatelessWidget {
  const _StatCards({required this.streakDays, required this.walkingWith});
  final int streakDays;
  final int walkingWith;

  @override
  Widget build(BuildContext context) {
    Widget card(
      Color color,
      String title,
      String value,
      String unit,
      String note,
    ) {
      return Expanded(
        child: AppCard(
          color: color,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.body(
                  15,
                  color: AppPalette.ink,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppText.display(48, color: AppPalette.ink),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: AppText.body(
                        18,
                        color: AppPalette.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: AppText.body(
                  13,
                  color: AppPalette.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(
            AppPalette.coral,
            'Streak',
            '$streakDays',
            streakDays == 1 ? 'day' : 'days',
            streakDays == 0 ? 'Join a walk to start one' : 'Keep it going!',
          ),
          const SizedBox(width: AppSpace.md),
          card(
            AppPalette.blue,
            'Walking with',
            '$walkingWith',
            walkingWith == 1 ? 'person' : 'people',
            walkingWith == 0 ? 'Join a walk to meet people' : 'this week',
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoal extends StatelessWidget {
  const _WeeklyGoal({required this.km, required this.goalKm});
  final double km;
  final double goalKm;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final progress = goalKm <= 0 ? 0.0 : (km / goalKm).clamp(0.0, 1.0);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly goal',
                  style: AppText.body(
                    15,
                    color: p.text,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_km(km)} / ${_km(goalKm)} km',
                style: AppText.body(
                  15,
                  color: p.textMuted,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress == 0 ? 0.02 : progress,
              minHeight: 14,
              backgroundColor: p.surfaceMuted,
              color: AppPalette.lime,
            ),
          ),
        ],
      ),
    );
  }
}

// lib/screens/walk_details/walk_details_view.dart
//
// Walk details in the 2026 style (same system as the Home redesign).
// Pure UI: the walk, the signed-in user and every action come from
// EventDetailsScreen, which keeps the Firestore logic. Pieces that load their
// own data (host rating, participants, photos, invite tools) are passed in as
// widgets so this view can be tested without Firebase.
import 'package:flutter/material.dart';

import '../../models/walk_event.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/walk_format.dart';
import '../../widgets/ui/ui_kit.dart';

class WalkDetailsActions {
  const WalkDetailsActions({
    required this.onBack,
    required this.onJoin,
    required this.onLeave,
    required this.onChat,
    required this.onStart,
    required this.onEnd,
    required this.onOpenActive,
    required this.onConfirmHere,
    required this.onDecline,
    required this.onToggleInterested,
    required this.onReport,
    required this.onCancel,
    required this.onCancelOccurrence,
    required this.onCancelSeries,
  });

  final VoidCallback onBack;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onChat;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onOpenActive;
  final VoidCallback onConfirmHere;
  final VoidCallback onDecline;
  final VoidCallback onToggleInterested;
  final VoidCallback onReport;
  final VoidCallback onCancel;
  final VoidCallback onCancelOccurrence;
  final VoidCallback onCancelSeries;
}

/// Where the signed-in user stands with this walk.
enum WalkRole { visitor, joined, host }

class WalkDetailsView extends StatelessWidget {
  const WalkDetailsView({
    super.key,
    required this.walk,
    required this.currentUid,
    required this.isConfirmed,
    required this.actions,
    this.hostRating,
    this.participants,
    this.photos,
    this.inviteTools,
    this.activeCount,
  });

  final WalkEvent walk;
  final String? currentUid;

  /// The user checked in ("I'm here") for an active walk.
  final bool isConfirmed;
  final WalkDetailsActions actions;

  /// Optional pieces that load their own data.
  final Widget? hostRating;
  final Widget? participants;
  final Widget? photos;
  final Widget? inviteTools;

  /// Walkers checked in, when the walk is active (host view).
  final int? activeCount;

  WalkRole get role => walk.isOwner
      ? WalkRole.host
      : (walk.joined ? WalkRole.joined : WalkRole.visitor);

  bool get _active => walk.status == 'active';
  bool get _ended =>
      walk.status == 'completed' ||
      walk.status == 'ended' ||
      walk.status == 'completed_late';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.md,
            AppSpace.page,
            AppSpace.xxl,
          ),
          children: [
            _TopBar(walk: walk, actions: actions),
            const SizedBox(height: AppSpace.lg),
            _Hero(walk: walk, role: role, active: _active, ended: _ended),
            const SizedBox(height: AppSpace.lg),
            _Facts(walk: walk),
            const SizedBox(height: AppSpace.xl),
            _Section(
              title: 'Meeting point',
              child: _MeetingPoint(walk: walk),
            ),
            _Section(
              title: 'Host',
              child: _HostCard(walk: walk, rating: hostRating),
            ),
            if (participants != null)
              _Section(
                title: "Who's going",
                child: AppCard(child: participants!),
              ),
            if (photos != null) photos!,
            if ((walk.description ?? '').trim().isNotEmpty)
              _Section(
                title: 'About this walk',
                child: AppCard(
                  child: Text(
                    walk.description!.trim(),
                    style: AppText.body(15, color: p.text, height: 1.5),
                  ),
                ),
              ),
            if (walk.isRecurring &&
                !walk.isRecurringTemplate &&
                walk.recurrence != null)
              _Section(
                title: 'Repeats',
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.repeat_rounded, color: p.text),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          walk.recurrence!.getDescription(),
                          style: AppText.body(15, color: p.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (role == WalkRole.host && !walk.cancelled && !_ended)
              _HostTools(
                walk: walk,
                inviteTools: inviteTools,
                activeCount: _active ? activeCount : null,
                actions: actions,
              ),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        walk: walk,
        role: role,
        active: _active,
        ended: _ended,
        isConfirmed: isConfirmed,
        actions: actions,
      ),
    );
  }
}

// ------------------------------------------------------------------ top bar

class _TopBar extends StatelessWidget {
  const _TopBar({required this.walk, required this.actions});
  final WalkEvent walk;
  final WalkDetailsActions actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final canInterest = !walk.isOwner && !walk.cancelled;
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: actions.onBack,
          tooltip: 'Back',
          size: 48,
        ),
        const Spacer(),
        if (canInterest) ...[
          RoundIconButton(
            icon: walk.interested
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            onTap: actions.onToggleInterested,
            tooltip: walk.interested ? 'Remove from interested' : 'Interested',
            size: 48,
            background: walk.interested ? AppPalette.lime : null,
            foreground: walk.interested ? AppPalette.ink : null,
          ),
          const SizedBox(width: AppSpace.sm),
        ],
        Material(
          color: p.surface,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          child: PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_horiz_rounded, color: p.text),
            onSelected: (v) {
              if (v == 'report') actions.onReport();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report this walk'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({
    required this.walk,
    required this.role,
    required this.active,
    required this.ended,
  });

  final WalkEvent walk;
  final WalkRole role;
  final bool active;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final (String label, Color dot) = walk.cancelled
        ? ('Cancelled', const Color(0xFFE5484D))
        : ended
        ? ('Walk ended', AppPalette.blue)
        : active
        ? ('Walk in progress', AppPalette.coral)
        : switch (role) {
            WalkRole.host => ("You're hosting", AppPalette.teal),
            WalkRole.joined => ("You're in", AppPalette.teal),
            WalkRole.visitor => (
              walk.isPrivate ? 'Private walk' : 'Open walk',
              AppPalette.coral,
            ),
          };

    final place = (walk.meetingPlaceName ?? walk.city ?? '').trim();
    final names = walk.joinedUserNames;
    final people = [
      for (var i = 0; i < names.length; i++)
        AvatarStackPerson(
          names[i],
          i < walk.joinedUserPhotoUrls.length
              ? walk.joinedUserPhotoUrls[i]
              : null,
        ),
    ];
    final extra = (walk.joinedCount - people.take(3).length).clamp(0, 999);
    final faded = walk.cancelled || ended;

    return Opacity(
      opacity: faded ? 0.75 : 1,
      child: AppCard(
        color: AppPalette.lime,
        shadowColor: faded ? null : AppPalette.coral,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PillLabel(
                  text: label,
                  background: AppPalette.ink,
                  foreground: Colors.white,
                  dotColor: dot,
                ),
                Text(
                  WalkFormat.when(walk.dateTime),
                  style: AppText.body(
                    15,
                    color: AppPalette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            LayoutBuilder(
              builder: (context, c) => Text(
                walk.title.isEmpty ? 'Untitled walk' : walk.title,
                textScaler: AppText.headlineScaler(context),
                style: AppText.display(
                  (c.maxWidth * 0.11).clamp(24.0, 34.0),
                  color: AppPalette.ink,
                  height: 1.05,
                ),
              ),
            ),
            if (place.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: AppPalette.ink,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        15,
                        color: AppPalette.ink.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Wrap(
              spacing: AppSpace.md,
              runSpacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (people.isNotEmpty)
                  AvatarStack(people: people, extra: extra),
                Text(
                  walk.joinedCount == 0
                      ? 'Be the first to join'
                      : '${walk.joinedCount} going',
                  style: AppText.body(
                    14,
                    color: AppPalette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- facts

class _Facts extends StatelessWidget {
  const _Facts({required this.walk});
  final WalkEvent walk;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String)>[
      if (walk.distanceKm > 0)
        (Icons.straighten_rounded, '${WalkFormat.km(walk.distanceKm)} km'),
      if ((walk.plannedDurationMinutes ?? 0) > 0)
        (Icons.schedule_rounded, '${walk.plannedDurationMinutes} min'),
      if (walk.pace.trim().isNotEmpty)
        (Icons.directions_walk_rounded, '${walk.pace} pace'),
      if (walk.gender.trim().isNotEmpty) (Icons.group_rounded, walk.gender),
      if (walk.isPrivate) (Icons.lock_rounded, 'Private'),
      if (walk.isRecurring && !walk.isRecurringTemplate)
        (Icons.repeat_rounded, 'Repeats'),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final (icon, label) in facts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppSpace.radiusPill),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: p.text),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      14,
                      color: p.text,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- sections

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textScaler: AppText.headlineScaler(context),
            style: AppText.display(24, color: p.text, weight: 750),
          ),
          const SizedBox(height: AppSpace.md),
          child,
        ],
      ),
    );
  }
}

class _MeetingPoint extends StatelessWidget {
  const _MeetingPoint({required this.walk});
  final WalkEvent walk;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = (walk.meetingPlaceName ?? '').trim();
    final lat = walk.meetingLat ?? walk.startLat;
    final lng = walk.meetingLng ?? walk.startLng;
    final coords = (lat != null && lng != null)
        ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
        : null;
    final city = (walk.city ?? '').trim();

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: p.limeSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.place_rounded,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.lime
                  : AppPalette.ink,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty
                      ? name
                      : (city.isNotEmpty ? city : 'Location on the map'),
                  style: AppText.body(
                    16,
                    color: p.text,
                    weight: FontWeight.w800,
                  ),
                ),
                if (name.isNotEmpty && city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(city, style: AppText.body(14, color: p.textMuted)),
                ],
                if (name.isEmpty && coords != null) ...[
                  const SizedBox(height: 2),
                  Text(coords, style: AppText.body(13, color: p.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.walk, this.rating});
  final WalkEvent walk;
  final Widget? rating;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rawName = (walk.hostName ?? '').trim();
    final name = walk.isOwner
        ? 'You'
        : (rawName.isNotEmpty ? rawName : 'Walk host');
    final photo = walk.hostPhotoUrl;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppPalette.peach,
            foregroundImage: (photo != null && photo.isNotEmpty)
                ? NetworkImage(photo)
                : null,
            onForegroundImageError: (photo != null && photo.isNotEmpty)
                ? (_, _) {}
                : null,
            child: Text(
              AvatarStack.initials(rawName.isNotEmpty ? rawName : name),
              textScaler: TextScaler.noScaling,
              style: AppText.body(
                16,
                color: AppPalette.ink,
                weight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    16,
                    color: p.text,
                    weight: FontWeight.w800,
                  ),
                ),
                if (rating != null) ...[const SizedBox(height: 4), rating!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostTools extends StatelessWidget {
  const _HostTools({
    required this.walk,
    required this.inviteTools,
    required this.activeCount,
    required this.actions,
  });

  final WalkEvent walk;
  final Widget? inviteTools;
  final int? activeCount;
  final WalkDetailsActions actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const danger = Color(0xFFE5484D);
    final series =
        walk.isRecurring &&
        !walk.isRecurringTemplate &&
        walk.recurringGroupId != null;

    Widget cancelButton(String label, IconData icon, VoidCallback onTap) {
      return TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: danger,
          textStyle: AppText.body(15, weight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        ),
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return _Section(
      title: 'Host tools',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeCount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(Icons.how_to_reg_rounded, color: p.text),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(
                        '$activeCount checked in so far',
                        style: AppText.body(
                          15,
                          color: p.text,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (inviteTools != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: inviteTools!,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpace.md,
              children: series
                  ? [
                      cancelButton(
                        'Cancel this date',
                        Icons.event_busy_rounded,
                        actions.onCancelOccurrence,
                      ),
                      cancelButton(
                        'Cancel the whole series',
                        Icons.cancel_outlined,
                        actions.onCancelSeries,
                      ),
                    ]
                  : [
                      cancelButton(
                        'Cancel this walk',
                        Icons.cancel_outlined,
                        actions.onCancel,
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- action bar

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.walk,
    required this.role,
    required this.active,
    required this.ended,
    required this.isConfirmed,
    required this.actions,
  });

  final WalkEvent walk;
  final WalkRole role;
  final bool active;
  final bool ended;
  final bool isConfirmed;
  final WalkDetailsActions actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canChat =
        (role != WalkRole.visitor) &&
        walk.firestoreId.isNotEmpty &&
        !walk.cancelled;

    // (primary label, primary action, icon) + optional secondary text button
    String label;
    VoidCallback? primary;
    IconData? icon;
    String? secondaryLabel;
    VoidCallback? secondary;

    if (walk.cancelled) {
      label = 'This walk was cancelled';
    } else if (ended) {
      label = 'This walk has ended';
    } else if (role == WalkRole.host) {
      if (active) {
        label = 'End walk';
        primary = actions.onEnd;
        icon = Icons.stop_rounded;
        secondaryLabel = 'Open walk';
        secondary = actions.onOpenActive;
      } else {
        label = 'Start walk';
        primary = actions.onStart;
        icon = Icons.play_arrow_rounded;
      }
    } else if (role == WalkRole.joined) {
      if (active && !isConfirmed) {
        label = "I'm here";
        primary = actions.onConfirmHere;
        icon = Icons.how_to_reg_rounded;
        secondaryLabel = 'Not coming';
        secondary = actions.onDecline;
      } else if (active) {
        label = 'Open walk';
        primary = actions.onOpenActive;
        icon = Icons.directions_walk_rounded;
      } else {
        label = 'Group chat';
        primary = actions.onChat;
        icon = Icons.forum_rounded;
        secondaryLabel = 'Leave';
        secondary = actions.onLeave;
      }
    } else {
      label = "I'm in";
      primary = actions.onJoin;
    }

    // Chat sits next to the main button unless the main button is chat.
    final showChatButton = canChat && primary != actions.onChat;

    final secondaryButton = secondary == null
        ? null
        : TextButton(
            onPressed: secondary,
            style: TextButton.styleFrom(
              foregroundColor: p.text,
              textStyle: AppText.body(15, weight: FontWeight.w700),
            ),
            child: Text(secondaryLabel!),
          );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            12,
            AppSpace.page,
            12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // One row only if the main button keeps ~170pt next to the
              // secondary button (~120pt) and the chat button.
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final oneRow =
                  secondaryButton == null ||
                  constraints.maxWidth -
                          (showChatButton ? 60 : 0) -
                          120 * scale >=
                      170 * scale;
              final mainRow = Row(
                children: [
                  if (secondaryButton != null && oneRow) ...[
                    secondaryButton,
                    const SizedBox(width: AppSpace.sm),
                  ],
                  Expanded(
                    child: PillButton(
                      label: label,
                      icon: icon,
                      onPressed: primary,
                      // Lime on dark backgrounds, ink on light ones.
                      dark: !isDark,
                      expand: true,
                    ),
                  ),
                  if (showChatButton) ...[
                    const SizedBox(width: AppSpace.sm),
                    RoundIconButton(
                      icon: Icons.forum_rounded,
                      onTap: actions.onChat,
                      tooltip: 'Group chat',
                      size: 52,
                    ),
                  ],
                ],
              );
              if (oneRow) return mainRow;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  secondaryButton,
                  const SizedBox(height: 4),
                  mainRow,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

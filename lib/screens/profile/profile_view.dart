// lib/screens/profile/profile_view.dart
//
// Your profile in the 2026 style (same system as Home and Walk details).
// Pure UI: ProfileScreen loads the data and keeps every action. Sections that
// load their own data (lifetime stats, host rating, badges, past walks) are
// passed in as widgets so this view can be tested without Firebase.
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/floating_nav_bar.dart';
import '../../widgets/ui/ui_kit.dart';

const _danger = Color(0xFFE5484D);

class ProfileActions {
  const ProfileActions({
    required this.onFriends,
    required this.onNotifications,
    required this.onSettings,
    required this.onAvatarTap,
    required this.onEditProfile,
    required this.onAnalytics,
    required this.onSafetyTips,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onSwitchAccount,
    required this.onSignOut,
    required this.onNavTap,
    required this.onCreateWalk,
  });

  final VoidCallback onFriends;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditProfile;
  final VoidCallback onAnalytics;
  final VoidCallback onSafetyTips;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onSwitchAccount;
  final VoidCallback onSignOut;

  /// Another tab in the bottom bar (0 home, 1 walks, 2 events).
  final ValueChanged<int> onNavTap;
  final VoidCallback onCreateWalk;
}

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.name,
    required this.bio,
    required this.walkerLevel,
    required this.weeklyWalks,
    required this.weeklyKm,
    required this.weeklyGoalKm,
    required this.motivation,
    required this.walksJoined,
    required this.walksHosted,
    required this.totalKm,
    required this.interestedCount,
    required this.avatar,
    required this.actions,
    this.age,
    this.gender,
    this.banner,
    this.lifetimeStats,
    this.hostRating,
    this.badges,
    this.pastWalks,
  });

  /// Empty when the user hasn't set a name yet.
  final String name;
  final String bio;
  final String walkerLevel;
  final int? age;
  final String? gender;

  final int weeklyWalks;
  final double weeklyKm;
  final double weeklyGoalKm;
  final String motivation;

  final int walksJoined;
  final int walksHosted;
  final double totalKm;
  final int interestedCount;

  final Widget avatar;
  final ProfileActions actions;

  /// Optional pieces: an offline / stale-data banner, and sections that load
  /// their own data. [hostRating] is only shown when the user has hosted.
  final Widget? banner;
  final Widget? lifetimeStats;
  final Widget? hostRating;
  final Widget? badges;
  final Widget? pastWalks;

  double get weeklyProgress =>
      weeklyGoalKm <= 0 ? 0 : (weeklyKm / weeklyGoalKm).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final showGender = (gender ?? '').trim().isNotEmpty && gender != 'Not set';
    final showAge = (age ?? 0) > 0;

    return Scaffold(
      backgroundColor: p.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.lg,
            AppSpace.page,
            FloatingNavBar.reservedHeight + AppSpace.lg,
          ),
          children: [
            ?banner,
            // ---- Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: AppText.headlineScaler(context),
                    style: AppText.display(40, color: p.text),
                  ),
                ),
                RoundIconButton(
                  icon: Icons.group_rounded,
                  onTap: actions.onFriends,
                  tooltip: 'My friends',
                  size: 44,
                ),
                const SizedBox(width: AppSpace.sm),
                RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: actions.onNotifications,
                  tooltip: 'Notifications',
                  size: 44,
                ),
                const SizedBox(width: AppSpace.sm),
                RoundIconButton(
                  icon: Icons.settings_outlined,
                  onTap: actions.onSettings,
                  tooltip: 'Settings',
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),

            // ---- Who you are
            AppCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Semantics(
                    label: 'Change profile picture',
                    button: true,
                    child: GestureDetector(
                      onTap: actions.onAvatarTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppPalette.lime, width: 4),
                        ),
                        child: avatar,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    name.trim().isNotEmpty ? name.trim() : 'Add your name',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: AppText.headlineScaler(context),
                    style: AppText.display(30, color: p.text),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  PillLabel(text: walkerLevel.toUpperCase()),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    bio.trim().isNotEmpty
                        ? bio.trim()
                        : 'Add a short bio about you',
                    textAlign: TextAlign.center,
                    style: AppText.body(15, color: p.textMuted),
                  ),
                  if (showAge || showGender) ...[
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        if (showAge) _InfoChip(text: 'Age $age'),
                        if (showGender) _InfoChip(text: gender!),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  OutlinedButton.icon(
                    onPressed: actions.onEditProfile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.text,
                      side: BorderSide(color: p.border),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      textStyle: AppText.body(15, weight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            // ---- This week
            const SectionHeader(title: 'This week'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpace.md,
                    runSpacing: AppSpace.sm,
                    children: [
                      Text(
                        '$weeklyWalks walk${weeklyWalks == 1 ? '' : 's'} · '
                        '${weeklyKm.toStringAsFixed(1)} / '
                        '${weeklyGoalKm.toStringAsFixed(1)} km',
                        style: AppText.body(
                          16,
                          color: p.text,
                          weight: FontWeight.w800,
                        ),
                      ),
                      PillLabel(text: '${(weeklyProgress * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: weeklyProgress == 0 ? 0.02 : weeklyProgress,
                      minHeight: 14,
                      backgroundColor: p.surfaceMuted,
                      color: AppPalette.lime,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(motivation, style: AppText.body(15, color: p.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            // ---- Stats
            const SectionHeader(title: 'Your stats'),
            _StatTiles(
              tiles: [
                (AppPalette.lime, 'Walks joined', '$walksJoined'),
                (AppPalette.coral, 'Hosted', '$walksHosted'),
                (AppPalette.blue, 'Total km', totalKm.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Starred walks: $interestedCount',
              style: AppText.body(14, color: p.textMuted),
            ),
            if (lifetimeStats != null) ...[
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'Lifetime'),
              lifetimeStats!,
            ],
            if (hostRating != null && walksHosted > 0) ...[
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'As a host'),
              hostRating!,
            ],
            if (badges != null) ...[
              const SizedBox(height: AppSpace.xl),
              badges!,
            ],
            if (pastWalks != null) ...[
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'Past walks'),
              pastWalks!,
            ],
            const SizedBox(height: AppSpace.xl),

            // ---- More
            const SectionHeader(title: 'More'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    onTap: actions.onAnalytics,
                  ),
                  _ActionRow(
                    icon: Icons.shield_outlined,
                    label: 'Walking safety & community tips',
                    onTap: actions.onSafetyTips,
                  ),
                  _ActionRow(
                    icon: Icons.table_view_rounded,
                    label: 'Export walk history (CSV)',
                    onTap: actions.onExportCsv,
                  ),
                  _ActionRow(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Export walk summary (PDF)',
                    onTap: actions.onExportPdf,
                  ),
                  _ActionRow(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Switch account',
                    onTap: actions.onSwitchAccount,
                  ),
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    onTap: actions.onSignOut,
                    color: _danger,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index != 3) actions.onNavTap(index);
        },
        onCreate: actions.onCreateWalk,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
      ),
      child: Text(
        text,
        style: AppText.body(14, color: p.text, weight: FontWeight.w700),
      ),
    );
  }
}

/// Three coloured stat tiles; two or one per row on narrow phones / big text.
class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.tiles});
  final List<(Color, String, String)> tiles;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpace.md;
        var width = (c.maxWidth - gap * 2) / 3;
        if (width < 104 * scale) width = (c.maxWidth - gap) / 2;
        if (width < 104 * scale) width = c.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (color, label, value) in tiles)
              SizedBox(
                width: width,
                child: AppCard(
                  color: color,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          textScaler: AppText.headlineScaler(context),
                          style: AppText.display(34, color: AppPalette.ink),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppText.body(
                          14,
                          color: AppPalette.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One tappable row in the "More" card.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Overrides the text colour (Sign out is red).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = color ?? p.text;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c),
      title: Text(
        label,
        style: AppText.body(15, color: c, weight: FontWeight.w700),
      ),
      trailing: color == null
          ? Icon(Icons.chevron_right_rounded, color: p.textMuted)
          : null,
    );
  }
}

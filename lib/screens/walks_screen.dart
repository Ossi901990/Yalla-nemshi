// lib/screens/walks_screen.dart
import 'package:flutter/material.dart';

import '../models/walk_event.dart';
import 'nearby_walks_screen.dart';
import 'create_walk_screen.dart';
import 'walk_search_screen.dart';
import 'notifications_screen.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/ui_kit.dart';
import '../widgets/ui/floating_nav_bar.dart';
import '../widgets/walk_row.dart';

// ===== Design tokens (match HomeScreen) =====
const double kRadiusCard = 24;
const double kRadiusControl = 16;
const double kRadiusPill = 999;

const kDarkBg = Color(0xFF071B26);
const kDarkSurface = Color(0xFF0C2430);
const kDarkSurface2 = Color(0xFF0E242E);

const kTextPrimary = Color(0xFFD9F5EA);
const kTextSecondary = Color(0xFF9BB9B1);
const kTextMuted = Color(0xFF6A8580);

const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;

const kLightSurface = Color(0xFFFBFEF8);
const double kCardElevationLight = 0.6;
const double kCardElevationDark = 0.0;
const double kCardBorderAlpha = 0.06;

class WalksScreen extends StatefulWidget {
  final List<WalkEvent> myWalks;
  final List<WalkEvent> nearbyWalks;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onTapEvent;
  final void Function(WalkEvent) onCancelHosted;
  final void Function(WalkEvent) onEventCreated;
  final VoidCallback onCreatedNavigateHome;

  // Stats for profile sheet
  final int walksJoined;
  final int eventsHosted;
  final double totalKm;
  final int interestedCount;
  final double weeklyKm;
  final int weeklyWalks;
  final int streakDays;
  final double weeklyGoalKm;
  final String userName;

  // Pagination
  final bool hasMoreWalks;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  /// Open on Nearby in map mode.
  final bool openNearbyMap;

  const WalksScreen({
    super.key,
    required this.myWalks,
    required this.nearbyWalks,
    required this.onToggleJoin,
    required this.onToggleInterested,
    required this.onTapEvent,
    required this.onCancelHosted,
    required this.onEventCreated,
    required this.onCreatedNavigateHome,
    required this.walksJoined,
    required this.eventsHosted,
    required this.totalKm,
    required this.interestedCount,
    required this.weeklyKm,
    required this.weeklyWalks,
    required this.streakDays,
    required this.weeklyGoalKm,
    required this.userName,
    required this.hasMoreWalks,
    required this.isLoadingMore,
    required this.onLoadMore,
    this.openNearbyMap = false,
  });

  @override
  State<WalksScreen> createState() => _WalksScreenState();
}

class _WalksScreenState extends State<WalksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void _openWalkSearch() {
    Navigator.of(context).pushNamed(WalkSearchScreen.routeName);
  }

  void _showNotificationsSheet() {
    Navigator.pushNamed(context, NotificationsScreen.routeName);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.openNearbyMap ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                AppSpace.lg,
                AppSpace.page,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Walks',
                      textScaler: AppText.headlineScaler(context),
                      style: AppText.display(44, color: p.text),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.search_rounded,
                    onTap: _openWalkSearch,
                    tooltip: 'Search walks',
                    size: 48,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  RoundIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: _showNotificationsSheet,
                    tooltip: 'Notifications',
                    size: 48,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: _PillTabs(controller: _tabController),
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MyWalksTab(
                    hosted: widget.myWalks,
                    joined: widget.nearbyWalks.where((w) => w.joined).toList(),
                    onOpen: widget.onTapEvent,
                    onJoin: widget.onToggleJoin,
                    onCreateWalk: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateWalkScreen(
                          onEventCreated: widget.onEventCreated,
                          onCreatedNavigateHome: widget.onCreatedNavigateHome,
                        ),
                      ),
                    ),
                    onBrowse: () => _tabController.animateTo(1),
                  ),
                  NearbyWalksScreen(
                    events: widget.nearbyWalks,
                    onToggleJoin: widget.onToggleJoin,
                    onToggleInterested: widget.onToggleInterested,
                    onTapEvent: widget.onTapEvent,
                    onCancelHosted: widget.onCancelHosted,
                    walksJoined: widget.walksJoined,
                    eventsHosted: widget.eventsHosted,
                    totalKm: widget.totalKm,
                    interestedCount: widget.interestedCount,
                    weeklyKm: widget.weeklyKm,
                    weeklyWalks: widget.weeklyWalks,
                    streakDays: widget.streakDays,
                    weeklyGoalKm: widget.weeklyGoalKm,
                    userName: widget.userName,
                    hasMoreWalks: widget.hasMoreWalks,
                    isLoadingMore: widget.isLoadingMore,
                    onLoadMore: widget.onLoadMore,
                    startOnMap: widget.openNearbyMap,
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

/// "My walks | Nearby" pill tabs (lime = selected), same as Create walk.
class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpace.radiusPill),
        border: Border.all(color: p.border),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpace.radiusPill),
          color: AppPalette.lime,
        ),
        labelColor: AppPalette.ink,
        unselectedLabelColor: p.textMuted,
        labelStyle: AppText.body(15, weight: FontWeight.w800),
        unselectedLabelStyle: AppText.body(15, weight: FontWeight.w600),
        tabs: const [
          Tab(text: 'My walks'),
          Tab(text: 'Nearby'),
        ],
      ),
    );
  }
}

/// Walks you host and walks you joined that haven't finished yet.
class _MyWalksTab extends StatelessWidget {
  const _MyWalksTab({
    required this.hosted,
    required this.joined,
    required this.onOpen,
    required this.onJoin,
    required this.onCreateWalk,
    required this.onBrowse,
  });

  final List<WalkEvent> hosted;
  final List<WalkEvent> joined;
  final void Function(WalkEvent) onOpen;
  final void Function(WalkEvent) onJoin;
  final VoidCallback onCreateWalk;
  final VoidCallback onBrowse;

  static List<WalkEvent> _upcoming(List<WalkEvent> walks) {
    final now = DateTime.now();
    return walks
        .where(
          (w) =>
              !w.cancelled &&
              (w.status == 'active' ||
                  w.dateTime.isAfter(now.subtract(const Duration(hours: 1)))),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final host = _upcoming(hosted);
    final join = _upcoming(joined);

    if (host.isEmpty && join.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.md,
          AppSpace.page,
          FloatingNavBar.reservedHeight,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No walks planned yet',
                  textScaler: AppText.headlineScaler(context),
                  style: AppText.display(26, color: p.text, weight: 750),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Walks you host or join show up here.',
                  style: AppText.body(15, color: p.textMuted),
                ),
                const SizedBox(height: AppSpace.lg),
                Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.sm,
                  children: [
                    PillButton(
                      label: 'Create a walk',
                      onPressed: onCreateWalk,
                      dark: Theme.of(context).brightness != Brightness.dark,
                    ),
                    TextButton(
                      onPressed: onBrowse,
                      style: TextButton.styleFrom(
                        foregroundColor: p.text,
                        textStyle: AppText.body(16, weight: FontWeight.w800),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Browse nearby →'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget section(String title, List<WalkEvent> walks) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        for (final w in walks) ...[
          WalkRow(walk: w, onOpen: () => onOpen(w), onJoin: () => onJoin(w)),
          const SizedBox(height: AppSpace.md),
        ],
        const SizedBox(height: AppSpace.md),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.md,
        AppSpace.page,
        FloatingNavBar.reservedHeight,
      ),
      children: [
        if (host.isNotEmpty) section('Hosting', host),
        if (join.isNotEmpty) section('Joined', join),
      ],
    );
  }
}

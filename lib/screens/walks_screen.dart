// lib/screens/walks_screen.dart
import 'package:flutter/material.dart';

import '../models/walk_event.dart';
import 'nearby_walks_screen.dart';
import 'create_walk_screen.dart';

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
  });

  @override
  State<WalksScreen> createState() => _WalksScreenState();
}

class _WalksScreenState extends State<WalksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBFEF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2933),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No notifications yet. We\'ll show walk updates here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF1ABFC4),
      body: Column(
        children: [
          // ===== HEADER (matching Home screen) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: logo + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                          ),
                          child: const Icon(
                            Icons.directions_walk,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Transform.translate(
                          offset: const Offset(0, -2),
                          child: Text(
                            'Yalla Nemshi',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ) ??
                                const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),
                      ],
                    ),

                    // Right: notif
                    Semantics(
                      label: 'Notifications',
                      button: true,
                      child: GestureDetector(
                        onTap: _showNotificationsSheet,
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withAlpha(
                                  (0.1 * 255).round(),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1ABFC4), Color(0xFF1DB8C0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Transform.translate(
                            offset: const Offset(0, -2),
                            child: Text(
                              'Yalla Nemshi',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ) ??
                                  const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      Semantics(
                        label: 'Notifications',
                        button: true,
                        child: GestureDetector(
                          onTap: _showNotificationsSheet,
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white24,
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== MAIN CONTENT AREA WITH ROUNDED BACKGROUND =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? kDarkBg : const Color(0xFF1ABFC4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(kRadiusCard),
                  topRight: Radius.circular(kRadiusCard),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(kRadiusCard),
                    topRight: Radius.circular(kRadiusCard),
                  ),
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: Column(
                  children: [
                    // ===== TABS =====
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? kDarkSurface2 : const Color(0xFFF7F9F2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(kRadiusCard),
                          topRight: Radius.circular(kRadiusCard),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xFF1ABFC4),
                        indicatorWeight: 3,
                        indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
                        dividerColor: Colors.transparent,
                        labelColor: const Color(0xFF1ABFC4),
                        unselectedLabelColor: isDark ? kTextMuted : Colors.black54,
                        labelStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                        tabs: const [
                          Tab(text: 'My Walks'),
                          Tab(text: 'Nearby Walks'),
                        ],
                      ),
                    ),

                    // ===== TAB CONTENT =====
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                // ===== TAB 1: MY WALKS =====
                _MyWalksTab(
                  walks: widget.myWalks,
                  onTapEvent: widget.onTapEvent,
                ),

                // ===== TAB 2: NEARBY WALKS =====
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
                ),
              ],
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateWalkScreen(
                      onEventCreated: widget.onEventCreated,
                      onCreatedNavigateHome: widget.onCreatedNavigateHome,
                    ),
                  ),
                );
              },
              backgroundColor: isDark
                  ? const Color(0xFF1ABFC4)
                  : const Color(0xFF1ABFC4),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ===== MY WALKS TAB =====
class _MyWalksTab extends StatelessWidget {
  final List<WalkEvent> walks;
  final void Function(WalkEvent) onTapEvent;

  const _MyWalksTab({
    required this.walks,
    required this.onTapEvent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (walks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_walk,
                size: 64,
                color: isDark ? kTextMuted : Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'No walks yet',
                style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? kTextPrimary : Colors.black87,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create or join a walk to get started',
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: isDark ? kTextSecondary : Colors.black54,
                    ) ??
                    TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: isDark ? kTextSecondary : Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: walks.length,
      itemBuilder: (context, index) {
        final walk = walks[index];
        return _WalkCard(
          event: walk,
          onTap: () => onTapEvent(walk),
        );
      },
    );
  }
}

// ===== WALK CARD WIDGET (reuse from HomeScreen pattern) =====
class _WalkCard extends StatelessWidget {
  final WalkEvent event;
  final VoidCallback onTap;

  const _WalkCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isDark ? kDarkSurface : kLightSurface,
        elevation: isDark ? kCardElevationDark : kCardElevationLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusCard),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withAlpha(
              (kCardBorderAlpha * 255).round(),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: isDark ? kTextPrimary : Colors.black87,
                    ) ??
                    const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${event.distanceKm} km • ${_formatDate(event.dateTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? kTextSecondary : Colors.black54,
                    ) ??
                    TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? kTextSecondary : Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

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
      appBar: AppBar(
        title: const Text('Walks'),
        elevation: 0,
        backgroundColor: isDark ? kDarkSurface2 : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? const Color(0xFFA4E4C5) : const Color(0xFF14532D),
          labelColor: isDark ? const Color(0xFFA4E4C5) : const Color(0xFF14532D),
          unselectedLabelColor: isDark ? kTextMuted : Colors.black54,
          tabs: const [
            Tab(text: 'My Walks'),
            Tab(text: 'Nearby Walks'),
          ],
        ),
      ),
      body: TabBarView(
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
                  ? const Color(0xFF4F925C)
                  : const Color(0xFF4F925C),
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
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Create or join a walk to get started',
                style: theme.textTheme.bodyMedium?.copyWith(
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${event.distanceKm} km • ${_formatDate(event.dateTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
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

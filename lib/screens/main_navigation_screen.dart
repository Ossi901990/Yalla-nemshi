import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../models/walk_event.dart';
import 'home_screen.dart';
import 'walks_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'friend_list_screen.dart';

/// Main navigation screen that manages tab switching across the app
class MainNavigationScreen extends StatefulWidget {
  // Data passed from HomeScreen
  final List<WalkEvent> myWalks;
  final List<WalkEvent> nearbyWalks;
  final void Function(WalkEvent) onToggleJoin;
  final void Function(WalkEvent) onToggleInterested;
  final void Function(WalkEvent) onTapEvent;
  final void Function(WalkEvent) onCancelHosted;
  final void Function(WalkEvent) onEventCreated;
  final VoidCallback onCreatedNavigateHome;

  final int walksJoined;
  final int eventsHosted;
  final double totalKm;
  final int interestedCount;
  final double weeklyKm;
  final int weeklyWalks;
  final int streakDays;
  final double weeklyGoalKm;
  final String userName;

  final bool hasMoreWalks;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  final ValueChanged<double>? onWeeklyGoalChanged;

  const MainNavigationScreen({
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
    this.onWeeklyGoalChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    late Widget body;

    switch (_currentTab) {
      case 0:
        // Home tab
        body = HomeScreen(initialTab: 0);
        break;
      case 1:
        // Walks tab
        body = WalksScreen(
          myWalks: widget.myWalks,
          nearbyWalks: widget.nearbyWalks,
          onToggleJoin: widget.onToggleJoin,
          onToggleInterested: widget.onToggleInterested,
          onTapEvent: widget.onTapEvent,
          onCancelHosted: widget.onCancelHosted,
          onEventCreated: widget.onEventCreated,
          onCreatedNavigateHome: widget.onCreatedNavigateHome,
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
        );
        break;
      case 2:
        // Friends tab
        body = const FriendListScreen();
        break;
      case 3:
        // Events tab
        body = const EventsScreen();
        break;
      case 4:
        // Profile tab
        body = ProfileScreen(
          walksJoined: widget.walksJoined,
          eventsHosted: widget.eventsHosted,
          totalKm: widget.totalKm,
          interestedCount: widget.interestedCount,
          weeklyKm: widget.weeklyKm,
          weeklyWalks: widget.weeklyWalks,
          streakDays: widget.streakDays,
          weeklyGoalKm: widget.weeklyGoalKm,
          onWeeklyGoalChanged: widget.onWeeklyGoalChanged,
        );
        break;
      default:
        body = HomeScreen(initialTab: 0);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kDarkBg = Color(0xFF071B26);

    return Scaffold(
      backgroundColor: isDark ? kDarkBg : const Color(0xFF1ABFC4),
      body: body,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
      ),
    );
  }
}

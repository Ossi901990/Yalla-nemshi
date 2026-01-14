import 'package:flutter/material.dart';

/// Reusable BottomNavigationBar component for the app
class AppBottomNavBar extends StatelessWidget {
  /// Currently selected tab index
  final int currentIndex;

  /// Callback when a tab is tapped
  final Function(int) onTap;

  /// Optional callback for specific tab interactions (e.g., reload data)
  final Function(int)? onTabSpecificAction;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onTabSpecificAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Import the color constants from home_screen
    const kDarkSurface2 = Color(0xFF0E242E);
    const kMintBright = Color(0xFFA4E4C5);
    const kTextMuted = Color(0xFF6A8580);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        onTap(index);
        // Trigger specific action if needed
        onTabSpecificAction?.call(index);
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark ? kDarkSurface2 : Colors.white,
      elevation: 0,
      selectedItemColor: isDark ? kMintBright : const Color(0xFF14532D),
      unselectedItemColor: isDark ? kTextMuted : Colors.black54,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_walk),
          label: 'Walk',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_outlined),
          label: 'Events',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outlined),
          label: 'Profile',
        ),
      ],
    );
  }
}

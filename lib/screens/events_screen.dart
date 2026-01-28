// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'notifications_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071B26) : const Color(0xFF1ABFC4),
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
                        onTap: () {
                          Navigator.pushNamed(context, NotificationsScreen.routeName);
                        },
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
                          onTap: () {
                            Navigator.pushNamed(context, NotificationsScreen.routeName);
                          },
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
                color: isDark ? const Color(0xFF071B26) : const Color(0xFF1ABFC4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  color: isDark ? null : const Color(0xFFF7F9F2),
                ),
                child: Center(
                  child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_outlined,
              size: 64,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'Events Coming Soon',
              style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF1F2933),
                  ) ??
                  const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Color(0xFF1F2933),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature will be available soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ) ??
                  TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
            ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

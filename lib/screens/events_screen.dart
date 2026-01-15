// lib/screens/events_screen.dart
import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071B26) : const Color(0xFFF7F9F2),
      appBar: AppBar(
        title: Text(
          'Events',
          style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ) ??
              const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0E242E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: Center(
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
    );
  }
}

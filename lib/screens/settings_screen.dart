// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    // Sync initial switch with current app theme
    final currentMode = ThemeController.instance.themeMode.value;
    _darkModeEnabled = currentMode == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // match Home / Nearby / Profile / CreateWalk
      backgroundColor:
          isDark ? const Color(0xFF0B1A13) : const Color(0xFF4F925C),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ===== HEADER (same gradient style) =====
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF020908), // darker top
                          Color(0xFF0B1A13), // darker bottom
                        ]
                      : const [
                          Color(0xFF294630), // top
                          Color(0xFF4F925C), // bottom
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: const Icon(
                        Icons.directions_walk,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Yalla Nemshi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== MAIN SHEET WITH BG IMAGE (global pattern) =====
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color.fromARGB(255, 9, 2, 7)
                      : const Color(0xFFF7F9F2),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  image: DecorationImage(
                    image: AssetImage(
                      isDark
                          ? 'assets/images/bg_minimal_dark.png'
                          : 'assets/images/bg_minimal_light.png',
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                // overlay so content is readable
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      // Screen title
                      Text(
                        'Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF294630),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Appearance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 🔹 Compact card with a single switch row
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Icon(
                            _darkModeEnabled
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                          ),
                          title: const Text('Dark mode'),
                          subtitle: Text(
                            _darkModeEnabled
                                ? 'Using dark theme'
                                : 'Using light theme',
                          ),
                          trailing: Switch(
                            value: _darkModeEnabled,
                            onChanged: (value) {
                              setState(() {
                                _darkModeEnabled = value;
                              });

                              // 👉 This line actually changes the app theme:
                              ThemeController.instance.setDarkMode(value);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'More',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About Yalla Nemshi'),
                        subtitle: const Text('Version 1.0.0'),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Yalla Nemshi',
                            applicationVersion: '1.0.0',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

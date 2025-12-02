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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
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
    );
  }
}

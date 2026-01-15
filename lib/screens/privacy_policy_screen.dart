import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const String routeName = '/privacy-policy';

  const PrivacyPolicyScreen({super.key});

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
          // ===== HEADER =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Go back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Privacy Policy',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ) ?? const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
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
              height: 64,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Go back',
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Privacy Policy',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ) ?? const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ===== CONTENT =====
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF071B26), Color(0xFF041016)],
                      )
                    : null,
                color: isDark ? null : const Color(0xFFF7F9F2),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Card(
                  color: isDark
                      ? const Color(0xFF0C2430)
                      : const Color(0xFFFBFEF8),
                  elevation: isDark ? 0.0 : 0.6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withAlpha(
                        (0.06 * 255).round(),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: January 10, 2026',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          theme,
                          'Introduction',
                          'Yalla Nemshi ("we", "us", or "our") operates the Yalla Nemshi mobile application (the "Service"). '
                              'This page informs you of our policies regarding the collection, use, and disclosure of '
                              'personal data when you use our Service and the choices you have associated with that data.',
                        ),
                        _buildSection(
                          theme,
                          'Information Collection and Use',
                          'We collect several different types of information for various purposes to provide and improve our Service to you.',
                        ),
                        _buildSubsection(
                          theme,
                          'Types of Data Collected:',
                          '• Personal Data: Name, email address, phone number, profile picture\n'
                              '• Location Data: GPS coordinates for walk discovery and route planning\n'
                              '• Usage Data: App interactions, screens visited, features used\n'
                              '• Device Information: Device type, OS version, app version',
                        ),
                        _buildSection(
                          theme,
                          'Use of Data',
                          'Yalla Nemshi uses the collected data for various purposes:\n'
                              '• To provide and maintain our Service\n'
                              '• To notify you about changes to our Service\n'
                              '• To allow you to participate in interactive features\n'
                              '• To provide customer support\n'
                              '• To gather analysis or valuable information so we can improve our Service\n'
                              '• To monitor the usage of our Service\n'
                              '• To detect, prevent and address technical issues',
                        ),
                        _buildSection(
                          theme,
                          'Security of Data',
                          'The security of your data is important to us but remember that no method of transmission '
                              'over the Internet or method of electronic storage is 100% secure. While we strive to use '
                              'commercially acceptable means to protect your Personal Data, we cannot guarantee its '
                              'absolute security.',
                        ),
                        _buildSection(
                          theme,
                          'Changes to This Privacy Policy',
                          'We may update our Privacy Policy from time to time. We will notify you of any changes by '
                              'posting the new Privacy Policy on this page and updating the "Last updated" date at the top.',
                        ),
                        _buildSection(
                          theme,
                          'Contact Us',
                          'If you have any questions about this Privacy Policy, please contact us through the app settings.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSubsection(ThemeData theme, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(content, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
      ],
    );
  }
}

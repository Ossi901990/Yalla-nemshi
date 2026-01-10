import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  static const String routeName = '/terms';

  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071B26) : const Color(0xFF4F925C),
      body: Column(
        children: [
          // ===== HEADER =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(
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
                  colors: [Color(0xFF294630), Color(0xFF4F925C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF071B26),
                          Color(0xFF041016),
                        ],
                      )
                    : null,
                color: isDark ? null : const Color(0xFFF7F9F2),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Card(
                  color: isDark ? const Color(0xFF0C2430) : const Color(0xFFFBFEF8),
                  elevation: isDark ? 0.0 : 0.6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withAlpha((0.06 * 255).round()),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service',
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
                          '1. Agreement to Terms',
                          'By accessing and using Yalla Nemshi, you accept and agree to be bound by the terms and '
                              'provision of this agreement. If you do not agree to abide by the above, please do not use '
                              'this service.',
                        ),
                        _buildSection(
                          theme,
                          '2. License',
                          'Yalla Nemshi grants you a limited license to use the application for your personal, '
                              'non-commercial purposes only. You agree not to reproduce, transmit, or distribute any '
                              'content without prior written permission.',
                        ),
                        _buildSection(
                          theme,
                          '3. User Responsibilities',
                          'You are responsible for:\n'
                              '• Maintaining the confidentiality of your account information\n'
                              '• Being responsible for all activity that occurs under your account\n'
                              '• Notifying us immediately of any unauthorized use of your account\n'
                              '• Complying with all applicable laws and regulations',
                        ),
                        _buildSection(
                          theme,
                          '4. Acceptable Use',
                          'You agree not to use the Service to:\n'
                              '• Harass, threaten, or intimidate other users\n'
                              '• Post false, defamatory, or misleading information\n'
                              '• Engage in any illegal activity\n'
                              '• Interfere with or disrupt the Service or servers\n'
                              '• Attempt to gain unauthorized access to the Service',
                        ),
                        _buildSection(
                          theme,
                          '5. Safety and Liability',
                          'Walking activities organized through Yalla Nemshi are at your own risk. We are not responsible for:\n'
                              '• Personal injuries during walks\n'
                              '• Loss or theft of personal belongings\n'
                              '• Disputes between users\n'
                              '• Environmental hazards or weather conditions\n'
                              'Always exercise caution and follow local safety guidelines.',
                        ),
                        _buildSection(
                          theme,
                          '6. Disclaimer of Warranties',
                          'THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. '
                              'WE MAKE NO WARRANTIES REGARDING THE ACCURACY, RELIABILITY, OR AVAILABILITY OF THE SERVICE.',
                        ),
                        _buildSection(
                          theme,
                          '7. Limitation of Liability',
                          'IN NO EVENT SHALL YALLA NEMSHI BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, '
                              'CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SERVICE.',
                        ),
                        _buildSection(
                          theme,
                          '8. Termination',
                          'We reserve the right to terminate or suspend your account at any time, for any reason, '
                              'without notice. Upon termination, your right to use the Service will immediately cease.',
                        ),
                        _buildSection(
                          theme,
                          '9. Changes to Terms',
                          'We may update these Terms at any time. Your continued use of the Service following the '
                              'posting of revised Terms means you accept and agree to the changes.',
                        ),
                        _buildSection(
                          theme,
                          '10. Contact',
                          'If you have any questions about these Terms, please contact us through the app settings.',
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
        Text(
          content,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

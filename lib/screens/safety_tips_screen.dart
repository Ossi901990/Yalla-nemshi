// lib/screens/safety_tips_screen.dart
import 'package:flutter/material.dart';

// ===== Design tokens (match Home / Profile) =====
const double kRadiusCard = 24;
const double kSpace1 = 8;
const double kSpace2 = 16;
const double kSpace3 = 24;

const Color kLightSurface = Color(0xFFFBFEF8);
const double kCardElevationLight = 0.6;
const double kCardElevationDark = 0.0;
const double kCardBorderAlpha = 0.06;

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // ✅ match app base background
      backgroundColor: isDark
          ? const Color(0xFF071B26)
          : const Color(0xFF4F925C),

      body: Column(
        children: [
          // ===== HEADER (match Home/Profile logic) =====
          if (isDark)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: back + title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Safety & Community Tips',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    // Right: keep spacing consistent (no icons here)
                    const SizedBox(width: 32),
                  ],
                ),
              ),
            )
          else
            // Light: gradient bar (same style as other screens)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Safety & Community Tips',
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
            ),

// ===== MAIN AREA (Home/Profile style: rounded top + one main card) =====
Expanded(
  child: Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(kRadiusCard),
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kRadiusCard),
        ),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF071B26), // top
                  Color(0xFF041016), // bottom
                ],
              )
            : null,
        color: isDark ? null : const Color(0xFFF7F9F2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpace2,
          kSpace2,
          kSpace2,
          kSpace2,
        ),
        child: Card(

                  color: isDark ? const Color(0xFF0C2430) : kLightSurface,
                  elevation: isDark ? kCardElevationDark : kCardElevationLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        kCardBorderAlpha,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSpace2,
                      kSpace3,
                      kSpace2,
                      kSpace3,
                    ),
                    child: ListView(
                      children: [
                        Text(
                          'Walking safely together',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yalla Nemshi is about feeling safe, welcome, and comfortable while walking with others. '
                          'Please read these tips before joining or hosting a walk.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _SectionTitle(title: 'Before the walk', isDark: isDark),
                        const SizedBox(height: 8),
                        const _Bullet(
                          text:
                              'Choose meeting points in public, well-lit areas (parks, main entrances, etc.).',
                        ),
                        const _Bullet(
                          text:
                              'Share your plans with a friend or family member if you are meeting people for the first time.',
                        ),
                        const _Bullet(
                          text:
                              'Wear comfortable shoes and bring water, especially for longer walks.',
                        ),
                        const _Bullet(
                          text:
                              'Check the weather and adapt your clothing (hat, jacket, etc.).',
                        ),
                        const SizedBox(height: 24),

                        _SectionTitle(title: 'During the walk', isDark: isDark),
                        const SizedBox(height: 8),
                        const _Bullet(
                          text:
                              'Respect everyone’s pace and personal space. Ask before changing the route.',
                        ),
                        const _Bullet(
                          text:
                              'Stay on sidewalks or safe walking paths whenever possible.',
                        ),
                        const _Bullet(
                          text:
                              'Avoid sharing sensitive personal information with people you just met.',
                        ),
                        const _Bullet(
                          text:
                              'If you ever feel unsafe or uncomfortable, you can leave the walk at any time.',
                        ),
                        const SizedBox(height: 24),

                        _SectionTitle(title: 'Hosting a walk', isDark: isDark),
                        const SizedBox(height: 8),
                        const _Bullet(
                          text:
                              'Be clear in your event description: pace, distance, and who the walk is suitable for.',
                        ),
                        const _Bullet(
                          text:
                              'Arrive a bit early to welcome participants at the meeting point.',
                        ),
                        const _Bullet(
                          text:
                              'Communicate any changes (time, location) as early as possible.',
                        ),
                        const _Bullet(
                          text:
                              'If someone seems uncomfortable or left behind, check in kindly.',
                        ),
                        const SizedBox(height: 24),

                        _SectionTitle(
                          title: 'Community guidelines',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        const _Bullet(
                          text:
                              'Be kind and respectful in your language and behaviour at all times.',
                        ),
                        const _Bullet(
                          text:
                              'Discrimination, harassment, or hateful behaviour is not welcome.',
                        ),
                        const _Bullet(
                          text:
                              'Only create real events you plan to attend. Don’t share fake or misleading information.',
                        ),
                        const _Bullet(
                          text:
                              'If you notice something unsafe or inappropriate, use the Report button on the event.',
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Thank you for helping make Yalla Nemshi a safe and friendly space for everyone 💚',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
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
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

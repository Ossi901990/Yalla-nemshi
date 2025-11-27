// lib/screens/safety_tips_screen.dart
import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Community Tips'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Walking safely together',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Yalla Nemshi is about feeling safe, welcome, and comfortable while walking with others. '
            'Please read these tips before joining or hosting a walk.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Text(
            'Before the walk',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _Bullet(
              text:
                  'Choose meeting points in public, well-lit areas (parks, main entrances, etc.).'),
          const _Bullet(
              text:
                  'Share your plans with a friend or family member if you are meeting people for the first time.'),
          const _Bullet(
              text:
                  'Wear comfortable shoes and bring water, especially for longer walks.'),
          const _Bullet(
              text:
                  'Check the weather and adapt your clothing (hat, jacket, etc.).'),
          const SizedBox(height: 24),

          Text(
            'During the walk',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _Bullet(
              text:
                  'Respect everyone’s pace and personal space. Ask before changing the route.'),
          const _Bullet(
              text:
                  'Stay on sidewalks or safe walking paths whenever possible.'),
          const _Bullet(
              text:
                  'Avoid sharing sensitive personal information with people you just met.'),
          const _Bullet(
              text:
                  'If you ever feel unsafe or uncomfortable, you can leave the walk at any time.'),
          const SizedBox(height: 24),

          Text(
            'Hosting a walk',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _Bullet(
              text:
                  'Be clear in your event description: pace, distance, and who the walk is suitable for.'),
          const _Bullet(
              text:
                  'Arrive a bit early to welcome participants at the meeting point.'),
          const _Bullet(
              text:
                  'Communicate any changes (time, location) as early as possible.'),
          const _Bullet(
              text:
                  'If someone seems uncomfortable or left behind, check in kindly.'),
          const SizedBox(height: 24),

          Text(
            'Community guidelines',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _Bullet(
              text:
                  'Be kind and respectful in your language and behaviour at all times.'),
          const _Bullet(
              text:
                  'Discrimination, harassment, or hateful behaviour is not welcome.'),
          const _Bullet(
              text:
                  'Only create real events you plan to attend. Don’t share fake or misleading information.'),
          const _Bullet(
              text:
                  'If you notice something unsafe or inappropriate, use the Report button on the event.'),
          const SizedBox(height: 24),

          Text(
            'Thank you for helping make Yalla Nemshi a safe and friendly space for everyone 💚',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

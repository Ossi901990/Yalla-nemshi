// Profile (2026 redesign): every situation on every common phone size,
// text-size setting and theme must lay out without errors.
//
// Screenshots: `flutter test test/profile_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/screens/profile/profile_view.dart';
import 'package:yalla_nemshi/widgets/ui/ui_kit.dart';

import 'support/layout_kit.dart';

ProfileActions _actions({
  ValueChanged<int>? onNavTap,
  VoidCallback? onCreate,
}) => ProfileActions(
  onFriends: () {},
  onNotifications: () {},
  onSettings: () {},
  onAvatarTap: () {},
  onEditProfile: () {},
  onAnalytics: () {},
  onSafetyTips: () {},
  onExportCsv: () {},
  onExportPdf: () {},
  onSwitchAccount: () {},
  onSignOut: () {},
  onNavTap: onNavTap ?? (_) {},
  onCreateWalk: onCreate ?? () {},
);

const _avatar = CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48));

Widget _screen(String state, {ProfileActions? actions}) {
  final a = actions ?? _actions();
  switch (state) {
    case 'new_user':
      return ProfileView(
        name: '',
        bio: '',
        walkerLevel: 'New walker',
        weeklyWalks: 0,
        weeklyKm: 0,
        weeklyGoalKm: 10,
        motivation: 'Every walk counts. Start with one this week!',
        walksJoined: 0,
        walksHosted: 0,
        totalKm: 0,
        interestedCount: 0,
        avatar: _avatar,
        actions: a,
      );
    default: // 'active_host': long text, every section, big numbers
      return ProfileView(
        name: 'Osaid Abdullah Al-Rashidi Mehmedović',
        bio:
            'Morning walker, coffee after. I host easy loops along the river '
            'most weekends — everyone is welcome, dogs too.',
        age: 34,
        gender: 'Male',
        walkerLevel: 'Committed walker',
        weeklyWalks: 4,
        weeklyKm: 18.6,
        weeklyGoalKm: 25,
        motivation:
            "You're 74% of the way there. One more evening walk and you've got it!",
        walksJoined: 128,
        walksHosted: 47,
        totalKm: 1234.5,
        interestedCount: 12,
        avatar: _avatar,
        actions: a,
        banner: const SizedBox(height: 40, child: Placeholder()),
        // Stand-ins for the sections that load their own data.
        lifetimeStats: const AppCard(child: SizedBox(height: 120)),
        hostRating: const AppCard(child: Text('⭐ 4.8 · 23 reviews')),
        badges: const SizedBox(height: 200, child: Placeholder()),
        pastWalks: const SizedBox(height: 240, child: Placeholder()),
      );
  }
}

void main() {
  setUpAll(loadAppFonts);

  fitGrid(
    screen: 'profile',
    states: const ['new_user', 'active_host'],
    build: _screen,
    scroll: () => find.byType(ListView),
  );

  testWidgets('empty profile nudges the user to fill it in', (tester) async {
    await tester.pumpWidget(themedApp(_screen('new_user'), ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Add your name'), findsOneWidget);
    expect(find.text('Add a short bio about you'), findsOneWidget);
    expect(find.text('As a host'), findsNothing);
  });

  testWidgets('host section shows once you have hosted', (tester) async {
    await tester.pumpWidget(themedApp(_screen('active_host'), ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Age 34'), findsOneWidget);
    expect(find.text('74%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('As a host'), 300);
    expect(find.text('As a host'), findsOneWidget);
  });

  testWidgets('bottom bar hands the chosen tab back to Home', (tester) async {
    int? tab;
    var created = false;
    await tester.pumpWidget(
      themedApp(
        _screen(
          'new_user',
          actions: _actions(
            onNavTap: (i) => tab = i,
            onCreate: () => created = true,
          ),
        ),
        ThemeMode.light,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home'));
    expect(tab, 0);
    await tester.tap(find.bySemanticsLabel('Create a walk'));
    expect(created, isTrue);
  });
}

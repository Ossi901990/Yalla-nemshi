// Create walk (2026 redesign): the form must lay out on every common phone
// size, text-size setting and theme, for point-to-point, loop and repeating
// walks.
//
// Screenshots: `flutter test test/create_walk_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_nemshi/screens/create_walk_screen.dart';

import 'support/layout_kit.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  fitGrid(
    screen: 'create',
    states: const ['point', 'loop', 'repeating'],
    build: (_) => CreateWalkScreen(
      onEventCreated: (_) {},
      onCreatedNavigateHome: () {},
    ),
    prepare: (tester, state) async {
      if (state == 'loop') {
        await tester.tap(find.text('Loop'));
      }
      if (state == 'repeating') {
        final toggle = find.byType(Switch).last;
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
      }
    },
    scroll: () => find.byType(SingleChildScrollView).first,
  );

  testWidgets('create button sits in the bottom bar', (tester) async {
    await tester.pumpWidget(
      themedApp(
        CreateWalkScreen(onEventCreated: (_) {}, onCreatedNavigateHome: () {}),
        ThemeMode.light,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create walk'), findsOneWidget);
    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();
    expect(find.text('Create loop walk'), findsOneWidget);
  });
}

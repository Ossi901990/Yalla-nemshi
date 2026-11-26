// My calendar (2026 redesign): must lay out on every common phone size,
// text-size setting and theme, with and without walks.
//
// Screenshots: `flutter test test/calendar_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/models/walk_event.dart';
import 'package:yalla_nemshi/screens/calendar_screen.dart';

import 'support/layout_kit.dart';

// Walks are placed relative to the real "today" because WalkRow formats
// dates from DateTime.now().
final _today = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}();

WalkEvent _walk(
  String id,
  String title,
  int days, {
  int hour = 18,
  bool owner = false,
  bool joined = false,
  bool starred = false,
  bool cancelled = false,
}) {
  final d = _today.add(Duration(days: days));
  return WalkEvent(
    id: id,
    firestoreId: id,
    hostUid: owner ? 'me' : 'h$id',
    title: title,
    dateTime: DateTime(d.year, d.month, d.day, hour, 30),
    distanceKm: 4,
    gender: 'Mixed',
    pace: 'Normal',
    isOwner: owner,
    joined: joined,
    interested: starred,
    cancelled: cancelled,
    meetingPlaceName: 'Baščaršija',
    joinedCount: 6,
  );
}

final _walks = [
  _walk('a', 'Morning loop by the river', 0, hour: 23, joined: true),
  _walk('b', 'Sunday family stroll around Vrelo Bosne park', 1, owner: true),
  _walk('c', 'After-work city walk', 1, hour: 19, starred: true),
  _walk(
    'd',
    'Old town coffee walk with a very long name indeed',
    4,
    joined: true,
  ),
  _walk('e', 'Trebević cable car hike', 10, starred: true),
  _walk('f', 'Not mine: nearby walk', 2),
  _walk('g', 'Cancelled walk', 3, joined: true, cancelled: true),
];

Widget _screen(
  String state, {
  VoidCallback? onFind,
  void Function(WalkEvent)? onOpen,
}) => CalendarScreen(
  walks: state == 'empty' ? const [] : _walks,
  onOpen: onOpen ?? (_) {},
  onJoin: (_) {},
  onFindWalks: onFind ?? () {},
  onCreateWalk: () {},
);

void main() {
  setUpAll(loadAppFonts);

  fitGrid(
    screen: 'calendar',
    states: const ['walks', 'empty'],
    build: _screen,
    scroll: () => find.byType(ListView).first,
  );

  testWidgets('shows only my walks, grouped by day', (tester) async {
    await tester.pumpWidget(themedApp(_screen('walks'), ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Morning loop by the river'), findsOneWidget);
    expect(find.text('Not mine: nearby walk'), findsNothing);
    expect(find.text('Cancelled walk'), findsNothing);
  });

  testWidgets('filters narrow the list', (tester) async {
    await tester.pumpWidget(themedApp(_screen('walks'), ThemeMode.light));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hosting'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sunday family stroll around Vrelo Bosne park'),
      findsOneWidget,
    );
    expect(find.text('Morning loop by the river'), findsNothing);

    await tester.tap(find.text('Starred'));
    await tester.pumpAndSettle();
    expect(find.text('After-work city walk'), findsOneWidget);
    expect(find.text('Morning loop by the river'), findsNothing);
  });

  testWidgets('tapping a day shows just that day', (tester) async {
    await tester.pumpWidget(themedApp(_screen('walks'), ThemeMode.light));
    await tester.pumpAndSettle();
    final tomorrow = _today.add(const Duration(days: 1));
    await tester.tap(
      find.bySemanticsLabel(RegExp('^.* ${tomorrow.day} .*, 2 walks\$')),
    );
    await tester.pumpAndSettle();
    expect(find.text('After-work city walk'), findsOneWidget);
    expect(find.text('Morning loop by the river'), findsNothing);
    await tester.tap(find.text('Show all days'));
    await tester.pumpAndSettle();
    expect(find.text('Morning loop by the river'), findsOneWidget);
  });

  testWidgets('empty calendar offers to find a walk', (tester) async {
    var found = false;
    await tester.pumpWidget(
      themedApp(_screen('empty', onFind: () => found = true), ThemeMode.light),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing planned yet'), findsOneWidget);
    await tester.tap(find.text('Find a walk'));
    expect(found, isTrue);
  });
}

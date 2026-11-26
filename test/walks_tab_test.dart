// Walks tab (2026 redesign): My walks and Nearby must lay out on every common
// phone size, text-size setting and theme, with and without walks.
//
// Screenshots: `flutter test test/walks_tab_test.dart --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/models/walk_event.dart';
import 'package:yalla_nemshi/screens/walks_screen.dart';

import 'support/layout_kit.dart';

WalkEvent _walk(
  String id,
  String title,
  int days, {
  bool owner = false,
  bool joined = false,
  String place = 'Baščaršija',
}) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day).add(Duration(days: days));
  return WalkEvent(
    id: id,
    firestoreId: id,
    hostUid: owner ? 'me' : 'h$id',
    title: title,
    dateTime: DateTime(d.year, d.month, d.day, 18, 30),
    distanceKm: 4,
    gender: 'Mixed',
    pace: 'Normal',
    isOwner: owner,
    joined: joined,
    meetingPlaceName: place,
    meetingLat: 31.95 + days / 100,
    meetingLng: 35.91 + days / 200,
    joinedCount: 6,
  );
}

final _hosted = [
  _walk('h1', 'Sunday family stroll around Vrelo Bosne park', 2, owner: true),
];
final _others = [
  _walk('n1', 'Sunrise to Vrelo Bosne', 1, joined: true, place: 'Ilidža'),
  _walk('n2', 'After-work city walk', 3, place: 'Marijin Dvor'),
  _walk('n3', 'Old town coffee walk with a very long name indeed', 5),
  _walk('n4', 'Trebević cable car hike', 12, place: 'Trebević'),
];

Widget _screen(String state) {
  final empty = state.endsWith('empty');
  return WalksScreen(
    myWalks: empty ? const [] : _hosted,
    nearbyWalks: empty ? const [] : _others,
    onToggleJoin: (_) {},
    onToggleInterested: (_) {},
    onTapEvent: (_) {},
    onCancelHosted: (_) {},
    onEventCreated: (_) {},
    onCreatedNavigateHome: () {},
    walksJoined: 1,
    eventsHosted: 1,
    totalKm: 4,
    interestedCount: 0,
    weeklyKm: 4,
    weeklyWalks: 1,
    streakDays: 1,
    weeklyGoalKm: 10,
    userName: 'Osaid',
    hasMoreWalks: true,
    isLoadingMore: false,
    onLoadMore: () {},
  );
}

void main() {
  setUpAll(loadAppFonts);

  fitGrid(
    screen: 'walks',
    states: const ['mine', 'mine_empty', 'nearby', 'nearby_empty', 'map'],
    build: _screen,
    prepare: (tester, state) async {
      if (state.startsWith('nearby') || state == 'map') {
        await tester.tap(find.text('Nearby'));
      }
      if (state == 'map') {
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show map'));
      }
    },
    scroll: () => find.byType(Scrollable).last,
  );

  testWidgets('My walks shows hosted and joined walks in sections', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp(_screen('mine'), ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Hosting'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Sunrise to Vrelo Bosne'), findsOneWidget);
  });

  testWidgets('Nearby has a map switch', (tester) async {
    await tester.pumpWidget(themedApp(_screen('nearby'), ThemeMode.light));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show map'), findsOneWidget);
  });
}

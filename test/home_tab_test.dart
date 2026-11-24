// Renders the redesigned Home tab at phone size in light and dark mode for
// every hero-card state, failing on layout errors (e.g. text overflow).
//
// Screenshots: `flutter test test/home_tab_test.dart --update-goldens`
// writes them to test/goldens/ (git-ignored) for a visual check. Normal runs,
// including CI on Linux, only check for layout errors: font rendering differs
// between platforms, so screenshots aren't compared.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/models/walk_event.dart';
import 'package:yalla_nemshi/screens/home/home_tab.dart';
import 'package:yalla_nemshi/theme/app_theme.dart';
import 'package:yalla_nemshi/widgets/ui/floating_nav_bar.dart';

const _me = 'me';

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await family('Bricolage', ['assets/fonts/BricolageGrotesque-Variable.ttf']);
  await family('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await family('Poppins', ['assets/fonts/Poppins-Bold.ttf']);

  // Material icons from the Flutter SDK, so icons aren't empty boxes.
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final icons = File(
    '${artifacts.path}/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

WalkEvent _walk(
  String id,
  String title,
  DateTime when, {
  bool owner = false,
  bool joined = false,
  String status = 'scheduled',
  String place = 'Wilsonovo šetalište',
  List<String> names = const ['Amra Mehić', 'Lejla Kovač', 'Sara Hadžić'],
  int going = 8,
  Map<String, String> states = const {},
}) {
  return WalkEvent(
    id: id,
    firestoreId: id,
    hostUid: owner ? _me : 'host_$id',
    title: title,
    dateTime: when,
    distanceKm: 4,
    gender: 'Mixed',
    pace: 'Easy',
    isOwner: owner,
    joined: joined,
    status: status,
    meetingPlaceName: place,
    joinedUserUids: [
      for (var i = 0; i < names.length; i++) 'u$i',
      if (joined) _me,
    ],
    joinedUserNames: names,
    joinedCount: going,
    participantStates: states,
  );
}

HomeTabActions _noActions() => HomeTabActions(
  onOpenNotifications: () {},
  onOpenProfile: () {},
  onSearch: () {},
  onOpenWalk: (_) {},
  onJoin: (_) {},
  onStartHosted: (_) {},
  onConfirmHere: (_) {},
  onOpenActive: (_) {},
  onCreateWalk: () {},
  onBrowseWalks: () {},
  onRefresh: () async {},
);

Widget _app(Widget home, ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
  home: Scaffold(
    extendBody: true,
    body: home,
    bottomNavigationBar: FloatingNavBar(
      currentIndex: 0,
      onTap: (_) {},
      onCreate: () {},
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);

  final now = DateTime.now();
  DateTime at(int days, int hour, [int minute = 0]) {
    final d = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  final others = [
    _walk('w2', 'Sunrise to Vrelo Bosne', at(2, 7), place: 'Ilidža', going: 9),
    _walk(
      'w3',
      'After-work city walk',
      at(3, 18),
      place: 'Marijin Dvor',
      going: 6,
    ),
    _walk(
      'w4',
      'Old town coffee walk with a very long name that should be cut off',
      at(5, 10),
      place: 'Baščaršija',
      going: 4,
      joined: true,
    ),
  ];

  final scenarios = <String, (List<WalkEvent>, HomeHeroMode?)>{
    'suggested': (
      [_walk('w1', 'Riverside evening loop', at(0, 23, 30)), ...others],
      HomeHeroMode.suggested,
    ),
    'hosting': (
      [
        _walk('w1', 'Riverside evening loop', at(1, 19, 30), owner: true),
        ...others,
      ],
      HomeHeroMode.hostUpcoming,
    ),
    'joined': (
      [
        _walk('w1', 'Riverside evening loop', at(1, 19, 30), joined: true),
        ...others,
      ],
      HomeHeroMode.joinedUpcoming,
    ),
    'in_progress': (
      [
        _walk(
          'w1',
          'Riverside evening loop',
          now.subtract(const Duration(minutes: 5)),
          joined: true,
          status: 'active',
        ),
        ...others,
      ],
      HomeHeroMode.joinedActive,
    ),
    'long_title_no_people': (
      [
        _walk(
          'w1',
          'A really quite long walk title that wraps onto several lines',
          at(1, 8),
          names: const [],
          going: 0,
        ),
        ...others,
      ],
      HomeHeroMode.suggested,
    ),
    'empty': (<WalkEvent>[], null),
  };

  for (final entry in scenarios.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final name = '${entry.key}_${mode.name}';
      testWidgets('home renders without layout errors: $name', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final (walks, heroMode) = entry.value;
        final hero = heroMode == null ? null : walks.first;
        await tester.pumpWidget(
          _app(
            HomeTab(
              currentUid: _me,
              userName: 'Osaid Abdullah',
              photoUrl: null,
              unreadCount: 2,
              walks: walks,
              heroWalk: hero,
              heroMode: heroMode,
              canStartHosted: false,
              heroBusy: false,
              streakDays: entry.key == 'empty' ? 0 : 3,
              weeklyKm: 4,
              weeklyGoalKm: 10,
              actions: _noActions(),
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        // Layout errors (overflow etc.) are reported as exceptions.
        expect(tester.takeException(), isNull);
        if (autoUpdateGoldenFiles) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/home_$name.png'),
          );
        }
      });
    }
  }

  testWidgets('small phone (320 wide) has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (walks, heroMode) = scenarios['suggested']!;
    await tester.pumpWidget(
      _app(
        HomeTab(
          currentUid: _me,
          userName: 'Maximilian Alexander',
          photoUrl: null,
          unreadCount: 12,
          walks: walks,
          heroWalk: walks.first,
          heroMode: heroMode,
          canStartHosted: false,
          heroBusy: false,
          streakDays: 12,
          weeklyKm: 12.5,
          weeklyGoalKm: 10,
          actions: _noActions(),
        ),
        ThemeMode.light,
      ),
    );
    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (autoUpdateGoldenFiles) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_small_phone.png'),
      );
    }
    expect(error, isNull);
  });
}

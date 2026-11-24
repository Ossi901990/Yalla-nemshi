// Shared helpers for the phone-size layout tests of redesigned screens.
//
// `fitGrid` lays a screen out on every common phone size x text-size setting
// x light/dark and fails on any layout error (overflow etc.), reporting the
// widget and source line. `--update-goldens` also saves screenshots of
// failures and of the most extreme case to test/goldens/ (git-ignored).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/theme/app_theme.dart';

/// (name, width, height) in logical points.
const phoneDevices = <(String, double, double)>[
  ('galaxy_fold', 280, 653),
  ('iphone_se1', 320, 568),
  ('android_360', 360, 740),
  ('iphone_se3', 375, 667),
  ('iphone_14', 390, 844),
  ('pixel_7', 412, 915),
  ('iphone_pro_max', 430, 932),
];

/// Text-size settings: default and two "large text" levels.
const textScales = [1.0, 1.3, 1.6];

Future<void> loadAppFonts() async {
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

Widget themedApp(Widget home, ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
  home: home,
);

/// Overflow message plus the widget that caused it (with its source line).
String describeLayoutError(FlutterErrorDetails e) {
  final text = e.toString();
  final message = e.exceptionAsString().split('\n').first;
  final match = RegExp(
    r'The relevant error-causing widget was:\s*\n\s*(.+)\n\s*(.+)',
  ).firstMatch(text);
  return match == null
      ? message
      : '$message  <-  ${match.group(1)} ${match.group(2)}';
}

/// Registers one test per device x text scale x state x theme.
///
/// [build] returns the screen for a state. [scroll] finds the scrollable to
/// drag to the bottom so every section is laid out.
void fitGrid({
  required String screen,
  required List<String> states,
  required Widget Function(String state) build,
  required Finder Function() scroll,
}) {
  for (final (device, w, h) in phoneDevices) {
    for (final scale in textScales) {
      for (final state in states) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final name = '${screen}_${device}_x${scale}_${state}_${mode.name}';
          testWidgets('fits: $name', (tester) async {
            tester.view.physicalSize = Size(w * 3, h * 3);
            tester.view.devicePixelRatio = 3;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final errors = <FlutterErrorDetails>[];
            final previous = FlutterError.onError;
            FlutterError.onError = errors.add;
            final extreme = device == 'galaxy_fold' && scale == 1.6;
            // A normal phone at default text size, for reviewing the design.
            final preview = device == 'iphone_14' && scale == 1.0;
            try {
              await tester.pumpWidget(themedApp(build(state), mode));
              await tester.pumpAndSettle();
              if (autoUpdateGoldenFiles && (extreme || preview)) {
                await expectLater(
                  find.byType(MaterialApp),
                  matchesGoldenFile('goldens/top_$name.png'),
                );
              }
              await tester.drag(scroll(), const Offset(0, -6000));
              await tester.pumpAndSettle();
            } finally {
              FlutterError.onError = previous;
            }

            if (autoUpdateGoldenFiles && (errors.isNotEmpty || extreme)) {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile('goldens/bottom_$name.png'),
              );
            }
            expect(
              errors.map(describeLayoutError).toList(),
              isEmpty,
              reason: 'Layout errors on $name',
            );
          });
        }
      }
    }
  }
}

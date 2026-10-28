import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outgrid/app/app.dart';
import 'package:outgrid/core/storage/progress_controller.dart';
import 'package:outgrid/core/storage/settings_controller.dart';
import 'package:outgrid/features/level_selection/level_selection_screen.dart';
import 'package:outgrid/features/settings/settings_screen.dart';

// Several screens (home's decorative illustration, the puzzle board's
// hint pulse) run infinitely-repeating AnimationControllers by design.
// pumpAndSettle() never returns for those, so this suite advances frames
// by a bounded amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  final progress = ProgressController();
  await settings.load();
  await progress.load();
  await tester.pumpWidget(AppProviders(
    settingsController: settings,
    progressController: progress,
    child: const OutgridApp(),
  ));
  await _settle(tester);
}

void main() {
  testWidgets('Home screen shows brand, tagline, and primary CTA',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('THINK. TRACE. ESCAPE.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget, reason: 'no saved progress yet, so CTA reads Play');
    expect(find.text('Level Selection'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
  });

  testWidgets('Level Selection opens and shows all 10 chapters, only first unlocked',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Level Selection'));
    await _settle(tester);

    expect(find.byType(LevelSelectionScreen), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OUTGRID Master'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('OUTGRID Master'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('Settings screen opens and toggles persist in-memory',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await _settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    final soundSwitchFinder = find.widgetWithText(SwitchListTile, 'Sound effects');
    expect(soundSwitchFinder, findsOneWidget);
    await tester.tap(soundSwitchFinder);
    await _settle(tester);

    final tile = tester.widget<SwitchListTile>(soundSwitchFinder);
    expect(tile.value, isFalse);
  });

  testWidgets('Tapping Play launches the gameplay screen for level 1',
      (tester) async {
    await _pumpApp(tester);

    // Loading a level reads a real bundled JSON asset off disk; that I/O
    // runs on the real event loop and needs runAsync (fake-clock pump()
    // alone never lets it complete).
    await tester.runAsync(() async {
      await tester.tap(find.text('Play'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await _settle(tester);

    expect(find.textContaining('Chapter 1 · Level 1'), findsOneWidget);
    expect(find.text('Tap an arrow with a clear exit lane to send it off the board.'),
        findsOneWidget);
  });
}

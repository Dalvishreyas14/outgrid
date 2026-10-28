import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outgrid/core/storage/progress_controller.dart';
import 'package:outgrid/core/storage/progress_repository.dart';
import 'package:outgrid/core/storage/settings_controller.dart';
import 'package:outgrid/core/storage/settings_repository.dart';
import 'package:outgrid/models/arrow_path.dart';
import 'package:outgrid/models/direction.dart';
import 'package:outgrid/models/arrow_color.dart';
import 'package:outgrid/models/grid_point.dart';
import 'package:outgrid/models/level_model.dart';
import 'package:outgrid/models/game_settings.dart';
import 'package:outgrid/models/player_progress.dart';

LevelModel _level(int globalIndex, {int chapter = 1, int levelInChapter = 1}) {
  return LevelModel(
    id: 'c${chapter.toString().padLeft(2, '0')}_l${levelInChapter.toString().padLeft(3, '0')}',
    chapterIndex: chapter,
    levelInChapter: levelInChapter,
    globalIndex: globalIndex,
    title: 'Test',
    patternFamily: PatternFamily.square,
    rows: 5,
    cols: 5,
    arrows: [
      ArrowPathDef(
        id: 'a0',
        cells: const [GridPoint(0, 0)],
        direction: GridDirection.left,
        color: ArrowColorId.blue,
      ),
    ],
    difficultyScore: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsController', () {
    test('defaults to light theme, sound/music/haptics on, untimed', () async {
      final controller = SettingsController();
      await controller.load();
      expect(controller.settings.themeMode, AppThemeMode.light);
      expect(controller.settings.soundEnabled, isTrue);
      expect(controller.settings.timedModeEnabled, isFalse);
    });

    test('mutations persist across a fresh controller instance', () async {
      final a = SettingsController();
      await a.load();
      await a.setThemeMode(AppThemeMode.dark);
      await a.setHaptics(false);

      final b = SettingsController();
      await b.load();
      expect(b.settings.themeMode, AppThemeMode.dark);
      expect(b.settings.hapticsEnabled, isFalse);
    });
  });

  group('ProgressController', () {
    test('only level 1 is unlocked initially', () async {
      final controller = ProgressController();
      await controller.load();
      expect(controller.isUnlocked(1), isTrue);
      expect(controller.isUnlocked(2), isFalse);
      expect(controller.nextPlayableGlobalIndex, 1);
    });

    test('completing a level unlocks the next one and records the result',
        () async {
      final controller = ProgressController();
      await controller.load();
      final level = _level(1);

      await controller.completeLevel(level: level, stars: 3, moves: 5);

      expect(controller.isUnlocked(2), isTrue);
      expect(controller.isUnlocked(3), isFalse);
      expect(controller.resultFor(level.id)?.stars, 3);
      expect(controller.resultFor(level.id)?.completed, isTrue);
    });

    test('completing a level twice keeps the better star/move result',
        () async {
      final controller = ProgressController();
      await controller.load();
      final level = _level(1);

      await controller.completeLevel(level: level, stars: 2, moves: 10);
      await controller.completeLevel(level: level, stars: 3, moves: 4);
      expect(controller.resultFor(level.id)?.stars, 3);

      // A worse replay must not overwrite the best result.
      await controller.completeLevel(level: level, stars: 1, moves: 20);
      expect(controller.resultFor(level.id)?.stars, 3);
      expect(controller.resultFor(level.id)?.bestMoves, 4);
    });

    test('progress survives reload from a fresh controller instance',
        () async {
      final a = ProgressController();
      await a.load();
      await a.completeLevel(level: _level(1), stars: 2, moves: 8);

      final b = ProgressController();
      await b.load();
      expect(b.isUnlocked(2), isTrue);
      expect(b.resultFor('c01_l001')?.stars, 2);
    });

    test('active level snapshot saves and clears correctly', () async {
      final controller = ProgressController();
      await controller.load();
      final state = ActiveLevelState(
        levelId: 'c01_l003',
        globalIndex: 3,
        removedArrowIds: const ['a0', 'a1'],
        hearts: 2,
        moves: 1,
        failedAttempts: 1,
      );
      await controller.saveActiveLevel(state);
      expect(controller.nextPlayableGlobalIndex, 3);

      await controller.clearActiveLevel();
      expect(controller.progress.activeLevel, isNull);
    });
  });

  group('repositories handle corrupt/missing data safely', () {
    test('SettingsRepository falls back to defaults on bad JSON', () async {
      SharedPreferences.setMockInitialValues(
          {'outgrid_settings_v1': 'not valid json'});
      final result = await SettingsRepository().load();
      expect(result.themeMode, AppThemeMode.light);
    });

    test('ProgressRepository falls back to defaults on bad JSON', () async {
      SharedPreferences.setMockInitialValues(
          {'outgrid_progress_v1': '{broken'});
      final result = await ProgressRepository().load();
      expect(result.highestUnlockedLevel, 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:outgrid/core/constants/chapters.dart';
import 'package:outgrid/game/data/level_repository.dart';
import 'package:outgrid/game/engine/game_state.dart';
import 'package:outgrid/game/engine/move_validator.dart';
import 'package:outgrid/game/generation/puzzle_solver.dart';
import 'package:outgrid/game/generation/puzzle_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 500 bundled levels load, validate, and are fully solvable',
      () async {
    final repo = LevelRepository();
    final levels = await repo.all();

    expect(levels.length, ChapterDef.totalLevels,
        reason: 'The brief requires exactly 500 shipped levels');

    const validator = PuzzleValidator();
    const solver = PuzzleSolver();
    final failures = <String>[];

    for (final level in levels) {
      final report = validator.validate(level);
      if (!report.passed) {
        failures.add('${level.id}: ${report.issues.join('; ')}');
        continue;
      }

      // Confirm the live GameStateController can actually clear the
      // board end-to-end via the solver's topological order — this
      // exercises the same engine code path real gameplay uses, not a
      // shortcut around it.
      final solved = solver.solve(level);
      final game = GameStateController(level: level)..start();
      for (final arrowId in solved.order!) {
        final eval = game.attemptMove(arrowId);
        if (eval.outcome != MoveOutcome.success) {
          failures.add(
              '${level.id}: engine rejected solver move for $arrowId (${eval.outcome})');
          break;
        }
        game.finishAnimation();
      }
      if (game.status != GameStatus.levelCompleted) {
        failures.add(
            '${level.id}: did not reach levelCompleted after solver order');
      }
    }

    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  });

  test('globalIndex is contiguous 1..500 with no gaps or duplicates',
      () async {
    final repo = LevelRepository();
    final levels = await repo.all();
    final indices = levels.map((l) => l.globalIndex).toSet();
    expect(indices.length, ChapterDef.totalLevels);
    expect(indices, Set.from(List.generate(500, (i) => i + 1)));
  });

  test('level 1 is a small teaching board and level 500 is large', () async {
    final repo = LevelRepository();
    final first = await repo.levelByGlobalIndex(1);
    final last = await repo.levelByGlobalIndex(500);
    expect(first.rows, lessThanOrEqualTo(13));
    expect(last.rows, greaterThanOrEqualTo(20));
  });
}

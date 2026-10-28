import 'package:flutter_test/flutter_test.dart';
import 'package:outgrid/game/engine/board_model.dart';
import 'package:outgrid/game/engine/exit_checker.dart';
import 'package:outgrid/game/engine/game_state.dart';
import 'package:outgrid/game/engine/move_validator.dart';
import 'package:outgrid/models/arrow_color.dart';
import 'package:outgrid/models/arrow_path.dart';
import 'package:outgrid/models/direction.dart';
import 'package:outgrid/models/grid_point.dart';
import 'package:outgrid/models/level_model.dart';

ArrowPathDef _arrow(
  String id,
  List<List<int>> cells,
  GridDirection dir, {
  ArrowColorId color = ArrowColorId.blue,
}) {
  return ArrowPathDef(
    id: id,
    direction: dir,
    color: color,
    cells: cells.map((c) => GridPoint(c[0], c[1])).toList(),
  );
}

LevelModel _level(int rows, int cols, List<ArrowPathDef> arrows,
    {String id = 'test_level'}) {
  return LevelModel(
    id: id,
    chapterIndex: 1,
    levelInChapter: 1,
    globalIndex: 1,
    title: 'Test',
    patternFamily: PatternFamily.square,
    rows: rows,
    cols: cols,
    arrows: arrows,
    difficultyScore: 1,
  );
}

void main() {
  group('ExitChecker', () {
    test('arrow at the board edge has an empty forward lane', () {
      final arrow = _arrow('A', [
        [2, 0],
        [2, 1],
        [2, 2],
        [2, 3],
        [2, 4],
      ], GridDirection.right);
      final board = BoardState.fromLevel(_level(5, 5, [arrow]));
      const checker = ExitChecker();
      expect(checker.forwardLane(board, arrow), isEmpty);
      expect(checker.isExitLaneClear(board, arrow), isTrue);
    });

    test('horizontal lane correctly detects a blocker several cells away',
        () {
      final mover = _arrow('A', [
        [2, 0],
        [2, 1],
      ], GridDirection.right);
      final blocker = _arrow('B', [
        [2, 4],
      ], GridDirection.up, color: ArrowColorId.red);
      final board = BoardState.fromLevel(_level(5, 5, [mover, blocker]));
      const checker = ExitChecker();
      expect(checker.isExitLaneClear(board, mover), isFalse);
      expect(checker.firstBlocker(board, mover), 'B');
    });

    test('vertical lane correctly detects a blocker several cells away', () {
      final mover = _arrow('A', [
        [0, 2],
        [1, 2],
      ], GridDirection.down);
      final blocker = _arrow('B', [
        [4, 2],
      ], GridDirection.left, color: ArrowColorId.red);
      final board = BoardState.fromLevel(_level(5, 5, [mover, blocker]));
      const checker = ExitChecker();
      expect(checker.isExitLaneClear(board, mover), isFalse);
      expect(checker.firstBlocker(board, mover), 'B');
    });

    test('an arrow never blocks its own exit, even when bent', () {
      // L-shaped: travels left along row 4, then up column 0 to the head.
      // If the body were (incorrectly) included in the forward lane scan,
      // this would wrongly report itself as blocked.
      final arrow = _arrow('A', [
        [4, 3],
        [4, 2],
        [4, 1],
        [4, 0],
        [3, 0],
        [2, 0],
      ], GridDirection.up);
      final board = BoardState.fromLevel(_level(5, 5, [arrow]));
      const checker = ExitChecker();
      expect(checker.isExitLaneClear(board, arrow), isTrue);
    });

    test('removing the blocker clears the dependent lane', () {
      final mover = _arrow('X', [
        [0, 2],
        [1, 2],
        [2, 2],
      ], GridDirection.down);
      final blocker = _arrow('Y', [
        [3, 0],
        [3, 1],
        [3, 2],
      ], GridDirection.right);
      final board = BoardState.fromLevel(_level(5, 5, [mover, blocker]));
      const checker = ExitChecker();
      expect(checker.isExitLaneClear(board, mover), isFalse);
      board.removeArrow('Y');
      expect(checker.isExitLaneClear(board, mover), isTrue);
    });
  });

  group('MoveValidator', () {
    test('unknown id reports notFound', () {
      final board = BoardState.fromLevel(_level(3, 3, []));
      const validator = MoveValidator();
      expect(validator.evaluate(board, 'ghost').outcome, MoveOutcome.notFound);
    });

    test('already-removed arrow reports alreadyRemoved, not blocked', () {
      final arrow = _arrow('A', [
        [0, 0],
        [0, 1],
      ], GridDirection.right);
      final board = BoardState.fromLevel(_level(3, 3, [arrow]));
      board.removeArrow('A');
      const validator = MoveValidator();
      expect(
          validator.evaluate(board, 'A').outcome, MoveOutcome.alreadyRemoved);
    });
  });

  group('GameStateController', () {
    late ArrowPathDef x, y;
    late LevelModel level;

    setUp(() {
      // Y must be removed before X; X is otherwise clear to the edge.
      x = _arrow('X', [
        [0, 2],
        [1, 2],
        [2, 2],
      ], GridDirection.down);
      y = _arrow('Y', [
        [3, 0],
        [3, 1],
        [3, 2],
      ], GridDirection.right, color: ArrowColorId.green);
      level = _level(5, 5, [x, y]);
    });

    test('blocked move costs a heart and does not count as a move', () {
      final game = GameStateController(level: level)..start();
      final eval = game.attemptMove('X');
      expect(eval.outcome, MoveOutcome.blocked);
      expect(game.hearts, kStartingHearts - 1);
      expect(game.movesSuccessful, 0);
      expect(game.failedAttempts, 1);
      expect(game.board.isActive('X'), isTrue);
      expect(game.status, GameStatus.playing);
    });

    test('successful move enters animating, then commits on finishAnimation',
        () {
      final game = GameStateController(level: level)..start();
      final eval = game.attemptMove('Y');
      expect(eval.outcome, MoveOutcome.success);
      expect(game.status, GameStatus.animating);
      expect(game.board.isActive('Y'), isTrue, reason: 'not committed yet');

      game.finishAnimation();
      expect(game.board.isActive('Y'), isFalse);
      expect(game.movesSuccessful, 1);
      expect(game.status, GameStatus.playing);
    });

    test('duplicate input is ignored while animating', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      expect(game.status, GameStatus.animating);

      final second = game.attemptMove('X');
      expect(second.outcome, MoveOutcome.notFound);
      expect(game.hearts, kStartingHearts, reason: 'no heart charged');
      expect(game.board.isActive('X'), isTrue);
    });

    test('tapping an already-exited arrow is a safe no-op', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      game.finishAnimation();
      final result = game.attemptMove('Y');
      expect(result.outcome, MoveOutcome.alreadyRemoved);
      expect(game.hearts, kStartingHearts);
    });

    test('completing the level sets levelCompleted', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      game.finishAnimation();
      expect(game.status, GameStatus.playing);
      game.attemptMove('X');
      game.finishAnimation();
      expect(game.status, GameStatus.levelCompleted);
      expect(game.arrowsRemaining, 0);
    });

    test('three blocked moves end the level out of hearts', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('X');
      game.attemptMove('X');
      game.attemptMove('X');
      expect(game.hearts, 0);
      expect(game.status, GameStatus.outOfHearts);
      expect(game.acceptsInput, isFalse);
    });

    test('input is rejected once out of hearts', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('X');
      game.attemptMove('X');
      game.attemptMove('X');
      final afterFail = game.attemptMove('Y');
      expect(afterFail.outcome, MoveOutcome.notFound);
      expect(game.board.isActive('Y'), isTrue);
    });

    test('undo restores board, hearts, and move count after a success', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      game.finishAnimation();
      expect(game.movesSuccessful, 1);

      game.undo();
      expect(game.movesSuccessful, 0);
      expect(game.board.isActive('Y'), isTrue);
      expect(game.hearts, kStartingHearts);
      expect(game.status, GameStatus.playing);
    });

    test('undo restores a heart lost to a blocked attempt', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('X');
      expect(game.hearts, kStartingHearts - 1);
      game.undo();
      expect(game.hearts, kStartingHearts);
      expect(game.failedAttempts, 0);
    });

    test('repeated undo calls past the start of history are a safe no-op',
        () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      game.finishAnimation();
      expect(game.board.isActive('Y'), isFalse);

      game.undo();
      expect(game.board.isActive('Y'), isTrue);
      expect(game.board.isActive('X'), isTrue);

      // The undo stack is now empty; further calls must not corrupt state
      // or duplicate arrows.
      game.undo();
      game.undo();
      expect(game.board.allArrowIds.where(game.board.isActive).length, 2);
    });

    test('reset restores the original validated board and counters', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('X'); // blocked, costs a heart
      game.attemptMove('Y');
      game.finishAnimation();

      game.reset();
      expect(game.hearts, kStartingHearts);
      expect(game.movesSuccessful, 0);
      expect(game.failedAttempts, 0);
      expect(game.arrowsRemaining, 2);
      expect(game.board.isActive('X'), isTrue);
      expect(game.board.isActive('Y'), isTrue);
      expect(game.status, GameStatus.ready);
    });

    test('hint only ever suggests an arrow with a verified clear lane', () {
      final game = GameStateController(level: level)..start();
      final hint = game.findHint();
      expect(hint, 'Y', reason: 'X is blocked by Y at this point');

      game.attemptMove('Y');
      game.finishAnimation();
      final nextHint = game.findHint();
      expect(nextHint, 'X');
    });

    test('hint returns null once the board is clear', () {
      final game = GameStateController(level: level)..start();
      game.attemptMove('Y');
      game.finishAnimation();
      game.attemptMove('X');
      game.finishAnimation();
      expect(game.findHint(), isNull);
    });

    test('restoreFrom rehydrates a saved mid-level snapshot exactly', () {
      final fresh = GameStateController(level: level)..start();
      fresh.attemptMove('Y');
      fresh.finishAnimation();
      fresh.attemptMove('X'); // would be blocked if Y weren't gone
      fresh.finishAnimation();
      final solvedStatus = fresh.status;

      // Simulate reopening the app: a brand-new controller, rehydrated
      // from what would have been persisted after the first move only.
      final resumed = GameStateController(level: level);
      resumed.restoreFrom(
        removedArrowIds: const ['Y'],
        hearts: 2,
        moves: 1,
        failedAttempts: 1,
      );
      expect(resumed.board.isActive('Y'), isFalse);
      expect(resumed.board.isActive('X'), isTrue);
      expect(resumed.hearts, 2);
      expect(resumed.movesSuccessful, 1);
      expect(resumed.failedAttempts, 1);
      expect(resumed.status, GameStatus.ready);

      resumed.start();
      expect(resumed.status, GameStatus.playing);
      resumed.attemptMove('X');
      resumed.finishAnimation();
      expect(resumed.status, solvedStatus);
      expect(resumed.status, GameStatus.levelCompleted);
    });
  });
}

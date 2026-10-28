import 'package:flutter_test/flutter_test.dart';
import 'package:outgrid/game/generation/difficulty_analyzer.dart';
import 'package:outgrid/game/generation/puzzle_solver.dart';
import 'package:outgrid/game/generation/puzzle_validator.dart';
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

LevelModel _level(
  int rows,
  int cols,
  List<ArrowPathDef> arrows, {
  String id = 'test_level',
  PatternFamily family = PatternFamily.square,
}) {
  return LevelModel(
    id: id,
    chapterIndex: 1,
    levelInChapter: 1,
    globalIndex: 1,
    title: 'Test',
    patternFamily: family,
    rows: rows,
    cols: cols,
    arrows: arrows,
    difficultyScore: 1,
  );
}

void main() {
  group('PuzzleSolver', () {
    test('solves a simple dependency chain in a valid topological order',
        () {
      final x = _arrow('X', [
        [0, 2],
        [1, 2],
        [2, 2],
      ], GridDirection.down);
      final y = _arrow('Y', [
        [3, 0],
        [3, 1],
        [3, 2],
      ], GridDirection.right);
      final level = _level(5, 5, [x, y]);

      final result = const PuzzleSolver().solve(level);
      expect(result.solvable, isTrue);
      expect(result.order, isNotNull);
      expect(result.order!.toSet(), {'X', 'Y'});
      expect(result.order!.indexOf('Y'), lessThan(result.order!.indexOf('X')),
          reason: 'Y blocks X, so Y must be removed first');
    });

    test('detects a mutual two-arrow cycle as unsolvable', () {
      final a = _arrow('A', [
        [0, 0],
        [0, 1],
      ], GridDirection.right);
      final b = _arrow('B', [
        [0, 3],
      ], GridDirection.left);
      final level = _level(1, 4, [a, b]);

      final result = const PuzzleSolver().solve(level);
      expect(result.solvable, isFalse);
      expect(result.unresolvedArrowIds!.toSet(), {'A', 'B'});
    });

    test('independent arrows all resolve with zero dependency chain', () {
      final a = _arrow('A', [
        [0, 0],
      ], GridDirection.left);
      final b = _arrow('B', [
        [2, 2],
      ], GridDirection.right);
      final level = _level(5, 5, [a, b]);
      final result = const PuzzleSolver().solve(level);
      expect(result.solvable, isTrue);
      expect(const PuzzleSolver().longestChain(result, level), 1);
    });
  });

  group('PuzzleValidator', () {
    test('accepts a clean, solvable level with zero issues', () {
      final x = _arrow('X', [
        [0, 2],
        [1, 2],
      ], GridDirection.down);
      final y = _arrow('Y', [
        [3, 0],
        [3, 1],
        [3, 2],
      ], GridDirection.right);
      final level = _level(5, 5, [x, y]);
      final report = const PuzzleValidator().validate(level);
      expect(report.passed, isTrue);
      expect(report.issues, isEmpty);
      expect(report.solved, isTrue);
      expect(report.difficultyScore, greaterThan(0));
    });

    test('flags overlapping cells between two different arrows', () {
      final a = _arrow('A', [
        [0, 0],
        [0, 1],
      ], GridDirection.right);
      final b = _arrow('B', [
        [0, 1],
        [1, 1],
      ], GridDirection.down);
      final level = _level(5, 5, [a, b]);
      final report = const PuzzleValidator().validate(level);
      expect(report.passed, isFalse);
      expect(report.issues.any((i) => i.code == 'CELL_OVERLAP'), isTrue);
    });

    test('flags a diagonal (disconnected) step in a path', () {
      final bad = _arrow('A', [
        [0, 0],
        [1, 1],
      ], GridDirection.down);
      final level = _level(5, 5, [bad]);
      final report = const PuzzleValidator().validate(level);
      expect(report.issues.any((i) => i.code == 'DISCONNECTED_PATH'), isTrue);
    });

    test('flags a cell outside board bounds', () {
      final bad = _arrow('A', [
        [0, 0],
        [0, -1],
      ], GridDirection.left);
      final level = _level(5, 5, [bad]);
      final report = const PuzzleValidator().validate(level);
      expect(report.issues.any((i) => i.code == 'OUT_OF_BOUNDS'), isTrue);
    });

    test('flags a body cell sitting in the arrow\'s own forward lane', () {
      // Direction up but a body cell is further up than the head itself.
      final bad = ArrowPathDef(
        id: 'A',
        direction: GridDirection.up,
        color: ArrowColorId.blue,
        cells: const [GridPoint(0, 0), GridPoint(2, 0), GridPoint(1, 0)],
      );
      final level = _level(5, 5, [bad]);
      final report = const PuzzleValidator().validate(level);
      expect(report.issues.any((i) => i.code == 'SELF_BLOCKING'), isTrue);
    });

    test('flags an unsolvable (cyclic) level', () {
      final a = _arrow('A', [
        [0, 0],
        [0, 1],
      ], GridDirection.right);
      final b = _arrow('B', [
        [0, 3],
      ], GridDirection.left);
      final level = _level(1, 4, [a, b]);
      final report = const PuzzleValidator().validate(level);
      expect(report.passed, isFalse);
      expect(report.issues.any((i) => i.code == 'UNSOLVABLE'), isTrue);
    });
  });

  group('DifficultyAnalyzer', () {
    test('a denser, longer-chain board scores higher than a trivial one',
        () {
      final trivial = _level(10, 10, [
        _arrow('A', [
          [0, 0]
        ], GridDirection.left),
      ]);
      final trivialResult = const PuzzleSolver().solve(trivial);
      final trivialScore =
          const DifficultyAnalyzer().score(trivial, trivialResult);

      final chain = _level(6, 6, [
        _arrow('A', [
          [0, 2],
          [1, 2]
        ], GridDirection.down),
        _arrow('B', [
          [3, 0],
          [3, 1],
          [3, 2]
        ], GridDirection.right),
        _arrow('C', [
          [5, 0],
          [5, 1]
        ], GridDirection.right),
      ]);
      final chainResult = const PuzzleSolver().solve(chain);
      final chainScore = const DifficultyAnalyzer().score(chain, chainResult);

      expect(chainScore, greaterThan(trivialScore));
    });
  });
}

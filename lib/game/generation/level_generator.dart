import 'dart:math' as math;

import '../../models/arrow_color.dart';
import '../../models/arrow_path.dart';
import '../../models/direction.dart';
import '../../models/grid_point.dart';
import '../../models/level_model.dart';
import 'puzzle_validator.dart';
import 'silhouette_library.dart';

class GenerationResult {
  final LevelModel? level;
  final ValidationReport? report;
  final int attempts;
  final bool failed;

  const GenerationResult({
    this.level,
    this.report,
    required this.attempts,
    this.failed = false,
  });
}

/// Builds validated OUTGRID levels via reverse construction: fill a
/// silhouette mask with non-overlapping arrow paths (walking only
/// sideways or toward each arrow's own chosen exit direction, which by
/// construction guarantees no arrow can ever block its own exit), assign
/// contrasting colors, then hand the candidate to [PuzzleValidator] —
/// retrying with a new seed if the dependency graph happens to contain a
/// cycle.
class LevelGenerator {
  final PuzzleValidator validator;

  const LevelGenerator({this.validator = const PuzzleValidator()});

  GenerationResult generate({
    required String id,
    required int chapterIndex,
    required int levelInChapter,
    required int globalIndex,
    required String title,
    required PatternFamily family,
    required int rows,
    required int cols,
    required int seed,
    int? timeLimitSeconds,
    int maxAttempts = 150,
  }) {
    final builder = silhouetteBuilders[family];
    if (builder == null) {
      throw ArgumentError('No silhouette builder registered for $family');
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final rng = math.Random(seed + attempt * 7919 + 104729);
      final mask = builder(rows, cols, rng);
      final arrows = _buildArrows(mask, rows, cols, rng);
      if (arrows.isEmpty) continue;

      final candidate = LevelModel(
        id: id,
        chapterIndex: chapterIndex,
        levelInChapter: levelInChapter,
        globalIndex: globalIndex,
        title: title,
        patternFamily: family,
        rows: rows,
        cols: cols,
        arrows: arrows,
        difficultyScore: 0,
        suggestedTimeLimitSeconds: timeLimitSeconds,
      );

      final report = validator.validate(candidate);
      if (report.passed) {
        final finalLevel = LevelModel(
          id: id,
          chapterIndex: chapterIndex,
          levelInChapter: levelInChapter,
          globalIndex: globalIndex,
          title: title,
          patternFamily: family,
          rows: rows,
          cols: cols,
          arrows: arrows,
          difficultyScore: report.difficultyScore,
          suggestedTimeLimitSeconds: timeLimitSeconds,
        );
        return GenerationResult(
            level: finalLevel, report: report, attempts: attempt + 1);
      }
    }
    return GenerationResult(attempts: maxAttempts, failed: true);
  }

  List<ArrowPathDef> _buildArrows(
    List<List<bool>> mask,
    int rows,
    int cols,
    math.Random rng,
  ) {
    final filled = List.generate(rows, (_) => List<bool>.filled(cols, false));
    final ownerColor =
        List.generate(rows, (_) => List<ArrowColorId?>.filled(cols, null));
    final colorUsage = <ArrowColorId, int>{
      for (final c in ArrowColorId.values) c: 0,
    };
    final centerRow = (rows - 1) / 2.0;
    final centerCol = (cols - 1) / 2.0;
    final arrows = <ArrowPathDef>[];
    var arrowIndex = 0;

    GridPoint? findSeed() {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (mask[r][c] && !filled[r][c]) return GridPoint(r, c);
        }
      }
      return null;
    }

    GridDirection chooseDirection(GridPoint from) {
      final dRow = from.row - centerRow;
      final dCol = from.col - centerCol;
      final primaryVertical = dRow.abs() >= dCol.abs();
      final vertical = dRow <= 0 ? GridDirection.up : GridDirection.down;
      final horizontal = dCol <= 0 ? GridDirection.left : GridDirection.right;
      if (rng.nextDouble() < 0.12) {
        return GridDirection.values[rng.nextInt(4)];
      }
      final primary = primaryVertical ? vertical : horizontal;
      final secondary = primaryVertical ? horizontal : vertical;
      return rng.nextDouble() < 0.78 ? primary : secondary;
    }

    bool inBounds(GridPoint p) =>
        p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

    while (true) {
      final seed = findSeed();
      if (seed == null) break;

      final direction = chooseDirection(seed);
      final path = <GridPoint>[seed];
      final inPath = <GridPoint>{seed};
      filled[seed.row][seed.col] = true;
      var current = seed;
      final maxLen = 3 + rng.nextInt(7);

      bool validStep(GridPoint p) =>
          inBounds(p) &&
          mask[p.row][p.col] &&
          !filled[p.row][p.col] &&
          !inPath.contains(p);

      while (path.length < maxLen) {
        final forward = current.translate(direction.dRow, direction.dCol);
        final perpOptions = direction.isHorizontal
            ? [current.translate(-1, 0), current.translate(1, 0)]
            : [current.translate(0, -1), current.translate(0, 1)];

        final candidates = <GridPoint>[];
        final forwardValid = validStep(forward);
        if (forwardValid) candidates.add(forward);
        for (final p in perpOptions) {
          if (validStep(p)) candidates.add(p);
        }
        if (candidates.isEmpty) break;

        final GridPoint next;
        if (forwardValid && rng.nextDouble() < 0.6) {
          next = forward;
        } else {
          next = candidates[rng.nextInt(candidates.length)];
        }
        path.add(next);
        inPath.add(next);
        filled[next.row][next.col] = true;
        current = next;
      }

      final neighborColors = <ArrowColorId>{};
      for (final cell in path) {
        for (final n in [
          cell.translate(-1, 0),
          cell.translate(1, 0),
          cell.translate(0, -1),
          cell.translate(0, 1),
        ]) {
          if (inBounds(n)) {
            final oc = ownerColor[n.row][n.col];
            if (oc != null) neighborColors.add(oc);
          }
        }
      }
      final available = ArrowColorId.values
          .where((c) => !neighborColors.contains(c))
          .toList()
        ..sort((a, b) => colorUsage[a]!.compareTo(colorUsage[b]!));
      final chosenColor = available.isNotEmpty
          ? available.first
          : (List.of(ArrowColorId.values)
            ..sort((a, b) => colorUsage[a]!.compareTo(colorUsage[b]!)))
              .first;
      colorUsage[chosenColor] = colorUsage[chosenColor]! + 1;
      for (final cell in path) {
        ownerColor[cell.row][cell.col] = chosenColor;
      }

      arrows.add(ArrowPathDef(
        id: 'a${arrowIndex++}',
        cells: path,
        direction: direction,
        color: chosenColor,
      ));
    }

    return arrows;
  }
}

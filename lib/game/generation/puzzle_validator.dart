import '../../models/direction.dart';
import '../../models/level_model.dart';
import 'difficulty_analyzer.dart';
import 'puzzle_solver.dart';

class ValidationIssue {
  final String code;
  final String message;
  final String? arrowId;

  const ValidationIssue(this.code, this.message, {this.arrowId});

  @override
  String toString() =>
      arrowId == null ? '[$code] $message' : '[$code] $message (arrow $arrowId)';
}

class ValidationReport {
  final String levelId;
  final PatternFamily patternFamily;
  final int rows;
  final int cols;
  final int arrowCount;
  final int difficultyScore;
  final bool solved;
  final List<ValidationIssue> issues;

  const ValidationReport({
    required this.levelId,
    required this.patternFamily,
    required this.rows,
    required this.cols,
    required this.arrowCount,
    required this.difficultyScore,
    required this.solved,
    required this.issues,
  });

  bool get passed => issues.isEmpty && solved;

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'pattern': patternFamily.name,
        'rows': rows,
        'cols': cols,
        'arrowCount': arrowCount,
        'difficulty': difficultyScore,
        'solved': solved,
        'passed': passed,
        'issues': issues.map((i) => i.toString()).toList(),
      };
}

/// Runs every structural + solvability check required before a level can
/// ship, per the design brief's "Required automated checks" list.
class PuzzleValidator {
  final PuzzleSolver _solver;
  final DifficultyAnalyzer _analyzer;

  const PuzzleValidator({
    PuzzleSolver solver = const PuzzleSolver(),
    DifficultyAnalyzer analyzer = const DifficultyAnalyzer(),
  })  : _solver = solver,
        _analyzer = analyzer;

  ValidationReport validate(LevelModel level) {
    final issues = <ValidationIssue>[];

    if (level.arrows.isEmpty) {
      issues.add(const ValidationIssue('EMPTY_BOARD', 'Level has no arrows'));
    }
    if (level.rows <= 0 || level.cols <= 0) {
      issues.add(ValidationIssue(
          'BAD_DIMENSIONS', 'Non-positive board size ${level.rows}x${level.cols}'));
    }

    final seenCells = <String, String>{}; // "r,c" -> owning arrowId
    final seenIds = <String>{};

    for (final arrow in level.arrows) {
      if (!seenIds.add(arrow.id)) {
        issues.add(ValidationIssue('DUPLICATE_ID',
            'Arrow id used more than once', arrowId: arrow.id));
        continue;
      }
      if (arrow.cells.isEmpty) {
        issues.add(ValidationIssue('EMPTY_PATH', 'Arrow has no cells',
            arrowId: arrow.id));
        continue;
      }

      // Bounds.
      for (final cell in arrow.cells) {
        if (cell.row < 0 ||
            cell.row >= level.rows ||
            cell.col < 0 ||
            cell.col >= level.cols) {
          issues.add(ValidationIssue(
              'OUT_OF_BOUNDS', 'Cell $cell outside ${level.rows}x${level.cols}',
              arrowId: arrow.id));
        }
      }

      // Connectivity: consecutive cells must be exactly one orthogonal
      // step apart (no diagonals, no teleports, no repeats).
      for (var i = 1; i < arrow.cells.length; i++) {
        final a = arrow.cells[i - 1];
        final b = arrow.cells[i];
        final manhattan = (a.row - b.row).abs() + (a.col - b.col).abs();
        if (manhattan != 1) {
          issues.add(ValidationIssue('DISCONNECTED_PATH',
              'Non-adjacent step between $a and $b', arrowId: arrow.id));
        }
      }

      // No internal self-overlap.
      if (arrow.cells.toSet().length != arrow.cells.length) {
        issues.add(ValidationIssue(
            'SELF_OVERLAP', 'Path revisits a cell', arrowId: arrow.id));
      }

      // Arrowhead must be the strictly extremal cell along its own axis so
      // the arrow can never block its own exit lane.
      final head = arrow.head;
      for (final cell in arrow.cells) {
        if (cell == head) continue;
        final blocksSelf = switch (arrow.direction) {
          GridDirection.up => cell.col == head.col && cell.row < head.row,
          GridDirection.down => cell.col == head.col && cell.row > head.row,
          GridDirection.left => cell.row == head.row && cell.col < head.col,
          GridDirection.right => cell.row == head.row && cell.col > head.col,
        };
        if (blocksSelf) {
          issues.add(ValidationIssue('SELF_BLOCKING',
              'Arrow body cell $cell lies in its own forward lane',
              arrowId: arrow.id));
        }
      }

      // Cross-arrow overlap.
      for (final cell in arrow.cells) {
        final key = '${cell.row},${cell.col}';
        final owner = seenCells[key];
        if (owner != null && owner != arrow.id) {
          issues.add(ValidationIssue(
              'CELL_OVERLAP', 'Cell $cell shared with arrow $owner',
              arrowId: arrow.id));
        } else {
          seenCells[key] = arrow.id;
        }
      }
    }

    final solveResult = _solver.solve(level);
    if (!solveResult.solvable) {
      issues.add(ValidationIssue(
        'UNSOLVABLE',
        'Dependency cycle among: ${solveResult.unresolvedArrowIds?.join(', ')}',
      ));
    } else if (solveResult.order!.length != level.arrows.length) {
      issues.add(const ValidationIssue(
          'INCOMPLETE_SOLUTION', 'Solver order does not clear every arrow'));
    }

    final difficulty =
        solveResult.solvable ? _analyzer.score(level, solveResult) : 0;

    return ValidationReport(
      levelId: level.id,
      patternFamily: level.patternFamily,
      rows: level.rows,
      cols: level.cols,
      arrowCount: level.arrows.length,
      difficultyScore: difficulty,
      solved: solveResult.solvable,
      issues: issues,
    );
  }
}

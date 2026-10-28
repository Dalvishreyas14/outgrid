import '../../models/level_model.dart';
import 'puzzle_solver.dart';

/// Converts structural facts about a solved puzzle into a 1-100 difficulty
/// score, driven by dependency-chain depth and branching rather than raw
/// arrow count, per the design brief ("difficulty must be determined by
/// actual puzzle complexity, not merely by adding more arrows").
class DifficultyAnalyzer {
  const DifficultyAnalyzer();

  int score(LevelModel level, SolveResult solveResult) {
    if (!solveResult.solvable) return 0;
    final arrowCount = level.arrows.length;
    final area = level.rows * level.cols;
    final density = area == 0 ? 0.0 : arrowCount / area;
    final chain = const PuzzleSolver().longestChain(solveResult, level);
    final totalDeps = solveResult.dependencies.values
        .fold<int>(0, (sum, s) => sum + s.length);
    final avgDeps = arrowCount == 0 ? 0.0 : totalDeps / arrowCount;
    final maxDeps = solveResult.dependencies.values
        .map((s) => s.length)
        .fold<int>(0, (a, b) => a > b ? a : b);

    final raw = 6.0 +
        arrowCount * 0.45 +
        chain * 5.5 +
        avgDeps * 7.0 +
        maxDeps * 2.0 +
        density * 18.0;

    return raw.clamp(1, 100).round();
  }

  /// Human-readable difficulty tier, used in UI chapter cards and reports.
  String tier(int score) {
    if (score <= 15) return 'Beginner';
    if (score <= 32) return 'Easy';
    if (score <= 50) return 'Medium';
    if (score <= 68) return 'Hard';
    if (score <= 85) return 'Expert';
    return 'Master';
  }
}

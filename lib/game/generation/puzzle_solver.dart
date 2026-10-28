import '../../models/direction.dart';
import '../../models/grid_point.dart';
import '../../models/level_model.dart';

/// Result of solving a level's arrow-dependency graph.
class SolveResult {
  final bool solvable;

  /// A valid full removal order, present iff [solvable].
  final List<String>? order;

  /// Arrows left over because they sit in a dependency cycle (or depend,
  /// directly or transitively, on one) — present iff not [solvable].
  final List<String>? unresolvedArrowIds;

  /// arrowId -> set of arrow ids that must be removed before it.
  final Map<String, Set<String>> dependencies;

  const SolveResult({
    required this.solvable,
    required this.dependencies,
    this.order,
    this.unresolvedArrowIds,
  });
}

/// Solves OUTGRID boards by exploiting a key structural property of the
/// exit rule: an arrow's forward lane is a fixed set of grid cells
/// (geometry never changes), and removing arrows only ever *clears*
/// cells, never occupies new ones. So "B blocks A" is a static fact
/// computable once from the initial board, and the whole puzzle reduces
/// to topologically sorting the resulting dependency DAG — no search or
/// backtracking needed. A puzzle is solvable iff that graph is acyclic,
/// and when it is, *any* topological order is a valid play-through,
/// which is also what guarantees the hint system and undo/redo can never
/// paint the player into an unsolvable corner.
class PuzzleSolver {
  const PuzzleSolver();

  /// arrowId -> ids of arrows whose cells occupy its forward lane.
  Map<String, Set<String>> buildDependencyGraph(LevelModel level) {
    final occupancy = <String, String>{}; // "row,col" -> arrowId
    for (final arrow in level.arrows) {
      for (final cell in arrow.cells) {
        occupancy['${cell.row},${cell.col}'] = arrow.id;
      }
    }

    final deps = <String, Set<String>>{};
    for (final arrow in level.arrows) {
      final blockers = <String>{};
      var cursor =
          arrow.head.translate(arrow.direction.dRow, arrow.direction.dCol);
      while (_inBounds(cursor, level.rows, level.cols)) {
        final occupant = occupancy['${cursor.row},${cursor.col}'];
        if (occupant != null && occupant != arrow.id) {
          blockers.add(occupant);
        }
        cursor = cursor.translate(arrow.direction.dRow, arrow.direction.dCol);
      }
      deps[arrow.id] = blockers;
    }
    return deps;
  }

  bool _inBounds(GridPoint p, int rows, int cols) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  SolveResult solve(LevelModel level) {
    final deps = buildDependencyGraph(level);
    final inDegree = <String, int>{
      for (final e in deps.entries) e.key: e.value.length,
    };
    // dependents[B] = arrows that become more-ready once B is removed.
    final dependents = <String, List<String>>{
      for (final id in deps.keys) id: [],
    };
    for (final entry in deps.entries) {
      for (final blocker in entry.value) {
        dependents[blocker]?.add(entry.key);
      }
    }

    final ready = [
      for (final id in level.arrows.map((a) => a.id))
        if (inDegree[id] == 0) id,
    ]..sort();
    final order = <String>[];
    final remainingInDegree = Map.of(inDegree);

    while (ready.isNotEmpty) {
      ready.sort();
      final next = ready.removeAt(0);
      order.add(next);
      for (final dependent in dependents[next] ?? const <String>[]) {
        remainingInDegree[dependent] = remainingInDegree[dependent]! - 1;
        if (remainingInDegree[dependent] == 0) {
          ready.add(dependent);
        }
      }
    }

    if (order.length == level.arrows.length) {
      return SolveResult(solvable: true, dependencies: deps, order: order);
    }
    final unresolved = level.arrows
        .map((a) => a.id)
        .where((id) => !order.contains(id))
        .toList();
    return SolveResult(
      solvable: false,
      dependencies: deps,
      unresolvedArrowIds: unresolved,
    );
  }

  /// Length of the longest dependency chain (critical path), used by the
  /// difficulty analyzer. 0 for an empty or fully-independent board.
  int longestChain(SolveResult result, LevelModel level) {
    final memo = <String, int>{};
    int depthOf(String id) {
      if (memo.containsKey(id)) return memo[id]!;
      final deps = result.dependencies[id] ?? const <String>{};
      if (deps.isEmpty) return memo[id] = 1;
      final best = deps.map(depthOf).reduce((a, b) => a > b ? a : b);
      return memo[id] = best + 1;
    }

    var longest = 0;
    for (final arrow in level.arrows) {
      final d = depthOf(arrow.id);
      if (d > longest) longest = d;
    }
    return longest;
  }
}

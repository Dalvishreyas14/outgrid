import '../../models/arrow_path.dart';
import '../../models/grid_point.dart';
import '../../models/level_model.dart';

/// Mutable runtime board built from an immutable [LevelModel].
///
/// Owns the occupancy map so exit-lane checks are O(board edge) instead of
/// O(arrow count). Arrow *definitions* (shape/direction/color) never
/// change after construction — only each arrow's active/removed flag and
/// the occupancy cells that follow from it.
class BoardState {
  final String levelId;
  final int rows;
  final int cols;
  final Map<String, ArrowPathDef> _arrowsById;
  final List<String> _orderedArrowIds;
  final Set<String> _activeIds;

  /// occupancy[row][col] == arrow id occupying that cell, or null if empty.
  final List<List<String?>> occupancy;

  BoardState._(
    this.levelId,
    this.rows,
    this.cols,
    this._arrowsById,
    this._orderedArrowIds,
    this._activeIds,
    this.occupancy,
  );

  factory BoardState.fromLevel(LevelModel level) {
    final byId = <String, ArrowPathDef>{};
    final order = <String>[];
    final occ = List.generate(
      level.rows,
      (_) => List<String?>.filled(level.cols, null),
    );
    for (final arrow in level.arrows) {
      byId[arrow.id] = arrow;
      order.add(arrow.id);
      for (final cell in arrow.cells) {
        occ[cell.row][cell.col] = arrow.id;
      }
    }
    return BoardState._(
      level.id,
      level.rows,
      level.cols,
      byId,
      order,
      order.toSet(),
      occ,
    );
  }

  List<String> get allArrowIds => List.unmodifiable(_orderedArrowIds);

  ArrowPathDef arrowDef(String id) => _arrowsById[id]!;

  bool isActive(String id) => _activeIds.contains(id);

  bool get allCleared => _activeIds.isEmpty;

  int get remainingCount => _activeIds.length;

  List<ArrowPathDef> get activeArrows =>
      _orderedArrowIds.where(_activeIds.contains).map((id) => _arrowsById[id]!).toList();

  bool inBounds(GridPoint p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  String? occupantAt(GridPoint p) {
    if (!inBounds(p)) return null;
    return occupancy[p.row][p.col];
  }

  /// Removes an arrow's cells from the occupancy map and marks it inactive.
  /// Caller (MoveValidator / GameStateController) is responsible for
  /// confirming the move is legal before calling this.
  void removeArrow(String id) {
    if (!_activeIds.contains(id)) return;
    final def = _arrowsById[id]!;
    for (final cell in def.cells) {
      occupancy[cell.row][cell.col] = null;
    }
    _activeIds.remove(id);
  }

  /// Reinstates a previously removed arrow (used by undo).
  void restoreArrow(String id) {
    if (_activeIds.contains(id)) return;
    final def = _arrowsById[id]!;
    for (final cell in def.cells) {
      occupancy[cell.row][cell.col] = id;
    }
    _activeIds.add(id);
  }
}

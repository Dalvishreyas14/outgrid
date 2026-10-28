import '../../models/arrow_path.dart';
import '../../models/direction.dart';
import '../../models/grid_point.dart';
import 'board_model.dart';

/// Determines whether an arrow's forward exit lane — every cell from one
/// step beyond its arrowhead out to the board edge, along the arrowhead's
/// direction — is free of other active arrows.
///
/// This checks the *entire* lane (not just the adjacent cell), and
/// explicitly ignores cells that belong to the arrow's own body so a
/// path can never block its own exit.
class ExitChecker {
  const ExitChecker();

  /// All cells in the forward lane, in travel order, stopping at the
  /// board boundary. Does not include the head cell itself.
  List<GridPoint> forwardLane(BoardState board, ArrowPathDef arrow) {
    final lane = <GridPoint>[];
    final head = arrow.head;
    var cursor = head.translate(arrow.direction.dRow, arrow.direction.dCol);
    while (board.inBounds(cursor)) {
      lane.add(cursor);
      cursor = cursor.translate(arrow.direction.dRow, arrow.direction.dCol);
    }
    return lane;
  }

  /// True if every cell of the forward lane is empty or occupied only by
  /// this same arrow (which should not happen given a valid level, but is
  /// guarded against defensively).
  bool isExitLaneClear(BoardState board, ArrowPathDef arrow) {
    for (final cell in forwardLane(board, arrow)) {
      final occupant = board.occupantAt(cell);
      if (occupant != null && occupant != arrow.id) {
        return false;
      }
    }
    return true;
  }

  /// Id of the first blocking arrow in the lane, or null if clear.
  String? firstBlocker(BoardState board, ArrowPathDef arrow) {
    for (final cell in forwardLane(board, arrow)) {
      final occupant = board.occupantAt(cell);
      if (occupant != null && occupant != arrow.id) {
        return occupant;
      }
    }
    return null;
  }
}

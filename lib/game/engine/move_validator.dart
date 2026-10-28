import 'board_model.dart';
import 'exit_checker.dart';

enum MoveOutcome {
  /// Arrow existed, was active, and its lane was clear — safe to remove.
  success,

  /// Arrow existed and was active, but another arrow blocks its lane.
  blocked,

  /// Arrow id does not exist on this board.
  notFound,

  /// Arrow already exited; tapping it again is a no-op, not a mistake.
  alreadyRemoved,
}

class MoveEvaluation {
  final MoveOutcome outcome;
  final String? blockerArrowId;

  const MoveEvaluation(this.outcome, {this.blockerArrowId});

  bool get isMistake => outcome == MoveOutcome.blocked;
  bool get isSuccess => outcome == MoveOutcome.success;
}

/// Pure (non-mutating) rule check for "can this arrow leave the board
/// right now". Mutation (actually removing the arrow, charging a heart)
/// is the responsibility of the caller (GameStateController) so this
/// class stays trivially unit-testable.
class MoveValidator {
  final ExitChecker exitChecker;

  const MoveValidator({this.exitChecker = const ExitChecker()});

  MoveEvaluation evaluate(BoardState board, String arrowId) {
    if (!board.allArrowIds.contains(arrowId)) {
      return const MoveEvaluation(MoveOutcome.notFound);
    }
    if (!board.isActive(arrowId)) {
      return const MoveEvaluation(MoveOutcome.alreadyRemoved);
    }
    final arrow = board.arrowDef(arrowId);
    final blocker = exitChecker.firstBlocker(board, arrow);
    if (blocker == null) {
      return const MoveEvaluation(MoveOutcome.success);
    }
    return MoveEvaluation(MoveOutcome.blocked, blockerArrowId: blocker);
  }
}

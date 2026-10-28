import 'package:flutter/foundation.dart';

import '../../models/level_model.dart';
import 'board_model.dart';
import 'exit_checker.dart';
import 'move_validator.dart';

enum GameStatus {
  ready,
  playing,
  animating,
  paused,
  levelCompleted,
  outOfHearts,
  timeExpired,
  levelFailed,
}

class _Snapshot {
  final Set<String> activeIds;
  final int hearts;
  final int moves;
  final int failedAttempts;

  const _Snapshot({
    required this.activeIds,
    required this.hearts,
    required this.moves,
    required this.failedAttempts,
  });
}

const int kStartingHearts = 3;

/// Owns all mutable gameplay state for one level attempt: the board,
/// hearts/moves/undo history, and the status machine described in the
/// design brief. UI widgets read this via [ChangeNotifier] and drive it
/// through [attemptMove] / [finishAnimation] / [undo] / [reset] / [hint].
///
/// Kept framework-light (no BuildContext, no animation timing) so it is
/// directly unit-testable.
class GameStateController extends ChangeNotifier {
  final LevelModel level;
  final bool timedMode;
  final MoveValidator _validator;
  final ExitChecker _exitChecker;

  late BoardState board;
  GameStatus status = GameStatus.ready;
  int hearts = kStartingHearts;
  int movesSuccessful = 0;
  int failedAttempts = 0;

  String? lastRemovedArrowId;
  String? lastBlockedArrowId;
  String? hintArrowId;

  /// Bumped on every resolved tap (success or blocked) — never on
  /// no-ops. Lets the rendering layer detect "a new action happened"
  /// even when it targets the same arrow id as last time (e.g. the
  /// player taps the same blocked arrow twice in a row), which plain
  /// value-equality on lastBlockedArrowId can't distinguish.
  int actionVersion = 0;

  Duration? timeRemaining;

  final List<_Snapshot> _undoStack = [];

  GameStateController({
    required this.level,
    this.timedMode = false,
    MoveValidator validator = const MoveValidator(),
    ExitChecker exitChecker = const ExitChecker(),
  })  : _validator = validator,
        _exitChecker = exitChecker {
    board = BoardState.fromLevel(level);
    if (timedMode && level.suggestedTimeLimitSeconds != null) {
      timeRemaining = Duration(seconds: level.suggestedTimeLimitSeconds!);
    }
  }

  bool get acceptsInput => status == GameStatus.playing;
  bool get canUndo => _undoStack.isNotEmpty && acceptsInput;
  bool get isFailure =>
      status == GameStatus.outOfHearts ||
      status == GameStatus.timeExpired ||
      status == GameStatus.levelFailed;
  int get arrowsRemaining => board.remainingCount;
  int get totalArrows => level.arrows.length;

  /// Moves the controller from the initial [GameStatus.ready] state into
  /// [GameStatus.playing], accepting input. Safe to call once per attempt.
  void start() {
    if (status == GameStatus.ready) {
      status = GameStatus.playing;
      notifyListeners();
    }
  }

  void _pushSnapshot() {
    _undoStack.add(_Snapshot(
      activeIds: Set.of(board.allArrowIds.where(board.isActive)),
      hearts: hearts,
      moves: movesSuccessful,
      failedAttempts: failedAttempts,
    ));
  }

  /// Attempts to tap-remove [arrowId]. Returns the rule evaluation so the
  /// caller (gameplay widget) knows whether to play an escape animation
  /// or a blocked-shake animation. A [MoveOutcome.success] result puts
  /// the controller into [GameStatus.animating] — the caller MUST call
  /// [finishAnimation] once the visual animation completes, which is
  /// also what blocks duplicate input mid-animation.
  MoveEvaluation attemptMove(String arrowId) {
    if (!acceptsInput) {
      return const MoveEvaluation(MoveOutcome.notFound);
    }
    final evaluation = _validator.evaluate(board, arrowId);
    switch (evaluation.outcome) {
      case MoveOutcome.notFound:
      case MoveOutcome.alreadyRemoved:
        return evaluation;
      case MoveOutcome.blocked:
        _pushSnapshot();
        failedAttempts++;
        hearts--;
        lastBlockedArrowId = arrowId;
        hintArrowId = null;
        actionVersion++;
        status = hearts <= 0 ? GameStatus.outOfHearts : GameStatus.playing;
        notifyListeners();
        return evaluation;
      case MoveOutcome.success:
        _pushSnapshot();
        lastRemovedArrowId = arrowId;
        hintArrowId = null;
        actionVersion++;
        status = GameStatus.animating;
        notifyListeners();
        return evaluation;
    }
  }

  /// Commits the removal that [attemptMove] staged, after the UI has
  /// finished animating the arrow off the board.
  void finishAnimation() {
    if (status != GameStatus.animating || lastRemovedArrowId == null) return;
    board.removeArrow(lastRemovedArrowId!);
    movesSuccessful++;
    lastRemovedArrowId = null;
    status = board.allCleared ? GameStatus.levelCompleted : GameStatus.playing;
    notifyListeners();
  }

  /// Finds an arrow that is verifiably safe to remove right now, or null
  /// if the board is already clear. Because the exit-lane relation is
  /// monotonic (removing arrows only ever clears lanes, never blocks
  /// them), a solvable level always has at least one such arrow whenever
  /// arrows remain — so this never needs to search beyond one pass.
  String? findHint() {
    for (final arrow in board.activeArrows) {
      if (_exitChecker.isExitLaneClear(board, arrow)) {
        hintArrowId = arrow.id;
        notifyListeners();
        return arrow.id;
      }
    }
    return null;
  }

  void clearHint() {
    if (hintArrowId != null) {
      hintArrowId = null;
      notifyListeners();
    }
  }

  void undo() {
    if (!canUndo) return;
    final snap = _undoStack.removeLast();
    for (final id in board.allArrowIds) {
      final shouldBeActive = snap.activeIds.contains(id);
      if (shouldBeActive && !board.isActive(id)) {
        board.restoreArrow(id);
      } else if (!shouldBeActive && board.isActive(id)) {
        board.removeArrow(id);
      }
    }
    hearts = snap.hearts;
    movesSuccessful = snap.moves;
    failedAttempts = snap.failedAttempts;
    lastRemovedArrowId = null;
    lastBlockedArrowId = null;
    hintArrowId = null;
    status = GameStatus.playing;
    notifyListeners();
  }

  void reset() {
    board = BoardState.fromLevel(level);
    hearts = kStartingHearts;
    movesSuccessful = 0;
    failedAttempts = 0;
    lastRemovedArrowId = null;
    lastBlockedArrowId = null;
    hintArrowId = null;
    _undoStack.clear();
    if (timedMode && level.suggestedTimeLimitSeconds != null) {
      timeRemaining = Duration(seconds: level.suggestedTimeLimitSeconds!);
    }
    status = GameStatus.ready;
    notifyListeners();
  }

  /// Rehydrates the board from a persisted mid-level snapshot (app was
  /// closed and reopened). Must be called before [start]. Deliberately
  /// does not restore undo history — undo only reaches back within the
  /// current play session, which is an acceptable, documented limit.
  void restoreFrom({
    required List<String> removedArrowIds,
    required int hearts,
    required int moves,
    required int failedAttempts,
  }) {
    for (final id in removedArrowIds) {
      board.removeArrow(id);
    }
    this.hearts = hearts;
    movesSuccessful = moves;
    this.failedAttempts = failedAttempts;
    _undoStack.clear();
    status = board.allCleared ? GameStatus.levelCompleted : GameStatus.ready;
    notifyListeners();
  }

  void pause() {
    if (status == GameStatus.playing) {
      status = GameStatus.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (status == GameStatus.paused) {
      status = GameStatus.playing;
      notifyListeners();
    }
  }

  /// Advances the optional countdown timer. No-op unless [timedMode] and
  /// still playing.
  void tickTimer(Duration elapsed) {
    if (!timedMode || timeRemaining == null || status != GameStatus.playing) {
      return;
    }
    final next = timeRemaining! - elapsed;
    if (next <= Duration.zero) {
      timeRemaining = Duration.zero;
      status = GameStatus.timeExpired;
    } else {
      timeRemaining = next;
    }
    notifyListeners();
  }

  /// Stars earned if the level were completed right now, 1-3, driven by
  /// hearts remaining (documented star rule: fewer mistakes -> more
  /// stars).
  int get projectedStars => hearts.clamp(1, 3);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/grid_point.dart';
import '../engine/game_state.dart';
import 'arrow_palette.dart';
import 'board_painter.dart';

/// The interactive puzzle canvas: renders the board, handles tap-to-move
/// input, and drives the escape / blocked-shake / hint-pulse animations
/// off a single [GameStateController]. Reduced-motion shortens or skips
/// animation duration but never changes game logic.
class PuzzleBoardWidget extends StatefulWidget {
  final GameStateController controller;
  final ArrowPalette palette;
  final bool reducedMotion;
  final bool hapticsEnabled;
  final VoidCallback? onBlockedMove;

  const PuzzleBoardWidget({
    super.key,
    required this.controller,
    this.palette = ArrowPalette.outgridDefault,
    this.reducedMotion = false,
    this.hapticsEnabled = true,
    this.onBlockedMove,
  });

  @override
  State<PuzzleBoardWidget> createState() => _PuzzleBoardWidgetState();
}

class _PuzzleBoardWidgetState extends State<PuzzleBoardWidget>
    with TickerProviderStateMixin {
  late final AnimationController _exitAnim;
  late final AnimationController _shakeAnim;
  late final AnimationController _hintAnim;

  String? _animatingArrowId;
  String? _shakingArrowId;
  int _lastHandledVersion = 0;

  @override
  void initState() {
    super.initState();
    _exitAnim = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 300),
    );
    _shakeAnim = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? const Duration(milliseconds: 80)
          : const Duration(milliseconds: 260),
    );
    _hintAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    widget.controller.addListener(_onControllerChanged);
    _lastHandledVersion = widget.controller.actionVersion;
  }

  @override
  void didUpdateWidget(covariant PuzzleBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastHandledVersion = widget.controller.actionVersion;
      _animatingArrowId = null;
      _shakingArrowId = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _exitAnim.dispose();
    _shakeAnim.dispose();
    _hintAnim.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final c = widget.controller;
    if (c.actionVersion != _lastHandledVersion) {
      _lastHandledVersion = c.actionVersion;
      if (c.status == GameStatus.animating && c.lastRemovedArrowId != null) {
        _playExit(c.lastRemovedArrowId!);
      } else if (c.lastBlockedArrowId != null) {
        _playShake(c.lastBlockedArrowId!);
      }
    }
    if (mounted) setState(() {});
  }

  void _playExit(String arrowId) {
    if (widget.hapticsEnabled) HapticFeedback.lightImpact();
    setState(() => _animatingArrowId = arrowId);
    _exitAnim
      ..reset()
      ..forward().whenComplete(() {
        widget.controller.finishAnimation();
        if (mounted) setState(() => _animatingArrowId = null);
      });
  }

  void _playShake(String arrowId) {
    if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
    widget.onBlockedMove?.call();
    setState(() => _shakingArrowId = arrowId);
    _shakeAnim
      ..reset()
      ..forward().whenComplete(() {
        if (mounted) setState(() => _shakingArrowId = null);
      });
  }

  void _handleTapUp(TapUpDetails details, double cellSize) {
    final c = widget.controller;
    if (!c.acceptsInput) return;
    final col = (details.localPosition.dx / cellSize).floor();
    final row = (details.localPosition.dy / cellSize).floor();
    if (row < 0 || row >= c.board.rows || col < 0 || col >= c.board.cols) {
      return;
    }
    final arrowId = c.board.occupantAt(GridPoint(row, col));
    if (arrowId == null) return;
    c.attemptMove(arrowId);
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.controller.board;
    return LayoutBuilder(builder: (context, constraints) {
      final maxDim = board.rows > board.cols ? board.rows : board.cols;
      final cellSize =
          (constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight) /
              maxDim;
      final boardWidth = cellSize * board.cols;
      final boardHeight = cellSize * board.rows;

      return Center(
        child: SizedBox(
          width: boardWidth,
          height: boardHeight,
          child: ClipRect(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _handleTapUp(d, cellSize),
              child: AnimatedBuilder(
                animation: Listenable.merge([_exitAnim, _shakeAnim, _hintAnim]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(boardWidth, boardHeight),
                    painter: BoardPainter(
                      board: board,
                      palette: widget.palette,
                      cellSize: cellSize,
                      animatingArrowId: _animatingArrowId,
                      animProgress: _exitAnim.value,
                      shakingArrowId: _shakingArrowId,
                      shakeProgress: _shakeAnim.value,
                      hintArrowId: widget.controller.hintArrowId,
                      hintPulse: _hintAnim.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}

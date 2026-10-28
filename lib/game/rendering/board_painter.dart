import 'package:flutter/material.dart';

import '../../models/direction.dart';
import '../../models/grid_point.dart';
import '../engine/board_model.dart';
import 'arrow_painter.dart';
import 'arrow_palette.dart';

/// Renders every active arrow on the board, plus the in-flight escape
/// animation, blocked-move shake, and hint pulse. Designed to be cheap to
/// repaint every animation frame even on dense (hundreds-of-arrow)
/// boards — each arrow is a handful of stroked line segments.
class BoardPainter extends CustomPainter {
  final BoardState board;
  final ArrowPalette palette;
  final double cellSize;
  final String? animatingArrowId;
  final double animProgress; // 0..1, eased
  final String? shakingArrowId;
  final double shakeProgress; // 0..1
  final String? hintArrowId;
  final double hintPulse; // 0..1, loops

  BoardPainter({
    required this.board,
    required this.palette,
    required this.cellSize,
    this.animatingArrowId,
    this.animProgress = 0,
    this.shakingArrowId,
    this.shakeProgress = 0,
    this.hintArrowId,
    this.hintPulse = 0,
  });

  Offset _cellCenter(GridPoint p) =>
      Offset((p.col + 0.5) * cellSize, (p.row + 0.5) * cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Clean white canvas, no grid dots — matches the reference's flat
    // background with the arrows doing all the visual work.

    // Thin crisp lines, not thick rounded pipes — matches the reference
    // "circuit maze" style rather than a chunky tube look.
    final strokeWidth = (cellSize * 0.22).clamp(1.2, 10.0);

    for (final arrow in board.activeArrows) {
      var points = arrow.cells.map(_cellCenter).toList();
      var opacity = 1.0;
      var headScale = 1.0;

      if (arrow.id == animatingArrowId) {
        final travel =
            (board.rows + board.cols + 4) * cellSize * animProgress;
        final offset =
            Offset(arrow.direction.dCol * travel, arrow.direction.dRow * travel);
        points = points.map((p) => p + offset).toList();
        opacity = (1 - animProgress * 0.15).clamp(0.0, 1.0);
      } else if (arrow.id == shakingArrowId) {
        final jitter = _shakeOffset(shakeProgress, arrow.direction.isHorizontal);
        points = points.map((p) => p + jitter).toList();
      }

      if (arrow.id == hintArrowId) {
        final haloPaint = Paint()
          ..color = palette[arrow.color].withValues(alpha: 0.25 * (1 - hintPulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 10 * hintPulse
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, haloPaint);
        headScale = 1.0 + 0.15 * (1 - hintPulse);
      }

      paintArrowPath(
        canvas,
        points,
        arrow.direction,
        palette[arrow.color],
        strokeWidth,
        headScale: headScale,
        opacity: opacity,
      );
    }
  }

  Offset _shakeOffset(double t, bool arrowIsHorizontal) {
    // Shake perpendicular to the arrow's own axis so it reads as "this
    // specific piece is stuck", not a generic screen wobble.
    final wave = (t * 4 * 3.14159).remainder(2 * 3.14159);
    final mag = 5.0 * (1 - t);
    final s = mag * (wave < 3.14159 ? 1 : -1) * (1 - t);
    return arrowIsHorizontal ? Offset(0, s) : Offset(s, 0);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.animatingArrowId != animatingArrowId ||
        oldDelegate.shakeProgress != shakeProgress ||
        oldDelegate.shakingArrowId != shakingArrowId ||
        oldDelegate.hintArrowId != hintArrowId ||
        oldDelegate.hintPulse != hintPulse;
  }
}

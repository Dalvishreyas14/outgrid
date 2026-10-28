import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/direction.dart';

/// Draws one arrow as a rounded polyline with an arrowhead at the last
/// point, pointing in [direction]. Pure drawing helper — no model
/// knowledge beyond already-resolved screen-space points, so it's reused
/// for normal, animating, hinted, and shaking draws alike.
void paintArrowPath(
  Canvas canvas,
  List<Offset> points,
  GridDirection direction,
  Color color,
  double strokeWidth, {
  double headScale = 1.0,
  double opacity = 1.0,
}) {
  if (points.isEmpty) return;
  // Sharp right-angle corners and flat caps, not rounded pipes — gives
  // the thin "circuit maze" look rather than a thick rounded tube.
  final paint = Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter;

  if (points.length == 1) {
    // No line body to draw — the arrowhead glyph alone reads cleanly as
    // a minimal arrow, matching how short pieces look in dense boards.
  } else {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  _paintArrowhead(canvas, points.last, direction, color, strokeWidth,
      headScale: headScale, opacity: opacity);
}

void _paintArrowhead(
  Canvas canvas,
  Offset tip,
  GridDirection direction,
  Color color,
  double strokeWidth, {
  double headScale = 1.0,
  double opacity = 1.0,
}) {
  final paint = Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.fill;

  final size = strokeWidth * 2.1 * headScale;
  final angle = switch (direction) {
    GridDirection.right => 0.0,
    GridDirection.down => math.pi / 2,
    GridDirection.left => math.pi,
    GridDirection.up => -math.pi / 2,
  };

  // Triangle pointing along +x before rotation, apex at `tip`. Narrower
  // and longer than a default triangle — reads as a crisp chevron at
  // small sizes instead of a fat arrowhead blob.
  final back = size * 1.05;
  final half = size * 0.5;
  final p0 = Offset(0, 0);
  final p1 = Offset(-back, -half);
  final p2 = Offset(-back, half);

  final cosA = math.cos(angle), sinA = math.sin(angle);
  Offset rotate(Offset p) =>
      Offset(p.dx * cosA - p.dy * sinA, p.dx * sinA + p.dy * cosA) + tip;

  final path = Path()
    ..moveTo(rotate(p0).dx, rotate(p0).dy)
    ..lineTo(rotate(p1).dx, rotate(p1).dy)
    ..lineTo(rotate(p2).dx, rotate(p2).dy)
    ..close();
  canvas.drawPath(path, paint);
}

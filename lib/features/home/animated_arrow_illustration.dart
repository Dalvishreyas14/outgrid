import 'package:flutter/material.dart';

import '../../game/rendering/arrow_painter.dart';
import '../../models/direction.dart';

/// Small, purely decorative looping animation for the home screen: a
/// handful of arrows sliding across and looping, echoing the core
/// mechanic. Non-interactive. Freezes on a static frame when
/// [reducedMotion] is set.
class AnimatedArrowIllustration extends StatefulWidget {
  final bool reducedMotion;
  final double height;

  const AnimatedArrowIllustration({
    super.key,
    this.reducedMotion = false,
    this.height = 120,
  });

  @override
  State<AnimatedArrowIllustration> createState() =>
      _AnimatedArrowIllustrationState();
}

class _AnimatedArrowIllustrationState extends State<AnimatedArrowIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _specs = [
    (
      color: Color(0xFF7950F2),
      direction: GridDirection.right,
      rowFrac: 0.2,
      delay: 0.0,
    ),
    (
      color: Color(0xFF2864E8),
      direction: GridDirection.right,
      rowFrac: 0.45,
      delay: 0.25,
    ),
    (
      color: Color(0xFF0AA782),
      direction: GridDirection.right,
      rowFrac: 0.7,
      delay: 0.5,
    ),
    (
      color: Color(0xFFF28C18),
      direction: GridDirection.right,
      rowFrac: 0.95,
      delay: 0.75,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (!widget.reducedMotion) {
      _controller.repeat();
    } else {
      _controller.value = 0.3;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ArrowStreamPainter(_controller.value, _specs),
        ),
      ),
    );
  }
}

typedef _ArrowSpec = ({
  Color color,
  GridDirection direction,
  double rowFrac,
  double delay,
});

class _ArrowStreamPainter extends CustomPainter {
  final double t;
  final List<_ArrowSpec> specs;

  _ArrowStreamPainter(this.t, this.specs);

  @override
  void paint(Canvas canvas, Size size) {
    for (final spec in specs) {
      final localT = ((t + spec.delay) % 1.0);
      final startX = -size.width * 0.25;
      final endX = size.width * 1.25;
      final x = startX + (endX - startX) * localT;
      final y = size.height * spec.rowFrac;
      final opacity = (1 - (localT - 0.5).abs() * 1.6).clamp(0.15, 1.0);
      paintArrowPath(
        canvas,
        [Offset(x - 36, y), Offset(x, y)],
        spec.direction,
        spec.color,
        8,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowStreamPainter oldDelegate) =>
      oldDelegate.t != t;
}

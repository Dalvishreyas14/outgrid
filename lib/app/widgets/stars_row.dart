import 'package:flutter/material.dart';

class StarsRow extends StatelessWidget {
  final int stars;
  final int maxStars;
  final double size;
  final Color color;

  const StarsRow({
    super.key,
    required this.stars,
    this.maxStars = 3,
    this.size = 18,
    this.color = const Color(0xFFF28C18),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (i) {
        final filled = i < stars;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled ? color : color.withValues(alpha: 0.3),
          size: size,
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';

import '../app_theme.dart';

class HeartsRow extends StatelessWidget {
  final int hearts;
  final int maxHearts;
  final double size;

  const HeartsRow({
    super.key,
    required this.hearts,
    this.maxHearts = 3,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxHearts, (i) {
        final filled = i < hearts;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            color: filled ? AppColors.red : AppColors.textSecondary.withValues(alpha: 0.4),
            size: size,
          ),
        );
      }),
    );
  }
}

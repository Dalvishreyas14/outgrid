import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/widgets/stars_row.dart';
import '../../models/player_progress.dart';

class LevelCell extends StatelessWidget {
  final int levelInChapter;
  final bool unlocked;
  final bool isCurrent;
  final LevelResult? result;
  final Color accent;
  final VoidCallback? onTap;

  const LevelCell({
    super.key,
    required this.levelInChapter,
    required this.unlocked,
    required this.isCurrent,
    required this.result,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = result?.completed == true;
    return Material(
      color: completed
          ? accent.withValues(alpha: 0.14)
          : unlocked
              ? Theme.of(context).cardTheme.color
              : AppColors.textSecondary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: unlocked ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isCurrent ? Border.all(color: accent, width: 2) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked)
                Icon(Icons.lock_outline,
                    size: 16, color: AppColors.textSecondary.withValues(alpha: 0.6))
              else
                Text(
                  '$levelInChapter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: completed ? accent : null,
                      ),
                ),
              if (completed) ...[
                const SizedBox(height: 2),
                StarsRow(stars: result!.stars, size: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

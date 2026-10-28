import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/constants/chapters.dart';

class ChapterCard extends StatelessWidget {
  final ChapterDef chapter;
  final bool unlocked;
  final double completionFraction;
  final VoidCallback? onTap;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.unlocked,
    required this.completionFraction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(0xFF000000 | chapter.accentColor);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unlocked ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: unlocked ? 0.15 : 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${chapter.index}',
                    style: TextStyle(
                      color: unlocked ? accent : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chapter.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(chapter.tagline, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: unlocked ? completionFraction : 0,
                        minHeight: 6,
                        backgroundColor: AppColors.textSecondary.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                unlocked ? Icons.chevron_right : Icons.lock_outline,
                color: unlocked ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

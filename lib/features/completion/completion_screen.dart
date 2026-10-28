import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/widgets/stars_row.dart';
import '../../core/constants/chapters.dart';
import '../../game/engine/board_model.dart';
import '../../game/rendering/arrow_palette.dart';
import '../../game/rendering/board_painter.dart';
import '../../models/level_model.dart';
import '../gameplay/gameplay_screen.dart';

class CompletionScreen extends StatelessWidget {
  final LevelModel level;
  final int stars;
  final int moves;
  final int heartsRemaining;
  final bool isDailyChallenge;

  const CompletionScreen({
    super.key,
    required this.level,
    required this.stars,
    required this.moves,
    required this.heartsRemaining,
    this.isDailyChallenge = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasNext = level.globalIndex < ChapterDef.totalLevels;
    final board = BoardState.fromLevel(level);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.green, size: 64),
              const SizedBox(height: 12),
              Text(
                isDailyChallenge ? 'Daily Challenge Complete!' : 'Level Complete!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${level.title} · Chapter ${level.chapterIndex}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              StarsRow(stars: stars, size: 36),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final cellSize = constraints.maxWidth /
                        (level.rows > level.cols ? level.rows : level.cols);
                    return CustomPaint(
                      painter: BoardPainter(
                        board: board,
                        palette: ArrowPalette.outgridDefault,
                        cellSize: cellSize,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _summaryStat(context, '$moves', 'Moves'),
                  const SizedBox(width: 28),
                  _summaryStat(context, '$heartsRemaining', 'Hearts left'),
                ],
              ),
              const SizedBox(height: 26),
              if (!isDailyChallenge && hasNext)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameplayScreen(globalIndex: level.globalIndex + 1),
                    ),
                  ),
                  child: const Text('Next Level'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => GameplayScreen(
                      globalIndex: level.globalIndex,
                      isDailyChallenge: isDailyChallenge,
                    ),
                  ),
                ),
                child: const Text('Replay'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

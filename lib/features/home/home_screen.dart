import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/constants/chapters.dart';
import '../../core/storage/progress_controller.dart';
import '../../core/storage/settings_controller.dart';
import '../daily_challenge/daily_challenge_screen.dart';
import '../gameplay/gameplay_screen.dart';
import '../level_selection/level_selection_screen.dart';
import '../settings/settings_screen.dart';
import 'animated_arrow_illustration.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressController>();
    final settings = context.watch<SettingsController>().settings;
    final hasActiveLevel = progress.progress.activeLevel != null;
    final totalCompleted =
        progress.progress.results.values.where((r) => r.completed).length;
    final totalStars = progress.progress.results.values
        .fold<int>(0, (sum, r) => sum + (r.completed ? r.stars : 0));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ),
              const SizedBox(height: 8),
              Image.asset('assets/branding/outgrid_logo.png', height: 96),
              const SizedBox(height: 8),
              Text(
                'THINK. TRACE. ESCAPE.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 2.2,
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              AnimatedArrowIllustration(reducedMotion: settings.reducedMotion),
              const SizedBox(height: 16),
              _ProgressSummaryCard(
                completed: totalCompleted,
                totalStars: totalStars,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _playOrContinue(context, progress),
                child: Text(hasActiveLevel ? 'Continue' : 'Play'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LevelSelectionScreen())),
                child: const Text('Level Selection'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DailyChallengeScreen())),
                child: const Text('Daily Challenge'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _playOrContinue(BuildContext context, ProgressController progress) {
    final globalIndex = progress.nextPlayableGlobalIndex;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameplayScreen(globalIndex: globalIndex),
    ));
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  final int completed;
  final int totalStars;

  const _ProgressSummaryCard({required this.completed, required this.totalStars});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _stat(context, '$completed / ${ChapterDef.totalLevels}', 'Levels solved'),
            ),
            Container(width: 1, height: 36, color: AppColors.textSecondary.withValues(alpha: 0.15)),
            Expanded(
              child: _stat(context, '$totalStars', 'Stars earned'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/storage/progress_controller.dart';
import '../../core/utilities/daily_challenge.dart';
import '../../game/data/level_repository.dart';
import '../../models/level_model.dart';
import '../gameplay/gameplay_screen.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  LevelModel? _level;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final globalIndex = dailyChallengeGlobalIndex(DateTime.now());
    final level = await context.read<LevelRepository>().levelByGlobalIndex(globalIndex);
    if (mounted) setState(() => _level = level);
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressController>();
    final claimed = progress.isDailyChallengeClaimed(DateTime.now());
    final level = _level;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: level == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.today_rounded, size: 56, color: AppColors.purple),
                  const SizedBox(height: 16),
                  Text(_formattedDate(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    "Today's puzzle: ${level.title}",
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${level.rows}x${level.cols} board · ${level.arrows.length} arrows',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (claimed)
                    Chip(
                      label: const Text('Completed today'),
                      backgroundColor: AppColors.green.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(color: AppColors.green),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GameplayScreen(
                        globalIndex: level.globalIndex,
                        isDailyChallenge: true,
                      ),
                    )),
                    child: Text(claimed ? 'Play Again' : 'Play'),
                  ),
                ],
              ),
            ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

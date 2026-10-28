import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/chapters.dart';
import '../../core/storage/progress_controller.dart';
import '../chapters/chapter_card.dart';
import '../chapters/chapter_levels_screen.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Level Selection')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kChapters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final chapter = kChapters[i];
          final unlocked = progress.isUnlocked(chapter.firstGlobalIndex);
          return ChapterCard(
            chapter: chapter,
            unlocked: unlocked,
            completionFraction: progress.chapterCompletionFraction(chapter.index),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChapterLevelsScreen(chapter: chapter),
            )),
          );
        },
      ),
    );
  }
}

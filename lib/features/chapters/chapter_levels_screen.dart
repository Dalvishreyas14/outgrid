import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/chapters.dart';
import '../../core/storage/progress_controller.dart';
import '../gameplay/gameplay_screen.dart';
import 'level_cell.dart';

class ChapterLevelsScreen extends StatefulWidget {
  final ChapterDef chapter;
  const ChapterLevelsScreen({super.key, required this.chapter});

  @override
  State<ChapterLevelsScreen> createState() => _ChapterLevelsScreenState();
}

class _ChapterLevelsScreenState extends State<ChapterLevelsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    final progress = context.read<ProgressController>();
    final current = progress.nextPlayableGlobalIndex;
    if (current < widget.chapter.firstGlobalIndex || current > widget.chapter.lastGlobalIndex) {
      return;
    }
    final levelInChapter = current - widget.chapter.firstGlobalIndex + 1;
    final row = (levelInChapter - 1) ~/ 5;
    final targetOffset = (row * 76.0 - 150).clamp(0.0, double.infinity);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressController>();
    final accent = Color(0xFF000000 | widget.chapter.accentColor);

    return Scaffold(
      appBar: AppBar(title: Text(widget.chapter.name)),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: ChapterDef.levelsPerChapter,
        itemBuilder: (context, i) {
          final levelInChapter = i + 1;
          final globalIndex = widget.chapter.firstGlobalIndex + i;
          final levelId =
              'c${widget.chapter.index.toString().padLeft(2, '0')}_l${levelInChapter.toString().padLeft(3, '0')}';
          final unlocked = progress.isUnlocked(globalIndex);
          final isCurrent = progress.nextPlayableGlobalIndex == globalIndex;
          return LevelCell(
            levelInChapter: levelInChapter,
            unlocked: unlocked,
            isCurrent: isCurrent,
            result: progress.resultFor(levelId),
            accent: accent,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameplayScreen(globalIndex: globalIndex),
            )),
          );
        },
      ),
    );
  }
}

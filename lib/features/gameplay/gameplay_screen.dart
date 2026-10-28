import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../app/widgets/hearts_row.dart';
import '../../core/storage/progress_controller.dart';
import '../../core/storage/settings_controller.dart';
import '../../core/utilities/audio_service.dart';
import '../../game/data/level_repository.dart';
import '../../game/engine/game_state.dart';
import '../../game/rendering/arrow_palette.dart';
import '../../game/rendering/puzzle_board_widget.dart';
import '../../models/level_model.dart';
import '../../models/player_progress.dart';
import '../completion/completion_screen.dart';

class GameplayScreen extends StatefulWidget {
  final int globalIndex;
  final bool isDailyChallenge;

  const GameplayScreen({
    super.key,
    required this.globalIndex,
    this.isDailyChallenge = false,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  LevelModel? _level;
  GameStateController? _controller;
  Timer? _timerTicker;
  Timer? _hintAutoClear;
  bool _completionHandled = false;
  String? _loadError;
  late final AudioService _audio;
  String? _lastRemovedSeen;
  String? _lastBlockedSeen;

  @override
  void initState() {
    super.initState();
    _audio = AudioService(
      soundEnabled: () =>
          context.mounted ? context.read<SettingsController>().settings.soundEnabled : false,
    );
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<LevelRepository>();
      final progress = context.read<ProgressController>();
      final settings = context.read<SettingsController>().settings;
      final level = await repo.levelByGlobalIndex(widget.globalIndex);

      final controller = GameStateController(
        level: level,
        timedMode: settings.timedModeEnabled && !widget.isDailyChallenge,
      );

      final saved = progress.progress.activeLevel;
      if (saved != null && saved.levelId == level.id) {
        controller.restoreFrom(
          removedArrowIds: saved.removedArrowIds,
          hearts: saved.hearts,
          moves: saved.moves,
          failedAttempts: saved.failedAttempts,
        );
      }
      if (controller.timedMode) {
        _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          controller.tickTimer(const Duration(seconds: 1));
        });
      }

      // Fields must be assigned before start()/addListener() can fire —
      // _onControllerChanged dereferences _level, and start() triggers a
      // synchronous notifyListeners() call.
      setState(() {
        _level = level;
        _controller = controller;
      });
      controller.addListener(_onControllerChanged);
      controller.start();
    } catch (e) {
      setState(() => _loadError = e.toString());
    }
  }

  void _onControllerChanged() {
    final c = _controller!;
    if (c.lastRemovedArrowId != null && c.lastRemovedArrowId != _lastRemovedSeen) {
      _lastRemovedSeen = c.lastRemovedArrowId;
      _audio.arrowEscape();
    }
    if (c.lastBlockedArrowId != null && c.lastBlockedArrowId != _lastBlockedSeen) {
      _lastBlockedSeen = c.lastBlockedArrowId;
      _audio.blockedMove();
    }
    if (c.status == GameStatus.levelCompleted && !_completionHandled) {
      _completionHandled = true;
      _audio.levelComplete();
      _handleCompletion();
      return;
    }
    if (c.status == GameStatus.playing) {
      _persistActiveState();
    }
    setState(() {});
  }

  Future<void> _persistActiveState() async {
    if (!mounted) return;
    final c = _controller!;
    final progress = context.read<ProgressController>();
    await progress.saveActiveLevel(ActiveLevelState(
      levelId: _level!.id,
      globalIndex: _level!.globalIndex,
      removedArrowIds: _level!.arrows
          .map((a) => a.id)
          .where((id) => !c.board.isActive(id))
          .toList(),
      hearts: c.hearts,
      moves: c.movesSuccessful,
      failedAttempts: c.failedAttempts,
    ));
  }

  Future<void> _handleCompletion() async {
    final c = _controller!;
    final level = _level!;
    final progress = context.read<ProgressController>();
    final stars = c.projectedStars;
    final moves = c.movesSuccessful;

    if (widget.isDailyChallenge) {
      await progress.recordDailyChallengeResult(
        level: level,
        stars: stars,
        moves: moves,
        date: DateTime.now(),
      );
    } else {
      await progress.completeLevel(level: level, stars: stars, moves: moves);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CompletionScreen(
        level: level,
        stars: stars,
        moves: moves,
        heartsRemaining: c.hearts,
        isDailyChallenge: widget.isDailyChallenge,
      ),
    ));
  }

  void _showHint() {
    final c = _controller!;
    _audio.hint();
    c.findHint();
    _hintAutoClear?.cancel();
    _hintAutoClear = Timer(const Duration(seconds: 3), () {
      _controller?.clearHint();
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _timerTicker?.cancel();
    _hintAutoClear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(body: Center(child: Text('Could not load level: $_loadError')));
    }
    final level = _level;
    final controller = _controller;
    if (level == null || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settings = context.watch<SettingsController>().settings;
    final palette = ArrowPalette.byName(settings.arrowPaletteName);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    _Header(level: level, controller: controller, onPause: () {
                      controller.pause();
                    }),
                    _StatsRow(controller: controller),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: PuzzleBoardWidget(
                          controller: controller,
                          palette: palette,
                          reducedMotion: settings.reducedMotion,
                          hapticsEnabled: settings.hapticsEnabled,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Tap an arrow with a clear exit lane to send it off the board.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BottomControls(
                      controller: controller,
                      onHint: _showHint,
                      onButtonTap: _audio.buttonTap,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                if (controller.status == GameStatus.paused)
                  _PausedOverlay(controller: controller),
                if (controller.status == GameStatus.outOfHearts ||
                    controller.status == GameStatus.timeExpired)
                  _FailureOverlay(
                    controller: controller,
                    timedOut: controller.status == GameStatus.timeExpired,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final LevelModel level;
  final GameStateController controller;
  final VoidCallback onPause;

  const _Header({required this.level, required this.controller, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Chapter ${level.chapterIndex} · Level ${level.levelInChapter}',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(level.title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline),
            onPressed: controller.status == GameStatus.playing ? onPause : null,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final GameStateController controller;
  const _StatsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HeartsRow(hearts: controller.hearts),
          _statChip(context, 'Moves', '${controller.movesSuccessful}'),
          _statChip(context, 'Left', '${controller.arrowsRemaining}/${controller.totalArrows}'),
          if (controller.timedMode && controller.timeRemaining != null)
            _statChip(context, 'Time', _format(controller.timeRemaining!)),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _statChip(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  final GameStateController controller;
  final VoidCallback onHint;
  final VoidCallback onButtonTap;

  const _BottomControls({
    required this.controller,
    required this.onHint,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ControlButton(
              icon: Icons.refresh,
              label: 'Reset',
              onPressed: controller.status == GameStatus.playing ||
                      controller.status == GameStatus.outOfHearts ||
                      controller.status == GameStatus.timeExpired
                  ? () {
                      onButtonTap();
                      controller.reset();
                      controller.start();
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.lightbulb_outline,
              label: 'Hint',
              onPressed: controller.status == GameStatus.playing ? onHint : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: controller.canUndo
                  ? () {
                      onButtonTap();
                      controller.undo();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ControlButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  final GameStateController controller;
  const _PausedOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      title: 'Paused',
      children: [
        ElevatedButton(onPressed: controller.resume, child: const Text('Resume')),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            controller.reset();
            controller.start();
          },
          child: const Text('Restart Level'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Return to Home'),
        ),
      ],
    );
  }
}

class _FailureOverlay extends StatelessWidget {
  final GameStateController controller;
  final bool timedOut;
  const _FailureOverlay({required this.controller, required this.timedOut});

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      title: timedOut ? "Time's Up" : 'Out of Hearts',
      subtitle: timedOut
          ? 'You ran out of time for this level.'
          : 'Too many blocked moves. Give it another go.',
      children: [
        ElevatedButton(
          onPressed: () {
            controller.reset();
            controller.start();
          },
          child: const Text('Try Again'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _OverlayScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _OverlayScaffold({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

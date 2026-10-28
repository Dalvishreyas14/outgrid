import 'package:flutter/foundation.dart';

import '../../models/level_model.dart';
import '../../models/player_progress.dart';
import '../constants/chapters.dart';
import 'progress_repository.dart';

/// Live, in-memory [PlayerProgress] shared across the app via Provider.
/// Owns unlock/star/resume logic so screens never touch raw save-file
/// shape directly.
class ProgressController extends ChangeNotifier {
  final ProgressRepository _repo;
  PlayerProgress progress = const PlayerProgress();
  bool isLoaded = false;

  ProgressController({ProgressRepository repo = const ProgressRepository()})
      : _repo = repo;

  Future<void> load() async {
    progress = await _repo.load();
    isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _repo.save(progress);

  bool isUnlocked(int globalIndex) => globalIndex <= progress.highestUnlockedLevel;

  LevelResult? resultFor(String levelId) => progress.results[levelId];

  /// Resumes a saved mid-level attempt if one exists, otherwise the next
  /// level the player hasn't beaten yet.
  int get nextPlayableGlobalIndex =>
      progress.activeLevel?.globalIndex ?? progress.highestUnlockedLevel;

  int completedCountInChapter(int chapterIndex) {
    final chapter = chapterByIndex(chapterIndex);
    var count = 0;
    for (var g = chapter.firstGlobalIndex; g <= chapter.lastGlobalIndex; g++) {
      final id =
          'c${chapterIndex.toString().padLeft(2, '0')}_l${(g - chapter.firstGlobalIndex + 1).toString().padLeft(3, '0')}';
      if (progress.results[id]?.completed == true) count++;
    }
    return count;
  }

  double chapterCompletionFraction(int chapterIndex) =>
      completedCountInChapter(chapterIndex) / ChapterDef.levelsPerChapter;

  /// Records a level win: merges the best-ever result, unlocks the next
  /// level, clears any in-progress snapshot for this level, and persists
  /// before returning (so the caller can safely navigate away).
  Future<void> completeLevel({
    required LevelModel level,
    required int stars,
    required int moves,
  }) async {
    final newResult = LevelResult(stars: stars, bestMoves: moves, completed: true);
    final existing = progress.results[level.id];
    final merged = existing == null ? newResult : existing.mergeBetter(newResult);

    final results = Map<String, LevelResult>.from(progress.results);
    results[level.id] = merged;

    final nextUnlock = level.globalIndex + 1 <= ChapterDef.totalLevels
        ? level.globalIndex + 1
        : progress.highestUnlockedLevel;

    final clearActive = progress.activeLevel?.levelId == level.id;
    progress = progress.copyWith(
      results: results,
      highestUnlockedLevel: nextUnlock > progress.highestUnlockedLevel
          ? nextUnlock
          : progress.highestUnlockedLevel,
      clearActiveLevel: clearActive,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> saveActiveLevel(ActiveLevelState state) async {
    progress = progress.copyWith(activeLevel: state);
    notifyListeners();
    await _persist();
  }

  Future<void> clearActiveLevel() async {
    if (progress.activeLevel == null) return;
    progress = progress.copyWith(clearActiveLevel: true);
    notifyListeners();
    await _persist();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool isDailyChallengeClaimed(DateTime date) =>
      progress.dailyChallengeClaimedDates[_dateKey(date)] == true;

  /// Records a Daily Challenge win. Updates the level's best-ever result
  /// (so stars/best-moves stay meaningful even for out-of-order plays)
  /// but deliberately does NOT advance [PlayerProgress.highestUnlockedLevel]
  /// — a daily pick can be from a chapter the player hasn't reached yet,
  /// and playing it must not let them skip ahead in the main campaign.
  Future<void> recordDailyChallengeResult({
    required LevelModel level,
    required int stars,
    required int moves,
    required DateTime date,
  }) async {
    final newResult = LevelResult(stars: stars, bestMoves: moves, completed: true);
    final existing = progress.results[level.id];
    final merged = existing == null ? newResult : existing.mergeBetter(newResult);
    final results = Map<String, LevelResult>.from(progress.results)
      ..[level.id] = merged;
    final claimed = Map<String, bool>.from(progress.dailyChallengeClaimedDates)
      ..[_dateKey(date)] = true;

    progress = progress.copyWith(
      results: results,
      dailyChallengeClaimedDates: claimed,
    );
    notifyListeners();
    await _persist();
  }
}

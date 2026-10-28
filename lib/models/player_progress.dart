/// Per-level best result, persisted locally.
class LevelResult {
  final int stars; // 1..3
  final int bestMoves;
  final bool completed;

  const LevelResult({
    required this.stars,
    required this.bestMoves,
    required this.completed,
  });

  LevelResult mergeBetter(LevelResult other) {
    if (!completed) return other;
    if (!other.completed) return this;
    if (other.stars != stars) {
      return other.stars > stars ? other : this;
    }
    return other.bestMoves < bestMoves ? other : this;
  }

  Map<String, dynamic> toJson() =>
      {'stars': stars, 'bestMoves': bestMoves, 'completed': completed};

  factory LevelResult.fromJson(Map<String, dynamic> json) => LevelResult(
        stars: json['stars'] as int? ?? 0,
        bestMoves: json['bestMoves'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
      );
}

/// Snapshot of mid-level play, persisted so the app can resume a level
/// exactly where the player left off (not just restart it).
class ActiveLevelState {
  final String levelId;
  final int globalIndex;
  final List<String> removedArrowIds;
  final int hearts;
  final int moves;
  final int failedAttempts;

  const ActiveLevelState({
    required this.levelId,
    required this.globalIndex,
    required this.removedArrowIds,
    required this.hearts,
    required this.moves,
    required this.failedAttempts,
  });

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'globalIndex': globalIndex,
        'removed': removedArrowIds,
        'hearts': hearts,
        'moves': moves,
        'failed': failedAttempts,
      };

  factory ActiveLevelState.fromJson(Map<String, dynamic> json) =>
      ActiveLevelState(
        levelId: json['levelId'] as String,
        globalIndex: json['globalIndex'] as int,
        removedArrowIds: (json['removed'] as List).cast<String>(),
        hearts: json['hearts'] as int,
        moves: json['moves'] as int,
        failedAttempts: json['failed'] as int,
      );
}

/// Versioned, locally persisted player save. Unknown/missing fields must
/// always resolve to safe defaults so older saves keep loading after an
/// app update.
class PlayerProgress {
  static const int currentSaveVersion = 1;

  final int saveVersion;
  final int highestUnlockedLevel; // global index, 1..500
  final Map<String, LevelResult> results; // levelId -> result
  final ActiveLevelState? activeLevel;
  final Set<String> unlockedPaletteNames;
  final Map<String, bool> dailyChallengeClaimedDates; // yyyy-mm-dd -> claimed

  const PlayerProgress({
    this.saveVersion = currentSaveVersion,
    this.highestUnlockedLevel = 1,
    this.results = const {},
    this.activeLevel,
    this.unlockedPaletteNames = const {'OUTGRID Classic'},
    this.dailyChallengeClaimedDates = const {},
  });

  PlayerProgress copyWith({
    int? highestUnlockedLevel,
    Map<String, LevelResult>? results,
    ActiveLevelState? activeLevel,
    bool clearActiveLevel = false,
    Set<String>? unlockedPaletteNames,
    Map<String, bool>? dailyChallengeClaimedDates,
  }) {
    return PlayerProgress(
      saveVersion: currentSaveVersion,
      highestUnlockedLevel:
          highestUnlockedLevel ?? this.highestUnlockedLevel,
      results: results ?? this.results,
      activeLevel: clearActiveLevel ? null : (activeLevel ?? this.activeLevel),
      unlockedPaletteNames: unlockedPaletteNames ?? this.unlockedPaletteNames,
      dailyChallengeClaimedDates:
          dailyChallengeClaimedDates ?? this.dailyChallengeClaimedDates,
    );
  }

  Map<String, dynamic> toJson() => {
        'saveVersion': saveVersion,
        'highestUnlockedLevel': highestUnlockedLevel,
        'results': results.map((k, v) => MapEntry(k, v.toJson())),
        'activeLevel': activeLevel?.toJson(),
        'unlockedPalettes': unlockedPaletteNames.toList(),
        'dailyClaimed': dailyChallengeClaimedDates,
      };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    final version = json['saveVersion'] as int? ?? 1;
    final rawResults = (json['results'] as Map?)?.cast<String, dynamic>() ?? {};
    return PlayerProgress(
      saveVersion: version,
      highestUnlockedLevel: json['highestUnlockedLevel'] as int? ?? 1,
      results: rawResults.map(
        (k, v) => MapEntry(k, LevelResult.fromJson((v as Map).cast<String, dynamic>())),
      ),
      activeLevel: json['activeLevel'] != null
          ? ActiveLevelState.fromJson(
              (json['activeLevel'] as Map).cast<String, dynamic>())
          : null,
      unlockedPaletteNames:
          (json['unlockedPalettes'] as List?)?.cast<String>().toSet() ??
              {'OUTGRID Classic'},
      dailyChallengeClaimedDates:
          (json['dailyClaimed'] as Map?)?.cast<String, bool>() ?? const {},
    );
  }
}

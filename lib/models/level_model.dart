import 'arrow_path.dart';

/// Pattern family groups used by the generator and shown in level select
/// metadata / QA reports. Grouped by the families required in the design
/// brief (geometric / animal / object / abstract).
enum PatternFamily {
  circle,
  square,
  diamond,
  triangle,
  hexagon,
  octagon,
  star,
  heart,
  spiral,
  ring,
  concentric,
  symmetricalGeometric,
  cat,
  fox,
  dog,
  rabbit,
  bird,
  butterfly,
  fish,
  turtle,
  elephant,
  owl,
  crown,
  rocket,
  house,
  tree,
  key,
  trophy,
  giftBox,
  guitar,
  lightningBolt,
  planet,
  shield,
  gameController,
  circularLoops,
  interlockingSpirals,
  branchingPaths,
  symmetricalMaze,
  wavePattern,
  layeredGeometric,
  denseArrowFormation,
  multipleClusters,
  negativeSpace,
  complexMosaic,
}

extension PatternFamilyX on PatternFamily {
  static PatternFamily fromName(String name) =>
      PatternFamily.values.firstWhere((p) => p.name == name);

  /// "symmetricalMaze" -> "Symmetrical Maze", for UI display and titles.
  String get readableName {
    final withSpaces = name.replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}

/// A fully validated, immutable puzzle definition as shipped in
/// assets/levels. One instance == one playable board.
class LevelModel {
  /// Stable id, e.g. "c03_l027".
  final String id;
  final int chapterIndex; // 1..10
  final int levelInChapter; // 1..50
  final int globalIndex; // 1..500
  final String title;
  final PatternFamily patternFamily;
  final int rows;
  final int cols;
  final List<ArrowPathDef> arrows;
  final int difficultyScore; // 1..100, from difficulty_analyzer
  final int? suggestedTimeLimitSeconds; // null => untimed by default
  final int schemaVersion;

  const LevelModel({
    required this.id,
    required this.chapterIndex,
    required this.levelInChapter,
    required this.globalIndex,
    required this.title,
    required this.patternFamily,
    required this.rows,
    required this.cols,
    required this.arrows,
    required this.difficultyScore,
    this.suggestedTimeLimitSeconds,
    this.schemaVersion = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter': chapterIndex,
        'levelInChapter': levelInChapter,
        'globalIndex': globalIndex,
        'title': title,
        'pattern': patternFamily.name,
        'rows': rows,
        'cols': cols,
        'difficulty': difficultyScore,
        'timeLimit': suggestedTimeLimitSeconds,
        'schemaVersion': schemaVersion,
        'arrows': arrows.map((a) => a.toJson()).toList(),
      };

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'] as String,
      chapterIndex: json['chapter'] as int,
      levelInChapter: json['levelInChapter'] as int,
      globalIndex: json['globalIndex'] as int,
      title: json['title'] as String,
      patternFamily: PatternFamilyX.fromName(json['pattern'] as String),
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      difficultyScore: json['difficulty'] as int,
      suggestedTimeLimitSeconds: json['timeLimit'] as int?,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      arrows: (json['arrows'] as List)
          .map((a) => ArrowPathDef.fromJson(a as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

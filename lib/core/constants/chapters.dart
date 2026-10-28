import '../../models/level_model.dart';

/// Static chapter metadata shared by the level generator and the level
/// selection / chapter UI. 10 chapters x 50 levels = 500 total, per the
/// design brief's difficulty-progression bands (mapped onto chapters
/// below) and required pattern-family coverage.
class ChapterDef {
  final int index; // 1..10
  final String name;
  final String tagline;
  final int accentColor; // 0xRRGGBB
  final List<PatternFamily> families;

  const ChapterDef({
    required this.index,
    required this.name,
    required this.tagline,
    required this.accentColor,
    required this.families,
  });

  static const int levelsPerChapter = 50;
  static const int totalChapters = 10;
  static const int totalLevels = levelsPerChapter * totalChapters;

  int get firstGlobalIndex => (index - 1) * levelsPerChapter + 1;
  int get lastGlobalIndex => index * levelsPerChapter;

  PatternFamily familyForLevel(int levelInChapter) =>
      families[(levelInChapter - 1) % families.length];
}

const List<ChapterDef> kChapters = [
  ChapterDef(
    index: 1,
    name: 'First Steps',
    tagline: 'Learn to read an exit lane',
    accentColor: 0x2864E8, // blue
    families: [
      PatternFamily.circle,
      PatternFamily.square,
      PatternFamily.diamond,
      PatternFamily.triangle,
    ],
  ),
  ChapterDef(
    index: 2,
    name: 'Color Trails',
    tagline: 'Follow the colors home',
    accentColor: 0x0AA782, // green
    families: [
      PatternFamily.ring,
      PatternFamily.concentric,
      PatternFamily.star,
      PatternFamily.heart,
      PatternFamily.symmetricalGeometric,
    ],
  ),
  ChapterDef(
    index: 3,
    name: 'Twisted Paths',
    tagline: 'Bends, loops, and dependencies',
    accentColor: 0x7950F2, // purple
    families: [
      PatternFamily.spiral,
      PatternFamily.circularLoops,
      PatternFamily.interlockingSpirals,
      PatternFamily.wavePattern,
    ],
  ),
  ChapterDef(
    index: 4,
    name: 'Shape Shift',
    tagline: 'Recognizable silhouettes',
    accentColor: 0xF28C18, // orange
    families: [
      PatternFamily.cat,
      PatternFamily.fox,
      PatternFamily.dog,
      PatternFamily.rabbit,
      PatternFamily.bird,
    ],
  ),
  ChapterDef(
    index: 5,
    name: 'The Maze',
    tagline: 'Denser, narrower, trickier',
    accentColor: 0xEF4149, // red
    families: [
      PatternFamily.symmetricalMaze,
      PatternFamily.branchingPaths,
      PatternFamily.hexagon,
      PatternFamily.octagon,
    ],
  ),
  ChapterDef(
    index: 6,
    name: 'Crossroads',
    tagline: 'Everyday objects, real dependencies',
    accentColor: 0x2864E8,
    families: [
      PatternFamily.house,
      PatternFamily.tree,
      PatternFamily.key,
      PatternFamily.crown,
      PatternFamily.trophy,
    ],
  ),
  ChapterDef(
    index: 7,
    name: 'Mind Bender',
    tagline: 'Bigger boards, longer chains',
    accentColor: 0x0AA782,
    families: [
      PatternFamily.butterfly,
      PatternFamily.fish,
      PatternFamily.turtle,
      PatternFamily.elephant,
      PatternFamily.owl,
    ],
  ),
  ChapterDef(
    index: 8,
    name: 'Precision',
    tagline: 'Narrow margins, exact planning',
    accentColor: 0x7950F2,
    families: [
      PatternFamily.giftBox,
      PatternFamily.guitar,
      PatternFamily.lightningBolt,
      PatternFamily.planet,
      PatternFamily.shield,
      PatternFamily.gameController,
    ],
  ),
  ChapterDef(
    index: 9,
    name: 'Overdrive',
    tagline: 'Maximum density',
    accentColor: 0xF28C18,
    families: [
      PatternFamily.denseArrowFormation,
      PatternFamily.multipleClusters,
      PatternFamily.negativeSpace,
      PatternFamily.layeredGeometric,
    ],
  ),
  ChapterDef(
    index: 10,
    name: 'OUTGRID Master',
    tagline: 'Everything you\'ve learned, at once',
    accentColor: 0xEF4149,
    families: [
      PatternFamily.complexMosaic,
      PatternFamily.cat,
      PatternFamily.elephant,
      PatternFamily.star,
      PatternFamily.symmetricalMaze,
      PatternFamily.denseArrowFormation,
      PatternFamily.butterfly,
      PatternFamily.crown,
      PatternFamily.spiral,
      PatternFamily.diamond,
    ],
  ),
];

ChapterDef chapterByIndex(int index) =>
    kChapters.firstWhere((c) => c.index == index);

ChapterDef chapterForGlobalLevel(int globalIndex) => kChapters.firstWhere(
    (c) => globalIndex >= c.firstGlobalIndex && globalIndex <= c.lastGlobalIndex);

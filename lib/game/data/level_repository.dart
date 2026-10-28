import '../../core/constants/chapters.dart';
import '../../models/level_model.dart';
import 'level_loader.dart';

/// In-memory cache over the bundled level assets. Loads lazily per
/// chapter (not all 500 at once) and caches results, so opening the app
/// or jumping straight to a late level doesn't pay for parsing chapters
/// the player hasn't reached yet.
class LevelRepository {
  final LevelLoader _loader;
  final Map<int, List<LevelModel>> _chapterCache = {};

  LevelRepository({LevelLoader loader = const LevelLoader()})
      : _loader = loader;

  Future<List<LevelModel>> chapter(int chapterIndex) async {
    final cached = _chapterCache[chapterIndex];
    if (cached != null) return cached;
    final levels = await _loader.loadChapter(chapterIndex);
    _chapterCache[chapterIndex] = levels;
    return levels;
  }

  Future<LevelModel> levelByGlobalIndex(int globalIndex) async {
    final chapterDef = chapterForGlobalLevel(globalIndex);
    final levels = await chapter(chapterDef.index);
    return levels.firstWhere((l) => l.globalIndex == globalIndex);
  }

  Future<LevelModel?> levelById(String id) async {
    final chapterIndex = int.parse(id.substring(1, 3));
    final levels = await chapter(chapterIndex);
    for (final l in levels) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Loads every chapter. Used by level-select (needs completion state
  /// for all 500 at once) and by validation tooling/tests — not on the
  /// hot path of opening a single level.
  Future<List<LevelModel>> all() async {
    final out = <LevelModel>[];
    for (final c in kChapters) {
      out.addAll(await chapter(c.index));
    }
    return out;
  }

  void clearCache() => _chapterCache.clear();
}

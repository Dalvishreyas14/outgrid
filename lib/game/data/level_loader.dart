import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/level_model.dart';

/// Reads bundled level JSON assets. No network access — every level ships
/// inside the app so the game is fully playable offline.
class LevelLoader {
  const LevelLoader();

  Future<Map<String, dynamic>> loadManifest() async {
    final raw = await rootBundle.loadString('assets/levels/level_manifest.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<LevelModel>> loadChapter(int chapterIndex) async {
    final padded = chapterIndex.toString().padLeft(2, '0');
    final raw = await rootBundle
        .loadString('assets/levels/chapter_$padded/chapter_$padded.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['levels'] as List)
        .map((l) => LevelModel.fromJson(l as Map<String, dynamic>))
        .toList(growable: false);
  }
}

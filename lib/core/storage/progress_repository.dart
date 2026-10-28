import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/player_progress.dart';

/// Reads/writes [PlayerProgress] to local key-value storage. Versioned so
/// a future schema change can migrate old saves instead of discarding
/// them.
class ProgressRepository {
  static const _key = 'outgrid_progress_v1';

  const ProgressRepository();

  Future<PlayerProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PlayerProgress();
    try {
      return PlayerProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const PlayerProgress();
    }
  }

  Future<void> save(PlayerProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(progress.toJson()));
  }
}

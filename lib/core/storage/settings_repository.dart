import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/game_settings.dart';

/// Reads/writes [GameSettings] to local key-value storage. No network —
/// settings are device-local by design.
class SettingsRepository {
  static const _key = 'outgrid_settings_v1';

  const SettingsRepository();

  Future<GameSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const GameSettings();
    try {
      return GameSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt or pre-migration data: fall back to safe defaults rather
      // than crash the app on startup.
      return const GameSettings();
    }
  }

  Future<void> save(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

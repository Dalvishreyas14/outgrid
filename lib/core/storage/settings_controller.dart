import 'package:flutter/foundation.dart';

import '../../models/game_settings.dart';
import 'settings_repository.dart';

/// Live, in-memory [GameSettings] shared across the app via Provider.
/// Every mutator updates state, notifies listeners, then persists —
/// settings changes always survive app restart.
class SettingsController extends ChangeNotifier {
  final SettingsRepository _repo;
  GameSettings settings = const GameSettings();
  bool isLoaded = false;

  SettingsController({SettingsRepository repo = const SettingsRepository()})
      : _repo = repo;

  Future<void> load() async {
    settings = await _repo.load();
    isLoaded = true;
    notifyListeners();
  }

  Future<void> _update(GameSettings next) async {
    settings = next;
    notifyListeners();
    await _repo.save(settings);
  }

  Future<void> setSound(bool v) => _update(settings.copyWith(soundEnabled: v));
  Future<void> setMusic(bool v) => _update(settings.copyWith(musicEnabled: v));
  Future<void> setHaptics(bool v) =>
      _update(settings.copyWith(hapticsEnabled: v));
  Future<void> setReducedMotion(bool v) =>
      _update(settings.copyWith(reducedMotion: v));
  Future<void> setThemeMode(AppThemeMode mode) =>
      _update(settings.copyWith(themeMode: mode));
  Future<void> setPalette(String name) =>
      _update(settings.copyWith(arrowPaletteName: name));
  Future<void> setTimedMode(bool v) =>
      _update(settings.copyWith(timedModeEnabled: v));
}

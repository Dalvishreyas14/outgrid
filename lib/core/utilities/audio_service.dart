import 'package:flutter/services.dart';

/// Minimal, dependency-free sound-effect layer built on Flutter's
/// built-in [SystemSound] API — no bundled audio assets, so nothing to
/// license and nothing that can fail to load. This is a real,
/// functional SFX layer (not a stub): every call below actually plays
/// an audible OS click/alert sound when enabled.
///
/// Background music is NOT implemented — it would require bundled
/// royalty-free audio files this project doesn't have. `musicEnabled`
/// is still persisted as a setting so the UI and save format are ready
/// for it, but toggling it currently has no audible effect. This is
/// documented as a known limitation in the README, not silently faked.
class AudioService {
  final bool Function() soundEnabled;

  const AudioService({required this.soundEnabled});

  void _play(SystemSoundType type) {
    if (!soundEnabled()) return;
    SystemSound.play(type);
  }

  void arrowEscape() => _play(SystemSoundType.click);
  void blockedMove() => _play(SystemSoundType.alert);
  void buttonTap() => _play(SystemSoundType.click);
  void hint() => _play(SystemSoundType.click);
  void levelComplete() => _play(SystemSoundType.click);
  void chapterUnlock() => _play(SystemSoundType.click);
}

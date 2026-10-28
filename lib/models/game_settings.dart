enum AppThemeMode { light, warm, dark }

/// User-configurable settings, persisted independently from progress.
class GameSettings {
  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final bool reducedMotion;
  final AppThemeMode themeMode;
  final String arrowPaletteName;
  final bool timedModeEnabled;

  const GameSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.themeMode = AppThemeMode.light,
    this.arrowPaletteName = 'OUTGRID Classic',
    this.timedModeEnabled = false,
  });

  GameSettings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool? reducedMotion,
    AppThemeMode? themeMode,
    String? arrowPaletteName,
    bool? timedModeEnabled,
  }) {
    return GameSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      themeMode: themeMode ?? this.themeMode,
      arrowPaletteName: arrowPaletteName ?? this.arrowPaletteName,
      timedModeEnabled: timedModeEnabled ?? this.timedModeEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'sound': soundEnabled,
        'music': musicEnabled,
        'haptics': hapticsEnabled,
        'reducedMotion': reducedMotion,
        'theme': themeMode.name,
        'palette': arrowPaletteName,
        'timedMode': timedModeEnabled,
      };

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
        soundEnabled: json['sound'] as bool? ?? true,
        musicEnabled: json['music'] as bool? ?? true,
        hapticsEnabled: json['haptics'] as bool? ?? true,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        themeMode: AppThemeMode.values.firstWhere(
          (t) => t.name == (json['theme'] as String? ?? 'light'),
          orElse: () => AppThemeMode.light,
        ),
        arrowPaletteName: json['palette'] as String? ?? 'OUTGRID Classic',
        timedModeEnabled: json['timedMode'] as bool? ?? false,
      );
}

import 'package:flutter/material.dart';

import '../models/game_settings.dart';

/// OUTGRID brand palette, matching the supplied logo (navy wordmark,
/// white ground, purple/blue/green/orange/red arrow accents).
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const warmBackground = Color(0xFFFFF7E8);
  static const darkBackground = Color(0xFF14181F);
  static const darkSurface = Color(0xFF202938);
  static const textPrimary = Color(0xFF171B24);
  static const textSecondary = Color(0xFF737987);
  static const purple = Color(0xFF7950F2);
  static const blue = Color(0xFF2864E8);
  static const green = Color(0xFF0AA782);
  static const orange = Color(0xFFF28C18);
  static const red = Color(0xFFEF4149);
}

class AppTheme {
  static ThemeData forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return _build(
          background: AppColors.darkBackground,
          surface: AppColors.darkSurface,
          textPrimary: Colors.white,
          textSecondary: const Color(0xFFA7AEBD),
          brightness: Brightness.dark,
        );
      case AppThemeMode.warm:
        return _build(
          background: AppColors.warmBackground,
          surface: Colors.white,
          textPrimary: AppColors.textPrimary,
          textSecondary: AppColors.textSecondary,
          brightness: Brightness.light,
        );
      case AppThemeMode.light:
        return _build(
          background: AppColors.background,
          surface: const Color(0xFFF4F5F7),
          textPrimary: AppColors.textPrimary,
          textSecondary: AppColors.textSecondary,
          brightness: Brightness.light,
        );
    }
  }

  static ThemeData _build({
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.purple,
      onPrimary: Colors.white,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: textSecondary.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.purple : null),
      ),
      dividerColor: textSecondary.withValues(alpha: 0.15),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 34),
      headlineMedium: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 24),
      titleLarge: TextStyle(color: primary, fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge: TextStyle(color: primary, fontSize: 16),
      bodyMedium: TextStyle(color: secondary, fontSize: 14),
      labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

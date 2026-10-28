import 'package:flutter/painting.dart';

import '../../models/arrow_color.dart';

/// Maps palette ids to concrete theme colors. Kept separate from the pure
/// model layer so alternate palettes (colorblind-friendly, dark-theme
/// tuned) can be swapped in without touching level data or engine code.
class ArrowPalette {
  final Map<ArrowColorId, Color> colors;
  final String name;

  const ArrowPalette({required this.name, required this.colors});

  Color operator [](ArrowColorId id) => colors[id]!;

  static const ArrowPalette outgridDefault = ArrowPalette(
    name: 'OUTGRID Classic',
    colors: {
      ArrowColorId.purple: Color(0xFF7950F2),
      ArrowColorId.blue: Color(0xFF2864E8),
      ArrowColorId.green: Color(0xFF0AA782),
      ArrowColorId.orange: Color(0xFFF28C18),
      ArrowColorId.red: Color(0xFFEF4149),
    },
  );

  /// Higher-contrast variant tuned for dark backgrounds.
  static const ArrowPalette outgridNight = ArrowPalette(
    name: 'OUTGRID Night',
    colors: {
      ArrowColorId.purple: Color(0xFF9B7CF7),
      ArrowColorId.blue: Color(0xFF5B8DFF),
      ArrowColorId.green: Color(0xFF2FD3A6),
      ArrowColorId.orange: Color(0xFFFFA940),
      ArrowColorId.red: Color(0xFFFF6B70),
    },
  );

  /// Alternate unlockable palette, kept distinct in hue ordering so it
  /// reads as a genuinely different theme rather than a re-tint.
  static const ArrowPalette sunset = ArrowPalette(
    name: 'Sunset',
    colors: {
      ArrowColorId.purple: Color(0xFFB5389B),
      ArrowColorId.blue: Color(0xFF1C7ED6),
      ArrowColorId.green: Color(0xFF37B24D),
      ArrowColorId.orange: Color(0xFFFF922B),
      ArrowColorId.red: Color(0xFFE03131),
    },
  );

  static const List<ArrowPalette> all = [outgridDefault, outgridNight, sunset];

  static ArrowPalette byName(String name) =>
      all.firstWhere((p) => p.name == name, orElse: () => outgridDefault);
}

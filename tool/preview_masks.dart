import 'dart:io';
import 'dart:math' as math;

import 'package:outgrid/game/generation/silhouette_library.dart';
import 'package:outgrid/models/level_model.dart';

import 'png_writer.dart';

/// Dev-only: renders every silhouette family to a PNG so shapes can be
/// visually sanity-checked before being used to generate real levels.
/// Usage: dart run tool/preview_masks.dart OUTPUT_DIR
void main(List<String> args) {
  final outDir = args.isNotEmpty ? args[0] : 'preview_out';
  Directory(outDir).createSync(recursive: true);
  const rows = 28, cols = 28;
  for (final family in PatternFamily.values) {
    final builder = silhouetteBuilders[family];
    if (builder == null) {
      stderr.writeln('MISSING builder for $family');
      continue;
    }
    final rng = math.Random(42);
    final mask = builder(rows, cols, rng);
    final png = encodeMaskPng(mask, scale: 10);
    final path = '$outDir/${family.name}.png';
    File(path).writeAsBytesSync(png);
    final filled = mask.expand((r) => r).where((b) => b).length;
    stdout.writeln('${family.name}: $filled/${rows * cols} cells filled -> $path');
  }
}

import 'dart:io';

import 'package:outgrid/game/generation/level_generator.dart';
import 'package:outgrid/models/arrow_color.dart';
import 'package:outgrid/models/level_model.dart';

import 'png_writer.dart';

const _paletteRgb = {
  ArrowColorId.purple: 0x7950F2,
  ArrowColorId.blue: 0x2864E8,
  ArrowColorId.green: 0x0AA782,
  ArrowColorId.orange: 0xF28C18,
  ArrowColorId.red: 0xEF4149,
};

void main(List<String> args) {
  final outDir = args.isNotEmpty ? args[0] : 'preview_out';
  Directory(outDir).createSync(recursive: true);

  const gen = LevelGenerator();
  var totalAttempts = 0;
  var worstAttempts = 0;
  var failures = 0;
  final rows = <String>[];

  for (final family in PatternFamily.values) {
    final result = gen.generate(
      id: 'preview_${family.name}',
      chapterIndex: 1,
      levelInChapter: 1,
      globalIndex: 1,
      title: family.name,
      family: family,
      rows: 16,
      cols: 16,
      seed: family.index * 1000 + 7,
    );
    if (result.failed || result.level == null) {
      failures++;
      rows.add('${family.name}: FAILED after ${result.attempts} attempts');
      continue;
    }
    totalAttempts += result.attempts;
    if (result.attempts > worstAttempts) worstAttempts = result.attempts;
    final level = result.level!;
    rows.add(
        '${family.name}: ok attempts=${result.attempts} arrows=${level.arrows.length} '
        'difficulty=${level.difficultyScore}');

    if (const [
      'cat',
      'elephant',
      'star',
      'spiral',
      'denseArrowFormation',
      'symmetricalMaze',
      'butterfly',
      'crown'
    ].contains(family.name)) {
      final rgb = List.generate(
          level.rows, (_) => List<int>.filled(level.cols, 0xFFFFFF));
      for (final arrow in level.arrows) {
        final base = _paletteRgb[arrow.color]!;
        for (final cell in arrow.cells) {
          rgb[cell.row][cell.col] = base;
        }
        final head = arrow.head;
        rgb[head.row][head.col] = 0x171B24;
      }
      File('$outDir/level_${family.name}.png')
          .writeAsBytesSync(encodeRgbPng(rgb, scale: 14));
    }
  }

  stdout.writeln(rows.join('\n'));
  stdout.writeln('---');
  stdout.writeln(
      'families=${PatternFamily.values.length} failures=$failures avgAttempts=${(totalAttempts / (PatternFamily.values.length - failures)).toStringAsFixed(2)} worstAttempts=$worstAttempts');
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:outgrid/core/constants/chapters.dart';
import 'package:outgrid/game/generation/level_generator.dart';
import 'package:outgrid/models/level_model.dart';

/// Generation + validation pipeline for all 500 OUTGRID levels (Phase 5
/// of the design brief). Deterministic: re-running this script produces
/// byte-identical level data, because every level's RNG seed is derived
/// solely from its global index.
///
/// Usage: dart run tool/generate_levels.dart
void main() {
  final projectRoot = Directory.current.path;
  final levelsDir = Directory('$projectRoot/assets/levels');
  final reportsDir = Directory('$projectRoot/reports');
  reportsDir.createSync(recursive: true);

  const generator = LevelGenerator();
  final reportRows = <Map<String, dynamic>>[];
  final failures = <String>[];
  var totalArrows = 0;
  final difficulties = <int>[];

  for (final chapter in kChapters) {
    final chapterDir = Directory(
        '${levelsDir.path}/chapter_${chapter.index.toString().padLeft(2, '0')}');
    chapterDir.createSync(recursive: true);
    final chapterLevels = <Map<String, dynamic>>[];

    for (var levelInChapter = 1;
        levelInChapter <= ChapterDef.levelsPerChapter;
        levelInChapter++) {
      final globalIndex =
          (chapter.index - 1) * ChapterDef.levelsPerChapter + levelInChapter;
      final family = chapter.familyForLevel(levelInChapter);
      final id =
          'c${chapter.index.toString().padLeft(2, '0')}_l${levelInChapter.toString().padLeft(3, '0')}';
      final seed = globalIndex * 97 + 13;
      final size = _boardSizeFor(globalIndex, seed);

      final result = generator.generate(
        id: id,
        chapterIndex: chapter.index,
        levelInChapter: levelInChapter,
        globalIndex: globalIndex,
        title: family.readableName,
        family: family,
        rows: size,
        cols: size,
        seed: seed,
      );

      if (result.failed || result.level == null) {
        failures.add('$id ($family @ ${size}x$size)');
        reportRows.add({
          'levelId': id,
          'pattern': family.name,
          'rows': size,
          'cols': size,
          'passed': false,
          'issues': ['GENERATION_FAILED after ${result.attempts} attempts'],
        });
        continue;
      }

      final arrowCount = result.level!.arrows.length;
      final timeLimit = (35 + arrowCount * 4).clamp(45, 420);
      final finalLevel = LevelModel(
        id: result.level!.id,
        chapterIndex: result.level!.chapterIndex,
        levelInChapter: result.level!.levelInChapter,
        globalIndex: result.level!.globalIndex,
        title: result.level!.title,
        patternFamily: result.level!.patternFamily,
        rows: result.level!.rows,
        cols: result.level!.cols,
        arrows: result.level!.arrows,
        difficultyScore: result.level!.difficultyScore,
        suggestedTimeLimitSeconds: timeLimit,
      );

      chapterLevels.add(finalLevel.toJson());
      totalArrows += arrowCount;
      difficulties.add(finalLevel.difficultyScore);
      reportRows.add(result.report!.toJson()
        ..addAll({'attempts': result.attempts, 'chapter': chapter.index}));
    }

    File('${chapterDir.path}/chapter_${chapter.index.toString().padLeft(2, '0')}.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ')
            .convert({'chapter': chapter.index, 'levels': chapterLevels}));
  }

  final manifest = {
    'schemaVersion': 1,
    'totalLevels': ChapterDef.totalLevels,
    'generatedLevels': ChapterDef.totalLevels - failures.length,
    'chapters': kChapters
        .map((c) => {
              'index': c.index,
              'name': c.name,
              'tagline': c.tagline,
              'accentColor': c.accentColor,
              'firstGlobalIndex': c.firstGlobalIndex,
              'lastGlobalIndex': c.lastGlobalIndex,
              'file':
                  'chapter_${c.index.toString().padLeft(2, '0')}/chapter_${c.index.toString().padLeft(2, '0')}.json',
            })
        .toList(),
  };
  File('${levelsDir.path}/level_manifest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

  final passed = reportRows.where((r) => r['passed'] == true).length;
  final avgDifficulty = difficulties.isEmpty
      ? 0
      : difficulties.reduce((a, b) => a + b) / difficulties.length;

  final summary = {
    'totalLevels': ChapterDef.totalLevels,
    'passed': passed,
    'failed': failures.length,
    'totalArrowsAcrossAllLevels': totalArrows,
    'averageDifficulty': avgDifficulty,
    'failureIds': failures,
    'levels': reportRows,
  };
  File('${reportsDir.path}/level_validation_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

  final md = StringBuffer()
    ..writeln('# OUTGRID Level Validation Report')
    ..writeln()
    ..writeln('- Total levels: ${ChapterDef.totalLevels}')
    ..writeln('- Passed validation: $passed')
    ..writeln('- Failed validation: ${failures.length}')
    ..writeln('- Total arrows across all levels: $totalArrows')
    ..writeln('- Average difficulty score: ${avgDifficulty.toStringAsFixed(1)}')
    ..writeln();
  if (failures.isNotEmpty) {
    md.writeln('## Failures');
    for (final f in failures) {
      md.writeln('- $f');
    }
    md.writeln();
  }
  md.writeln('## Per-chapter summary');
  md.writeln();
  md.writeln('| Chapter | Name | Levels | Avg Arrows | Avg Difficulty | Board Size Range |');
  md.writeln('|---|---|---|---|---|---|');
  for (final chapter in kChapters) {
    final chapterReportRows = reportRows
        .where((r) => r['chapter'] == chapter.index && r['passed'] == true)
        .toList();
    final avgArrows = chapterReportRows.isEmpty
        ? 0
        : chapterReportRows
                .map((r) => r['arrowCount'] as int)
                .reduce((a, b) => a + b) /
            chapterReportRows.length;
    final avgDiff = chapterReportRows.isEmpty
        ? 0
        : chapterReportRows
                .map((r) => r['difficulty'] as int)
                .reduce((a, b) => a + b) /
            chapterReportRows.length;
    final sizes = chapterReportRows.map((r) => r['rows'] as int).toList();
    final minSize = sizes.isEmpty ? 0 : sizes.reduce((a, b) => a < b ? a : b);
    final maxSize = sizes.isEmpty ? 0 : sizes.reduce((a, b) => a > b ? a : b);
    md.writeln(
        '| ${chapter.index} | ${chapter.name} | ${chapterReportRows.length} | ${avgArrows.toStringAsFixed(1)} | ${avgDiff.toStringAsFixed(1)} | ${minSize}x$minSize - ${maxSize}x$maxSize |');
  }
  File('${reportsDir.path}/level_validation_report.md')
      .writeAsStringSync(md.toString());

  stdout.writeln('Generated ${ChapterDef.totalLevels} levels.');
  stdout.writeln('Passed: $passed, Failed: ${failures.length}');
  stdout.writeln('Report written to reports/level_validation_report.{json,md}');
}

/// Smoothly grows board size from ~8x8 (teaching) to ~30x30 (expert)
/// across the 500 levels, with small deterministic per-level jitter so
/// consecutive levels in a chapter aren't identically sized.
int _boardSizeFor(int globalIndex, int seed) {
  final t = (globalIndex - 1) / (ChapterDef.totalLevels - 1);
  final eased = math.pow(t, 0.85);
  final base = 8 + eased * (30 - 8);
  final jitter = (seed % 5) - 2; // -2..+2
  return (base + jitter).round().clamp(7, 32);
}

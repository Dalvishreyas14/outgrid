import 'dart:math' as math;

import '../../models/level_model.dart';
import 'shape_geometry.dart';

typedef MaskBuilder = List<List<bool>> Function(
    int rows, int cols, math.Random rng);

double _jit(math.Random rng, double base, double range) =>
    base + (rng.nextDouble() * 2 - 1) * range;

List<List<bool>> _fromRegion(int rows, int cols, Region region) =>
    rasterize(rows, cols, region);

/// Randomized-growing-tree carve, used for the organic branching/maze
/// abstract families. Produces a connected, self-avoiding corridor
/// network rather than a smooth silhouette.
List<List<bool>> _carveBranching(
  int rows,
  int cols,
  math.Random rng, {
  bool mirrorH = false,
  double fillRatio = 0.4,
}) {
  final workCols = mirrorH ? (cols / 2).ceil() : cols;
  final visited = List.generate(rows, (_) => List<bool>.filled(workCols, false));
  final r0 = rows ~/ 2;
  final c0 = workCols ~/ 2;
  final stack = <List<int>>[
    [r0, c0]
  ];
  visited[r0][c0] = true;
  const dirs = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];
  final maxSteps = (rows * workCols * fillRatio).round();
  var steps = 0;
  while (stack.isNotEmpty && steps < maxSteps) {
    final cur = stack.last;
    final shuffled = List.of(dirs)..shuffle(rng);
    var moved = false;
    for (final d in shuffled) {
      final nr = cur[0] + d[0], nc = cur[1] + d[1];
      if (nr >= 0 &&
          nr < rows &&
          nc >= 0 &&
          nc < workCols &&
          !visited[nr][nc]) {
        visited[nr][nc] = true;
        stack.add([nr, nc]);
        moved = true;
        steps++;
        break;
      }
    }
    if (!moved) stack.removeLast();
  }
  final grid = List.generate(rows, (_) => List<bool>.filled(cols, false));
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < workCols; c++) {
      if (visited[r][c]) {
        grid[r][c] = true;
        if (mirrorH) grid[r][cols - 1 - c] = true;
      }
    }
  }
  return grid;
}

Region _spiral(math.Random rng,
    {double cx = 0, double cy = 0, bool flip = false, int turns = 3}) {
  final a = _jit(rng, 0.11, 0.015);
  final thickness = _jit(rng, 0.085, 0.01);
  return (x, y) {
    final dx = flip ? -(x - cx) : (x - cx);
    final dy = y - cy;
    final r = math.sqrt(dx * dx + dy * dy);
    if (r > a * turns * 2 * math.pi + thickness) return false;
    var theta = math.atan2(dy, dx);
    if (theta < 0) theta += 2 * math.pi;
    for (var k = 0; k <= turns; k++) {
      final ringR = a * (theta + 2 * math.pi * k);
      if ((r - ringR).abs() <= thickness) return true;
    }
    return false;
  };
}

final Map<PatternFamily, MaskBuilder> silhouetteBuilders = {
  // ---------------- GEOMETRIC ----------------
  PatternFamily.circle: (rows, cols, rng) => _fromRegion(
      rows, cols, ellipse(0, 0, _jit(rng, 0.62, 0.08), _jit(rng, 0.62, 0.08))),

  PatternFamily.square: (rows, cols, rng) => _fromRegion(
      rows, cols, rect(0, 0, _jit(rng, 0.6, 0.08), _jit(rng, 0.6, 0.08))),

  PatternFamily.diamond: (rows, cols, rng) => _fromRegion(
      rows, cols, regularPolygon(4, _jit(rng, 0.78, 0.08), rotation: 0)),

  PatternFamily.triangle: (rows, cols, rng) => _fromRegion(
      rows, cols, regularPolygon(3, _jit(rng, 0.75, 0.08))),

  PatternFamily.hexagon: (rows, cols, rng) =>
      _fromRegion(rows, cols, regularPolygon(6, _jit(rng, 0.68, 0.06))),

  PatternFamily.octagon: (rows, cols, rng) =>
      _fromRegion(rows, cols, regularPolygon(8, _jit(rng, 0.68, 0.06))),

  PatternFamily.star: (rows, cols, rng) => _fromRegion(
      rows, cols, star(5, _jit(rng, 0.78, 0.06), _jit(rng, 0.32, 0.05))),

  PatternFamily.heart: (rows, cols, rng) => _fromRegion(
      rows, cols, heart(scale: _jit(rng, 0.62, 0.05))),

  PatternFamily.spiral: (rows, cols, rng) =>
      _fromRegion(rows, cols, _spiral(rng)),

  PatternFamily.ring: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      annulus(0, 0, _jit(rng, 0.68, 0.06), _jit(rng, 0.68, 0.06),
          _jit(rng, 0.38, 0.06), _jit(rng, 0.38, 0.06))),

  PatternFamily.concentric: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        annulus(0, 0, 0.78, 0.78, 0.62, 0.62),
        annulus(0, 0, 0.5, 0.5, 0.34, 0.34),
        ellipse(0, 0, 0.18, 0.18),
      ])),

  PatternFamily.symmetricalGeometric: (rows, cols, rng) {
    final shapes = <Region>[];
    final count = 2 + rng.nextInt(2);
    for (var i = 0; i < count; i++) {
      final cx = _jit(rng, 0.42, 0.18).abs();
      final cy = _jit(rng, 0.42, 0.18).abs();
      final r = _jit(rng, 0.22, 0.06);
      shapes.add(rng.nextBool()
          ? ellipse(cx, cy, r, r)
          : regularPolygon(4, r, cx: cx, cy: cy));
    }
    final quadrant = union(shapes);
    return _fromRegion(rows, cols, (x, y) => quadrant(x.abs(), y.abs()));
  },

  // ---------------- ANIMALS ----------------
  PatternFamily.cat: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        polygon([const Pt(-0.48, -0.2), const Pt(-0.24, -0.88), const Pt(-0.08, -0.32)]),
        polygon([const Pt(0.48, -0.2), const Pt(0.24, -0.88), const Pt(0.08, -0.32)]),
        ellipse(0, -0.08, 0.46, 0.42),
        polygon([
          const Pt(-0.5, 0.12),
          const Pt(0.5, 0.12),
          const Pt(0.36, 0.92),
          const Pt(-0.36, 0.92),
        ]),
      ])),

  PatternFamily.fox: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        polygon([const Pt(-0.44, -0.18), const Pt(-0.22, -0.92), const Pt(-0.04, -0.3)]),
        polygon([const Pt(0.44, -0.18), const Pt(0.22, -0.92), const Pt(0.04, -0.3)]),
        ellipse(0, -0.08, 0.4, 0.36),
        polygon([const Pt(-0.16, 0.14), const Pt(0.16, 0.14), const Pt(0, 0.56)]),
        polygon([
          const Pt(0.42, 0.3),
          const Pt(0.88, 0.1),
          const Pt(0.92, 0.58),
          const Pt(0.46, 0.82),
        ]),
        polygon([
          const Pt(-0.46, 0.3),
          const Pt(0.46, 0.3),
          const Pt(0.3, 0.9),
          const Pt(-0.3, 0.9),
        ]),
      ])),

  PatternFamily.dog: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(-0.46, 0.08, 0.15, 0.36, rot: -0.1),
        ellipse(0.46, 0.08, 0.15, 0.36, rot: 0.1),
        ellipse(0, -0.22, 0.32, 0.3),
        ellipse(0, 0.1, 0.24, 0.2),
        polygon([
          const Pt(-0.4, 0.14),
          const Pt(0.4, 0.14),
          const Pt(0.32, 0.92),
          const Pt(-0.32, 0.92),
        ]),
      ])),

  PatternFamily.rabbit: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        rect(-0.24, -0.78, 0.13, 0.42, rot: -0.06),
        rect(0.24, -0.78, 0.13, 0.42, rot: 0.06),
        ellipse(0, -0.12, 0.42, 0.4),
        ellipse(0, 0.5, 0.48, 0.38),
      ])),

  PatternFamily.bird: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, 0.08, 0.48, 0.5),
        polygon([const Pt(0.3, 0.0), const Pt(0.75, 0.1), const Pt(0.3, 0.24)]),
        polygon([
          const Pt(-0.36, -0.05),
          const Pt(-0.68, -0.25),
          const Pt(-0.68, 0.1),
        ]),
      ])),

  PatternFamily.butterfly: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, 0, 0.07, 0.68),
        ellipse(-0.36, -0.28, 0.42, 0.36, rot: -0.3),
        ellipse(0.36, -0.28, 0.42, 0.36, rot: 0.3),
        ellipse(-0.28, 0.32, 0.3, 0.28, rot: -0.2),
        ellipse(0.28, 0.32, 0.3, 0.28, rot: 0.2),
      ])),

  PatternFamily.fish: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(-0.05, 0, 0.55, 0.34),
        polygon([
          const Pt(-0.55, -0.28),
          const Pt(-0.92, 0),
          const Pt(-0.55, 0.28),
        ]),
        polygon([const Pt(0, -0.3), const Pt(0.18, -0.58), const Pt(0.32, -0.28)]),
      ])),

  PatternFamily.turtle: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, -0.02, 0.56, 0.42),
        ellipse(0.62, -0.02, 0.2, 0.15),
        ellipse(-0.42, -0.42, 0.17, 0.14),
        ellipse(0.42, -0.42, 0.17, 0.14),
        ellipse(-0.42, 0.4, 0.17, 0.14),
        ellipse(0.42, 0.4, 0.17, 0.14),
        polygon([const Pt(-0.56, -0.05), const Pt(-0.8, 0), const Pt(-0.56, 0.08)]),
      ])),

  PatternFamily.elephant: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(-0.58, -0.36, 0.26, 0.32),
        ellipse(0.58, -0.36, 0.26, 0.32),
        ellipse(0, -0.42, 0.3, 0.26),
        ellipse(0, 0.08, 0.46, 0.38),
        strokePath(const [
          Pt(0, -0.22),
          Pt(0.07, 0.08),
          Pt(0.1, 0.4),
          Pt(0.0, 0.62),
          Pt(-0.06, 0.8),
        ], 0.09),
        rect(-0.3, 0.64, 0.08, 0.2),
        rect(-0.1, 0.68, 0.08, 0.22),
        rect(0.14, 0.68, 0.08, 0.22),
        rect(0.34, 0.64, 0.08, 0.2),
      ])),

  PatternFamily.owl: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, 0.02, 0.5, 0.56),
        polygon([const Pt(-0.44, -0.42), const Pt(-0.6, -0.86), const Pt(-0.18, -0.5)]),
        polygon([const Pt(0.44, -0.42), const Pt(0.6, -0.86), const Pt(0.18, -0.5)]),
        polygon([const Pt(-0.16, 0.5), const Pt(-0.3, 0.84), const Pt(-0.02, 0.6)]),
        polygon([const Pt(0.16, 0.5), const Pt(0.3, 0.84), const Pt(0.02, 0.6)]),
      ])),

  // ---------------- OBJECTS ----------------
  PatternFamily.crown: (rows, cols, rng) {
    final peaks = <Pt>[];
    const peakCount = 5;
    for (var i = 0; i <= peakCount; i++) {
      final x = -0.7 + (1.4 * i / peakCount);
      peaks.add(Pt(x, i.isOdd ? -0.75 : -0.3));
    }
    final verts = [
      const Pt(-0.7, 0.55),
      const Pt(-0.7, -0.1),
      ...peaks,
      const Pt(0.7, -0.1),
      const Pt(0.7, 0.55),
    ];
    return _fromRegion(rows, cols, polygon(verts));
  },

  PatternFamily.rocket: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      subtract(
          union([
            rect(0, 0.05, 0.22, 0.55),
            polygon([const Pt(-0.22, -0.5), const Pt(0.22, -0.5), const Pt(0, -0.95)]),
            polygon([
              const Pt(-0.22, 0.35),
              const Pt(-0.52, 0.62),
              const Pt(-0.22, 0.62),
            ]),
            polygon([
              const Pt(0.22, 0.35),
              const Pt(0.52, 0.62),
              const Pt(0.22, 0.62),
            ]),
          ]),
          ellipse(0, -0.08, 0.1, 0.1))),

  PatternFamily.house: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      subtract(
          union([
            rect(0, 0.28, 0.5, 0.34),
            polygon([
              const Pt(-0.62, -0.08),
              const Pt(0.62, -0.08),
              const Pt(0, -0.62),
            ]),
            rect(0.32, -0.42, 0.08, 0.18),
          ]),
          rect(0, 0.48, 0.12, 0.14))),

  PatternFamily.tree: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        rect(0, 0.42, 0.09, 0.34),
        ellipse(0, -0.1, 0.42, 0.36),
        ellipse(0, -0.48, 0.3, 0.26),
      ])),

  PatternFamily.key: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        subtract(ellipse(0, -0.56, 0.24, 0.24), ellipse(0, -0.56, 0.1, 0.1)),
        rect(0, 0.05, 0.08, 0.56),
        rect(0.16, 0.45, 0.08, 0.07),
        rect(0.16, 0.6, 0.08, 0.05),
      ])),

  PatternFamily.trophy: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        polygon([
          const Pt(-0.42, -0.6),
          const Pt(0.42, -0.6),
          const Pt(0.22, 0.02),
          const Pt(-0.22, 0.02),
        ]),
        annulus(-0.55, -0.32, 0.2, 0.24, 0.09, 0.13),
        annulus(0.55, -0.32, 0.2, 0.24, 0.09, 0.13),
        rect(0, 0.18, 0.1, 0.16),
        rect(0, 0.42, 0.34, 0.1),
      ])),

  PatternFamily.giftBox: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        rect(0, 0.18, 0.48, 0.42),
        rect(0, 0.18, 0.08, 0.42),
        rect(0, 0.18, 0.48, 0.08),
        polygon([const Pt(-0.04, -0.26), const Pt(-0.32, -0.5), const Pt(-0.02, -0.4)]),
        polygon([const Pt(0.04, -0.26), const Pt(0.32, -0.5), const Pt(0.02, -0.4)]),
      ])),

  PatternFamily.guitar: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, 0.4, 0.46, 0.42),
        ellipse(0, -0.02, 0.3, 0.3),
        rect(0, -0.5, 0.06, 0.42),
        rect(0, -0.92, 0.14, 0.09),
      ])),

  PatternFamily.lightningBolt: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      polygon(const [
        Pt(0.12, -0.9),
        Pt(0.4, -0.9),
        Pt(-0.02, -0.08),
        Pt(0.22, -0.08),
        Pt(-0.28, 0.9),
        Pt(-0.06, 0.02),
        Pt(-0.36, 0.02),
      ])),

  PatternFamily.planet: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        ellipse(0, 0, 0.42, 0.42),
        annulus(0, 0, 0.88, 0.22, 0.7, 0.12, rot: -0.35),
      ])),

  PatternFamily.shield: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      polygon(const [
        Pt(-0.5, -0.65),
        Pt(0.5, -0.65),
        Pt(0.5, 0.05),
        Pt(0, 0.85),
        Pt(-0.5, 0.05),
      ])),

  PatternFamily.gameController: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      subtract(
          union([
            rect(0, -0.05, 0.5, 0.26),
            ellipse(-0.5, -0.05, 0.26, 0.26),
            ellipse(0.5, -0.05, 0.26, 0.26),
            ellipse(-0.38, 0.32, 0.26, 0.32),
            ellipse(0.38, 0.32, 0.26, 0.32),
          ]),
          union([
            ellipse(0.32, -0.12, 0.07, 0.07),
            ellipse(0.5, -0.22, 0.07, 0.07),
            rect(-0.42, -0.1, 0.12, 0.04),
            rect(-0.42, -0.1, 0.04, 0.12),
          ]))),

  // ---------------- ABSTRACT ----------------
  PatternFamily.circularLoops: (rows, cols, rng) {
    final rings = <Region>[];
    final count = 3 + rng.nextInt(2);
    for (var i = 0; i < count; i++) {
      final cx = _jit(rng, 0, 0.35);
      final cy = _jit(rng, 0, 0.35);
      final rOut = _jit(rng, 0.3, 0.08);
      rings.add(annulus(cx, cy, rOut, rOut, rOut * 0.65, rOut * 0.65));
    }
    return _fromRegion(rows, cols, union(rings));
  },

  PatternFamily.interlockingSpirals: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        _spiral(rng, cx: -0.3, cy: -0.1, turns: 2),
        _spiral(rng, cx: 0.3, cy: 0.1, flip: true, turns: 2),
      ])),

  PatternFamily.branchingPaths: (rows, cols, rng) =>
      _carveBranching(rows, cols, rng, fillRatio: 0.42),

  PatternFamily.symmetricalMaze: (rows, cols, rng) =>
      _carveBranching(rows, cols, rng, mirrorH: true, fillRatio: 0.42),

  PatternFamily.wavePattern: (rows, cols, rng) {
    final amp = _jit(rng, 0.35, 0.08);
    final freq = _jit(rng, 2.2, 0.4);
    final thickness = _jit(rng, 0.14, 0.02);
    return _fromRegion(rows, cols, (x, y) {
      final wave = amp * math.sin(freq * x * math.pi);
      return (y - wave).abs() <= thickness;
    });
  },

  PatternFamily.layeredGeometric: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      union([
        subtract(rect(0, 0, 0.78, 0.78), rect(0, 0, 0.6, 0.6)),
        subtract(rect(0, 0, 0.46, 0.46), rect(0, 0, 0.3, 0.3)),
        ellipse(0, 0, 0.14, 0.14),
      ])),

  PatternFamily.denseArrowFormation: (rows, cols, rng) =>
      _fromRegion(rows, cols, rect(0, 0, 0.92, 0.92)),

  PatternFamily.multipleClusters: (rows, cols, rng) {
    final count = 3 + rng.nextInt(3);
    final shapes = <Region>[];
    for (var i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count + _jit(rng, 0, 0.3);
      final dist = _jit(rng, 0.5, 0.08);
      final cx = dist * math.cos(angle);
      final cy = dist * math.sin(angle);
      final r = _jit(rng, 0.2, 0.05);
      shapes.add(ellipse(cx, cy, r, r));
    }
    return _fromRegion(rows, cols, union(shapes));
  },

  PatternFamily.negativeSpace: (rows, cols, rng) => _fromRegion(
      rows,
      cols,
      subtract(rect(0, 0, 0.82, 0.82), star(5, 0.42, 0.19))),

  PatternFamily.complexMosaic: (rows, cols, rng) {
    final shapes = <Region>[];
    final count = 5 + rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      final cx = _jit(rng, 0, 0.5);
      final cy = _jit(rng, 0, 0.5);
      final r = _jit(rng, 0.22, 0.08);
      final kind = rng.nextInt(3);
      shapes.add(switch (kind) {
        0 => ellipse(cx, cy, r, r),
        1 => regularPolygon(4, r, cx: cx, cy: cy),
        _ => regularPolygon(3, r, cx: cx, cy: cy),
      });
    }
    return _fromRegion(rows, cols, union(shapes));
  },
};

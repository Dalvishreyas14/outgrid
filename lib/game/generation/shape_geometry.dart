import 'dart:math' as math;

/// A point in normalized shape space: x,y roughly in [-1, 1], origin at
/// the board center. Used only by the silhouette library — never leaks
/// into shipped level data (which is plain grid cells).
class Pt {
  final double x, y;
  const Pt(this.x, this.y);
}

/// Boolean 2D field over normalized space. Pattern builders compose
/// shapes by combining these predicates before rasterizing to the grid.
typedef Region = bool Function(double x, double y);

Region union(List<Region> regions) =>
    (x, y) => regions.any((r) => r(x, y));

Region subtract(Region base, Region hole) =>
    (x, y) => base(x, y) && !hole(x, y);

Region intersect(List<Region> regions) =>
    (x, y) => regions.every((r) => r(x, y));

Region ellipse(double cx, double cy, double rx, double ry, {double rot = 0}) {
  final cosT = math.cos(-rot), sinT = math.sin(-rot);
  return (x, y) {
    final dx = x - cx, dy = y - cy;
    final rx2 = dx * cosT - dy * sinT;
    final ry2 = dx * sinT + dy * cosT;
    return (rx2 * rx2) / (rx * rx) + (ry2 * ry2) / (ry * ry) <= 1.0;
  };
}

Region annulus(double cx, double cy, double rxOut, double ryOut,
    double rxIn, double ryIn, {double rot = 0}) {
  final outer = ellipse(cx, cy, rxOut, ryOut, rot: rot);
  final inner = ellipse(cx, cy, rxIn, ryIn, rot: rot);
  return (x, y) => outer(x, y) && !inner(x, y);
}

Region rect(double cx, double cy, double halfW, double halfH,
    {double rot = 0}) {
  final cosT = math.cos(-rot), sinT = math.sin(-rot);
  return (x, y) {
    final dx = x - cx, dy = y - cy;
    final rx = dx * cosT - dy * sinT;
    final ry = dx * sinT + dy * cosT;
    return rx.abs() <= halfW && ry.abs() <= halfH;
  };
}

/// Point-in-polygon via ray casting. [verts] need not be convex.
Region polygon(List<Pt> verts) {
  return (x, y) {
    var inside = false;
    for (var i = 0, j = verts.length - 1; i < verts.length; j = i++) {
      final pi = verts[i], pj = verts[j];
      final intersects = ((pi.y > y) != (pj.y > y)) &&
          (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x);
      if (intersects) inside = !inside;
    }
    return inside;
  };
}

/// A regular N-gon centered at origin, point-up, circumradius [r].
Region regularPolygon(int sides, double r,
    {double cx = 0, double cy = 0, double rotation = -math.pi / 2}) {
  final verts = List.generate(sides, (i) {
    final a = rotation + 2 * math.pi * i / sides;
    return Pt(cx + r * math.cos(a), cy + r * math.sin(a));
  });
  return polygon(verts);
}

/// A 2n-gon star (n outer points) with given outer/inner radii.
Region star(int points, double outerR, double innerR,
    {double cx = 0, double cy = 0, double rotation = -math.pi / 2}) {
  final verts = List.generate(points * 2, (i) {
    final r = i.isEven ? outerR : innerR;
    final a = rotation + math.pi * i / points;
    return Pt(cx + r * math.cos(a), cy + r * math.sin(a));
  });
  return polygon(verts);
}

/// Distance from (x,y) to the segment a-b.
double _distToSegment(double x, double y, Pt a, Pt b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final lenSq = dx * dx + dy * dy;
  double t = lenSq == 0
      ? 0
      : (((x - a.x) * dx + (y - a.y) * dy) / lenSq).clamp(0.0, 1.0);
  final px = a.x + t * dx, py = a.y + t * dy;
  final ex = x - px, ey = y - py;
  return math.sqrt(ex * ex + ey * ey);
}

/// A thick polyline (stroke), useful for necks, trunks, bolts and wave
/// bands that are easier to describe as a path than a filled polygon.
Region strokePath(List<Pt> points, double thickness) {
  return (x, y) {
    for (var i = 1; i < points.length; i++) {
      if (_distToSegment(x, y, points[i - 1], points[i]) <= thickness) {
        return true;
      }
    }
    return false;
  };
}

/// Classic implicit heart curve (Taubin's heart), pre-normalized so the
/// silhouette roughly fills [-1, 1].
Region heart({double cx = 0, double cy = 0, double scale = 1.0}) {
  return (x, y) {
    final nx = (x - cx) / scale;
    // Flip y: normalized space has +y downward, heart curve wants +y up.
    final ny = -(y - cy) / scale * 1.15 + 0.35;
    final a = nx * nx + ny * ny - 1;
    return (a * a * a) - (nx * nx * ny * ny * ny) <= 0;
  };
}

/// Rasterizes a [Region] to a rows x cols boolean grid. The region is
/// sampled in a normalized space that matches the board's aspect ratio
/// (x spans roughly [-1,1] across cols, y across rows), using [margin]
/// to keep the silhouette from touching the board edge.
List<List<bool>> rasterize(
  int rows,
  int cols,
  Region region, {
  double margin = 0.08,
}) {
  final grid = List.generate(rows, (_) => List<bool>.filled(cols, false));
  final aspect = cols / rows;
  final scaleX = aspect >= 1 ? 1.0 : 1 / aspect;
  final scaleY = aspect >= 1 ? aspect : 1.0;
  for (var r = 0; r < rows; r++) {
    final ny = ((r + 0.5) / rows * 2 - 1) * scaleY / (1 - margin);
    for (var c = 0; c < cols; c++) {
      final nx = ((c + 0.5) / cols * 2 - 1) * scaleX / (1 - margin);
      if (region(nx, ny)) grid[r][c] = true;
    }
  }
  return grid;
}

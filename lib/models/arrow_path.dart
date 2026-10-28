import 'direction.dart';
import 'grid_point.dart';
import 'arrow_color.dart';

/// Immutable definition of one arrow as authored in level data.
///
/// [cells] is ordered from tail to head; the last entry is always the
/// arrowhead and, by construction-time invariant, is the most extreme
/// cell of the path along [direction]'s axis (so the arrow can never
/// block its own exit lane).
class ArrowPathDef {
  final String id;
  final List<GridPoint> cells;
  final GridDirection direction;
  final ArrowColorId color;

  const ArrowPathDef({
    required this.id,
    required this.cells,
    required this.direction,
    required this.color,
  });

  GridPoint get head => cells.last;

  GridPoint get tail => cells.first;

  int get length => cells.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dir': direction.name,
        'color': color.name,
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory ArrowPathDef.fromJson(Map<String, dynamic> json) {
    return ArrowPathDef(
      id: json['id'] as String,
      direction: GridDirectionX.fromName(json['dir'] as String),
      color: ArrowColorIdX.fromName(json['color'] as String),
      cells: (json['cells'] as List)
          .map((c) => GridPoint.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

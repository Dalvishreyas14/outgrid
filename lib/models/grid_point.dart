/// An immutable integer coordinate on the puzzle's logical grid.
class GridPoint {
  final int row;
  final int col;

  const GridPoint(this.row, this.col);

  GridPoint translate(int dRow, int dCol) =>
      GridPoint(row + dRow, col + dCol);

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';

  Map<String, dynamic> toJson() => {'r': row, 'c': col};

  factory GridPoint.fromJson(Map<String, dynamic> json) =>
      GridPoint(json['r'] as int, json['c'] as int);
}

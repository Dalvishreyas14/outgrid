/// Cardinal movement direction for an arrow's head and travel vector.
enum GridDirection { up, down, left, right }

extension GridDirectionX on GridDirection {
  /// Row delta per step in this direction.
  int get dRow {
    switch (this) {
      case GridDirection.up:
        return -1;
      case GridDirection.down:
        return 1;
      case GridDirection.left:
      case GridDirection.right:
        return 0;
    }
  }

  /// Column delta per step in this direction.
  int get dCol {
    switch (this) {
      case GridDirection.left:
        return -1;
      case GridDirection.right:
        return 1;
      case GridDirection.up:
      case GridDirection.down:
        return 0;
    }
  }

  bool get isHorizontal =>
      this == GridDirection.left || this == GridDirection.right;

  bool get isVertical => !isHorizontal;

  GridDirection get opposite {
    switch (this) {
      case GridDirection.up:
        return GridDirection.down;
      case GridDirection.down:
        return GridDirection.up;
      case GridDirection.left:
        return GridDirection.right;
      case GridDirection.right:
        return GridDirection.left;
    }
  }

  static GridDirection fromName(String name) {
    return GridDirection.values.firstWhere((d) => d.name == name);
  }
}

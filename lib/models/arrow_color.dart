/// The small, fixed OUTGRID arrow palette id set. Kept intentionally
/// short so colors stay distinguishable at high board density.
///
/// Pure Dart on purpose (no Flutter import) — this type is used by the
/// engine, solver, and generator, which all need to run outside the
/// Flutter engine (e.g. under plain `dart run` for level generation
/// tooling and fast `dart test`). Concrete theme colors live in
/// game/rendering/arrow_palette.dart.
enum ArrowColorId { purple, blue, green, orange, red }

extension ArrowColorIdX on ArrowColorId {
  static ArrowColorId fromName(String name) =>
      ArrowColorId.values.firstWhere((c) => c.name == name);
}

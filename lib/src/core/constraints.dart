import 'package:braid_ui/src/core/math.dart';

extension Constrained on Size {
  Size constrained(Constraints constraints) => Size(
        width.clamp(constraints.minWidth, constraints.maxWidth),
        height.clamp(constraints.minHeight, constraints.maxHeight),
      );
}

class Constraints {
  final double minWidth, minHeight;
  final double maxWidth, maxHeight;

  Constraints(this.minWidth, this.minHeight, this.maxWidth, this.maxHeight);

  Constraints.tight(Size size) : this(size.width, size.height, size.width, size.height);
  Constraints.loose(Size size) : this(0, 0, size.width, size.height);

  Constraints asLoose() => isLoose ? this : Constraints(0, 0, maxWidth, maxHeight);

  Constraints respecting(Constraints other) => Constraints(
        minWidth.clamp(other.minWidth, other.maxWidth),
        minHeight.clamp(other.minHeight, other.maxHeight),
        maxWidth.clamp(other.minWidth, other.maxWidth),
        maxHeight.clamp(other.minHeight, other.maxHeight),
      );

  bool get hasLooseWidth => minWidth == 0;
  bool get hasLooseHeight => minHeight == 0;
  bool get isLoose => hasBoundedWidth && hasLooseHeight;

  bool get isTight => minWidth == maxWidth && minHeight == maxHeight;

  bool get hasBoundedWidth => maxWidth < double.infinity;
  bool get hasBoundedHeight => maxHeight < double.infinity;

  @override
  bool operator ==(Object other) =>
      other is Constraints &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight;

  @override
  int get hashCode => Object.hash(minWidth, minHeight, maxWidth, maxHeight);
}

import 'math.dart';

extension ConstrainedSize on Size {
  Size constrained(Constraints constraints) => Size(
    width.clamp(constraints.minWidth, constraints.maxWidth),
    height.clamp(constraints.minHeight, constraints.maxHeight),
  );
}

class Constraints {
  final double minWidth, minHeight;
  final double maxWidth, maxHeight;

  const Constraints(this.minWidth, this.minHeight, this.maxWidth, this.maxHeight);

  const Constraints.only({double? minWidth, double? minHeight, double? maxWidth, double? maxHeight})
    : this(minWidth ?? 0, minHeight ?? 0, maxWidth ?? double.infinity, maxHeight ?? double.infinity);

  const Constraints.tightOnAxis({double? horizontal, double? vertical})
    : this.only(minWidth: horizontal, minHeight: vertical, maxWidth: horizontal, maxHeight: vertical);

  Constraints.tight(Size exactSize) : this(exactSize.width, exactSize.height, exactSize.width, exactSize.height);
  Constraints.loose(Size maxSize) : this(0, 0, maxSize.width, maxSize.height);

  Constraints asLoose() => isLoose ? this : Constraints(0, 0, maxWidth, maxHeight);

  Constraints copy({double? minWidth, double? minHeight, double? maxWidth, double? maxHeight}) => Constraints(
    minWidth ?? this.minWidth,
    minHeight ?? this.minHeight,
    maxWidth ?? this.maxWidth,
    maxHeight ?? this.maxHeight,
  );

  Constraints respecting(Constraints other) => Constraints(
    minWidth.clamp(other.minWidth, other.maxWidth),
    minHeight.clamp(other.minHeight, other.maxHeight),
    maxWidth.clamp(other.minWidth, other.maxWidth),
    maxHeight.clamp(other.minHeight, other.maxHeight),
  );

  bool get hasLooseWidth => minWidth == 0;
  bool get hasLooseHeight => minHeight == 0;
  bool get isLoose => hasLooseWidth && hasLooseHeight;

  bool get hasTightWidth => minWidth == maxWidth;
  bool get hasTightHeight => minHeight == maxHeight;
  bool get isTight => hasTightWidth && hasTightHeight;

  bool get hasBoundedWidth => maxWidth < double.infinity;
  bool get hasBoundedHeight => maxHeight < double.infinity;

  Size get minSize => Size(minWidth, minHeight);
  Size get maxSize => Size(maxWidth, maxHeight);

  @override
  bool operator ==(Object other) =>
      other is Constraints &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight;

  @override
  int get hashCode => Object.hash(minWidth, minHeight, maxWidth, maxHeight);

  @override
  String toString() =>
      'Constraints(minWidth=$minWidth, minHeight=$minHeight, maxWidth=$maxWidth, maxHeight=$maxHeight)';
}

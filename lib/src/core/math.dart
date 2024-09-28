class Size {
  static const Size zero = Size(0, 0);

  final double width, height;
  const Size(this.width, this.height);

  Size copy({double? width, double? height}) => Size(width ?? this.width, height ?? this.height);

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) => other is Size && other.width == width && other.height == height;
}

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

extension LerpDouble on double {
  double lerp(double delta, double other) => this + delta * (other - this);
}

extension LerpInt on int {
  int lerp(double delta, int other) => this + (delta * (other - this)).round();
}

class Size {
  static const Size zero = Size(0, 0);

  final double width, height;

  @literal
  const Size(this.width, this.height);

  @literal
  const Size.square(double size) : this(size, size);

  Size.max(Size a, Size b) : this(max(a.width, b.width), max(a.height, b.height));

  Size copy({double? width, double? height}) => Size(width ?? this.width, height ?? this.height);

  Size withInsets(Insets insets) => Size(width + insets.horizontal, height + insets.vertical);

  Size floor() => Size(width.floorToDouble(), height.floorToDouble());
  Size ceil() => Size(width.ceilToDouble(), height.ceilToDouble());

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) => other is Size && other.width == width && other.height == height;
}

class Insets {
  final double top, bottom, left, right;

  @literal
  const Insets({this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});
  @literal
  const Insets.all(double all) : this.axis(vertical: all, horizontal: all);
  @literal
  const Insets.axis({double vertical = 0, double horizontal = 0})
    : top = vertical,
      bottom = vertical,
      left = horizontal,
      right = horizontal;

  double get vertical => top + bottom;
  double get horizontal => left + right;

  Insets get inverted => Insets(top: -top, bottom: -bottom, left: -left, right: -right);

  Insets copy({double? top, double? bottom, double? left, double? right}) =>
      Insets(top: top ?? this.top, bottom: bottom ?? this.bottom, left: left ?? this.left, right: right ?? this.right);

  Insets operator +(Insets other) =>
      Insets(top: top + other.top, bottom: bottom + other.bottom, left: left + other.left, right: right + other.right);

  Insets operator -(Insets other) =>
      Insets(top: top - other.top, bottom: bottom - other.bottom, left: left - other.left, right: right - other.right);

  Insets operator *(Insets other) =>
      Insets(top: top * other.top, bottom: bottom * other.bottom, left: left * other.left, right: right * other.right);

  Insets operator /(Insets other) =>
      Insets(top: top / other.top, bottom: bottom / other.bottom, left: left / other.left, right: right / other.right);

  @override
  String toString() => 'Insets(top: $top, bottom: $bottom, left: $left, right: $right)';
}

class CornerRadius {
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;

  @literal
  const CornerRadius({this.topLeft = 0.0, this.topRight = 0.0, this.bottomLeft = 0.0, this.bottomRight = 0.0});

  @literal
  const CornerRadius.all(double radius)
    : this(topLeft: radius, topRight: radius, bottomLeft: radius, bottomRight: radius);

  @literal
  const CornerRadius.top(double radius) : this(topLeft: radius, topRight: radius);

  @literal
  const CornerRadius.left(double radius) : this(topLeft: radius, bottomLeft: radius);

  @literal
  const CornerRadius.bottom(double radius) : this(bottomLeft: radius, bottomRight: radius);

  @literal
  const CornerRadius.right(double radius) : this(topRight: radius, bottomRight: radius);

  CornerRadius copy({double? topLeft, double? topRight, double? bottomLeft, double? bottomRight}) => CornerRadius(
    topLeft: topLeft ?? this.topLeft,
    topRight: topRight ?? this.topRight,
    bottomLeft: bottomLeft ?? this.bottomLeft,
    bottomRight: bottomRight ?? this.bottomRight,
  );

  bool get isVanishing => topLeft < 1 && topRight < 1 && bottomLeft < 1 && bottomRight < 1;

  get _props => (topLeft, topRight, bottomLeft, bottomRight);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is CornerRadius && other._props == _props;
}

enum LayoutAxis {
  horizontal,
  vertical;

  T choose<T>(T horizontal, T vertical) => switch (this) {
    LayoutAxis.horizontal => horizontal,
    LayoutAxis.vertical => vertical,
  };

  T chooseCompute<T>(T Function() horizontal, T Function() vertical) => switch (this) {
    LayoutAxis.horizontal => horizontal(),
    LayoutAxis.vertical => vertical(),
  };

  Size createSize(double extent, double crossExtent) => switch (this) {
    LayoutAxis.horizontal => Size(extent, crossExtent),
    LayoutAxis.vertical => Size(crossExtent, extent),
  };

  LayoutAxis get opposite => switch (this) {
    LayoutAxis.horizontal => LayoutAxis.vertical,
    LayoutAxis.vertical => LayoutAxis.horizontal,
  };
}

// ---

extension Dimensions on Aabb3 {
  double get width => (this.max.x - this.min.x).abs();
  double get height => (this.max.y - this.min.y).abs();
}

class Matrix4Stack extends Matrix4 {
  final Queue<Float32List> _stack = Queue();

  Matrix4Stack.identity() : super.zero() {
    setIdentity();
  }

  void scopeWith(Matrix4 transform, void Function(Matrix4 mat4) action) => scope((mat4) {
    mat4.multiply(transform);
    action(mat4);
  });

  void scopedTransform(void Function(Matrix4 mat4) transformer, void Function(Matrix4 mat4) action) => scope((mat4) {
    transformer(mat4);
    action(mat4);
  });

  void scope(void Function(Matrix4 mat4) action) {
    push();
    action(this);
    pop();
  }

  void push([Matrix4? transform]) {
    _stack.add(Float32List.fromList(storage));

    if (transform != null) {
      multiply(transform);
    }
  }

  void pop() {
    storage.setAll(0, _stack.removeLast());
  }
}

double computeDelta(double current, double target, double delta) {
  double diff = target - current;
  delta = diff * delta;

  return delta.abs() > diff.abs() ? diff : delta;
}

extension Transform2 on Matrix4 {
  (double, double) transform2(double x, double y) {
    final vec = Vector3(x, y, 0);
    transform3(vec);
    return (vec.x, vec.y);
  }
}

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../core/math.dart';

abstract class Lerp<T> {
  static const _epsilon = 1e-4;

  final T start;
  final T end;

  const Lerp(this.start, this.end);

  T operator [](double t);

  @nonVirtual
  T compute(double t) {
    if (t - _epsilon <= 0) return start;
    if (t + _epsilon >= 1) return end;

    return this[t];
  }
}

// ---

class InsetsLerp extends Lerp<Insets> {
  const InsetsLerp(super.start, super.end);

  @override
  Insets operator [](double t) => Insets(
    top: start.top.lerp(t, end.top),
    bottom: start.bottom.lerp(t, end.bottom),
    left: start.left.lerp(t, end.left),
    right: start.right.lerp(t, end.right),
  );
}

class ColorLerp extends Lerp<Color> {
  const ColorLerp(super.start, super.end);

  @override
  Color operator [](double t) =>
      Color.values(start.r.lerp(t, end.r), start.g.lerp(t, end.g), start.b.lerp(t, end.b), start.a.lerp(t, end.a));
}

class DoubleLerp extends Lerp<double> {
  const DoubleLerp(super.start, super.end);

  @override
  double operator [](double t) => start.lerp(t, end);
}

import 'dart:math';

import 'package:meta/meta.dart';

typedef EasingFunction = double Function(double x);

abstract class Easing {
  static const Easing linear = _Easing(_linear);
  static const Easing inQuad = _Easing(_inQuad);
  static const Easing outQuad = _Easing(_outQuad);
  static const Easing inOutQuad = _Easing(_inOutQuad);
  static const Easing inCubic = _Easing(_inCubic);
  static const Easing outCubic = _Easing(_outCubic);
  static const Easing inOutCubic = _Easing(_inOutCubic);
  static const Easing inQuart = _Easing(_inQuart);
  static const Easing outQuart = _Easing(_outQuart);
  static const Easing inOutQuart = _Easing(_inOutQuart);
  static const Easing inQuint = _Easing(_inQuint);
  static const Easing outQuint = _Easing(_outQuint);
  static const Easing inOutQuint = _Easing(_inOutQuint);
  static const Easing inSine = _Easing(_inSine);
  static const Easing outSine = _Easing(_outSine);
  static const Easing inOutSine = _Easing(_inOutSine);
  static const Easing inExpo = _Easing(_inExpo);
  static const Easing outExpo = _Easing(_outExpo);
  static const Easing inOutExpo = _Easing(_inOutExpo);
  static const Easing inCirc = _Easing(_inCirc);
  static const Easing outCirc = _Easing(_outCirc);
  static const Easing inOutCirc = _Easing(_inOutCirc);

  // ---

  const Easing();

  double compute(double x);

  @nonVirtual
  double call(double x) {
    if (x == 0 || x == 1) return x;
    return compute(x);
  }
}

class _Easing extends Easing {
  final EasingFunction _function;
  const _Easing(this._function);

  @override
  double compute(double x) => _function(x);
}

double _linear(double x) => x;

double _inQuad(double x) => x * x;
double _outQuad(double x) => 1.0 - (1.0 - x) * (1.0 - x);
double _inOutQuad(double x) => x < 0.5 ? 2.0 * x * x : 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0;

double _inCubic(double x) => x * x * x;
double _outCubic(double x) => 1.0 - pow(1.0 - x, 3);
double _inOutCubic(double x) => x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0;

double _inQuart(double x) => x * x * x * x;
double _outQuart(double x) => 1.0 - pow(1.0 - x, 4.0);
double _inOutQuart(double x) => x < 0.5 ? 8.0 * x * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 4.0) / 2.0;

double _inQuint(double x) => x * x * x * x * x;
double _outQuint(double x) => 1.0 - pow(1.0 - x, 5.0);
double _inOutQuint(double x) => x < 0.5 ? 16.0 * x * x * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 5.0) / 2.0;

double _inSine(double x) => 1.0 - cos((x * pi) / 2.0);
double _outSine(double x) => sin((x * pi) / 2.0);
double _inOutSine(double x) => -(cos(pi * x) - 1) / 2.0;

double _inExpo(double x) => x == 0.0 ? 0.0 : pow(2.0, 10.0 * x - 10.0).toDouble();
double _outExpo(double x) => x == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
double _inOutExpo(double x) {
  return x == 0.0
      ? 0.0
      : x == 1.0
          ? 1.0
          : x < 0.5
              ? pow(2.0, 20.0 * x - 10.0) / 2.0
              : (2.0 - pow(2.0, -20.0 * x + 10.0)) / 2.0;
}

double _inCirc(double x) => 1.0 - sqrt(1.0 - pow(x, 2.0));
double _outCirc(double x) => sqrt(1.0 - pow(x - 1.0, 2.0));
double _inOutCirc(double x) =>
    x < 0.5 ? (1.0 - sqrt(1.0 - pow(2.0 * x, 2.0))) / 2 : (sqrt(1.0 - pow(-2.0 * x + 2.0, 2.0)) + 1.0) / 2.0;

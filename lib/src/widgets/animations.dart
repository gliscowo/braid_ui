import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';

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
  Color operator [](double t) => Color.values(
        start.r.lerp(t, end.r),
        start.g.lerp(t, end.g),
        start.b.lerp(t, end.b),
        start.a.lerp(t, end.a),
      );
}

class DoubleLerp extends Lerp<double> {
  const DoubleLerp(super.start, super.end);

  @override
  double operator [](double t) => start.lerp(t, end);
}

// ---

class AnimatedPadding extends AutomaticallyAnimatedWidget {
  final Insets insets;
  final Widget? child;

  const AnimatedPadding({
    super.key,
    required this.insets,
    required super.duration,
    this.child,
  });

  @override
  AutomaticallyAnimatedWidgetState<AnimatedPadding> createState() => _AnimatedPaddingState();
}

// ---

// TODO: customizable easing
abstract class AutomaticallyAnimatedWidget extends StatefulWidget {
  final Duration duration;

  const AutomaticallyAnimatedWidget({
    super.key,
    required this.duration,
  });

  @override
  AutomaticallyAnimatedWidgetState<AutomaticallyAnimatedWidget> createState();
}

typedef LerpFactory<T extends Lerp<V>, V> = T Function(V start, V end);
typedef _LerpVisitor<L extends Lerp<V>, V> = L Function(Lerp<V>? previous, V targetValue, LerpFactory<L, V> factory);

abstract class AutomaticallyAnimatedWidgetState<T extends AutomaticallyAnimatedWidget> extends WidgetState<T> {
  double _elapsedTime = 0;
  double _progress = 0;

  @protected
  double get animationValue => _progress;

  _LerpVisitor? _activeVisitor;

  @override
  void init() {
    _visitLerps((previous, targetValue, factory) {
      return factory(targetValue, targetValue);
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    var restartAnimation = false;
    _visitLerps((previous, targetValue, factory) {
      if (previous!.end != targetValue) {
        restartAnimation = true;
      }

      return previous;
    });

    if (restartAnimation) {
      _visitLerps((previous, targetValue, factory) => factory(previous!.compute(_progress), targetValue));

      _elapsedTime = 0;
      _progress = 0;
      scheduleAnimationCallback(_callback);
    }
  }

  void _visitLerps(_LerpVisitor visitor) {
    _activeVisitor = visitor;
    updateLerps();
  }

  void _callback(double delta) {
    _elapsedTime += delta;
    setState(() => _progress = min(1, Easings.expo(_elapsedTime / (widget.duration.inMilliseconds / 1000))));

    if (_progress + 1e-3 < 1) {
      scheduleAnimationCallback(_callback);
    } else {
      _progress = 1;
    }
  }

  // ---

  @protected
  L visitLerp<L extends Lerp<V>, V>(Lerp<V>? previous, V targetValue, LerpFactory<L, V> factory) {
    return _activeVisitor!.call(previous, targetValue, (start, end) => factory(start, end)) as L;
  }

  @protected
  void updateLerps();
}

class _AnimatedPaddingState extends AutomaticallyAnimatedWidgetState<AnimatedPadding> {
  InsetsLerp? _insets;

  @override
  void updateLerps() {
    _insets = visitLerp(_insets, widget.insets, InsetsLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      insets: _insets!.compute(animationValue),
      child: widget.child,
    );
  }
}

// ---

class AnimatedPanel extends AutomaticallyAnimatedWidget {
  final Color color;
  final double cornerRadius;
  final Widget? child;

  const AnimatedPanel({
    super.key,
    required super.duration,
    required this.color,
    this.cornerRadius = 0,
    this.child,
  });

  @override
  AutomaticallyAnimatedWidgetState<AutomaticallyAnimatedWidget> createState() => _AnimatedPanelState();
}

class _AnimatedPanelState extends AutomaticallyAnimatedWidgetState<AnimatedPanel> {
  ColorLerp? _color;
  DoubleLerp? _cornerRadius;

  @override
  void updateLerps() {
    _color = visitLerp(_color, widget.color, ColorLerp.new);
    _cornerRadius = visitLerp(_cornerRadius, widget.cornerRadius, DoubleLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: _color!.compute(animationValue),
      cornerRadius: _cornerRadius!.compute(animationValue),
      child: widget.child,
    );
  }
}

// ---

abstract final class Easings {
  static double linear(double x) => x;

  static double sine(double x) => sin(x * pi - pi / 2) * 0.5 + 0.5;

  static double quadratic(double x) => x < 0.5 ? 2 * x * x : (1 - pow(-2 * x + 2, 2) / 2);

  static double cubic(double x) => x < 0.5 ? 4 * x * x * x : (1 - pow(-2 * x + 2, 3) / 2);

  static double quartic(double x) => x < 0.5 ? 8 * x * x * x * x : (1 - pow(-2 * x + 2, 4) / 2);

  static double expo(double x) {
    if (x == 0) return 0;
    if (x == 1) return 1;

    return x < 0.5 ? pow(2, 20 * x - 10) / 2 : (2 - pow(2, -20 * x + 10)) / 2;
  }
}

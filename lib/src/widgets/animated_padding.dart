import 'dart:math';

import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';

class AnimatedPadding extends StatefulWidget {
  final Insets insets;
  final Duration duration;
  final Widget? child;

  const AnimatedPadding({
    super.key,
    required this.insets,
    required this.duration,
    this.child,
  });

  @override
  WidgetState<StatefulWidget> createState() => _AnimatedPaddingState();
}

class _AnimatedPaddingState extends WidgetState<AnimatedPadding> {
  Insets? _oldInsets;
  late Insets _currentInsets;

  double _elapsedTime = 0;
  double _progress = 0;

  @override
  void init() {
    _currentInsets = widget.insets;
  }

  @override
  void didUpdateWidget(AnimatedPadding oldWidget) {
    if (widget.insets == oldWidget.insets) {
      return;
    }

    _oldInsets = _currentInsets;
    _elapsedTime = 0;
    _progress = 0;
    scheduleAnimationCallback(_callback);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      insets: _currentInsets,
      child: widget.child,
    );
  }

  void _callback(double delta) {
    _elapsedTime += delta;
    setState(() {
      _progress = min(1, Easings.expo(_elapsedTime / (widget.duration.inMilliseconds / 1000)));

      _currentInsets = Insets(
        top: _oldInsets!.top.lerp(_progress, widget.insets.top),
        bottom: _oldInsets!.bottom.lerp(_progress, widget.insets.bottom),
        left: _oldInsets!.left.lerp(_progress, widget.insets.left),
        right: _oldInsets!.right.lerp(_progress, widget.insets.right),
      );
    });

    if (_progress + 1e-3 < 1) {
      scheduleAnimationCallback(_callback);
    } else {
      _progress = 1;
    }
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

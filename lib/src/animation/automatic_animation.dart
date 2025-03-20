import 'dart:math';

import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'easings.dart';
import 'lerp.dart';

abstract class AutomaticallyAnimatedWidget extends StatefulWidget {
  final Duration duration;
  final Easing easing;

  const AutomaticallyAnimatedWidget({super.key, this.easing = Easing.linear, required this.duration});

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
    var restartAnimation = widget.easing != oldWidget.easing;
    if (!restartAnimation) {
      _visitLerps((previous, targetValue, factory) {
        if (previous!.end != targetValue) {
          restartAnimation = true;
        }

        return previous;
      });
    }

    if (restartAnimation) {
      print('starting animation');
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
    setState(() => _progress = min(1, widget.easing(_elapsedTime / (widget.duration.inMilliseconds / 1000))));

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

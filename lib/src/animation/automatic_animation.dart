import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'animation.dart';
import 'easings.dart';
import 'lerp.dart';

abstract class AutomaticallyAnimatedWidget extends StatefulWidget {
  final Duration duration;
  final Easing easing;

  const AutomaticallyAnimatedWidget({super.key, this.easing = Easing.linear, required this.duration});

  @override
  AutomaticallyAnimatedWidgetState<AutomaticallyAnimatedWidget> createState();
}

typedef _LerpVisitor<L extends Lerp<V>, V> = L Function(Lerp<V>? previous, V targetValue, LerpFactory<L, V> factory);

abstract class AutomaticallyAnimatedWidgetState<T extends AutomaticallyAnimatedWidget> extends WidgetState<T> {
  late Animation _animation;
  _LerpVisitor? _activeVisitor;

  void _callback(double progress) => setState(() {});

  @override
  void init() {
    _animation = Animation(
      easing: widget.easing,
      duration: widget.duration,
      scheduler: scheduleAnimationCallback,
      listener: _callback,
      startFrom: AnimationTarget.end,
    );

    _visitLerps((previous, targetValue, factory) {
      return factory(targetValue, targetValue);
    });
  }

  @override
  void didUpdateWidget(T oldWidget) {
    var restartAnimation = widget.easing != oldWidget.easing;
    _animation.duration = widget.duration;

    if (!restartAnimation) {
      _visitLerps((previous, targetValue, factory) {
        if (previous!.end != targetValue) {
          restartAnimation = true;
        }

        return previous;
      });
    }

    if (restartAnimation) {
      _visitLerps((previous, targetValue, factory) => factory(previous!.compute(_animation.value), targetValue));
      _animation.easing = widget.easing;
      _animation.towards(AnimationTarget.end);
    }
  }

  void _visitLerps(_LerpVisitor visitor) {
    _activeVisitor = visitor;
    updateLerps();
  }

  // ---

  @protected
  double get animationValue => _animation.value;

  @protected
  L visitLerp<L extends Lerp<V>, V>(Lerp<V>? previous, V targetValue, LerpFactory<L, V> factory) {
    return _activeVisitor!.call(previous, targetValue, (start, end) => factory(start, end)) as L;
  }

  @protected
  Lerp<V?> visitNullableLerp<V>(Lerp<V?>? previous, V? targetValue, LerpFactory<Lerp<V>, V> factory) {
    return _activeVisitor!.call(previous, targetValue, (start, end) => NullableLerp<V>(start, end, factory))
        as Lerp<V?>;
  }

  @protected
  void updateLerps();
}

import '../framework/proxy.dart';
import 'easings.dart';

typedef AnimationListener = void Function(double progress);
typedef CallbackScheduler = void Function(AnimationCallback callback);

enum AnimationTarget {
  start(-1, 0),
  end(1, 1);

  final double direction;
  final double progress;

  const AnimationTarget(this.direction, this.progress);
}

class Animation {
  final CallbackScheduler _scheduler;
  final AnimationListener listener;

  Easing easing;
  Duration duration;

  double _progress;
  AnimationTarget? _target;

  Animation({
    required this.easing,
    required this.duration,
    required CallbackScheduler scheduler,
    required this.listener,
    AnimationTarget startFrom = AnimationTarget.start,
  }) : _scheduler = scheduler,
       _progress = startFrom.progress;

  double get value => easing(_progress);

  void towards(AnimationTarget target, {bool restart = true}) {
    if (restart) {
      _progress = 1 - target.progress;
    }

    if (_target == null) {
      _scheduler(_callback);
    }

    _target = target;
  }

  void pause() {
    _target = null;
  }

  void stop({AnimationTarget? at}) {
    if (_target == null && at == null) return;

    _progress = at?.progress ?? _target!.progress;
    _target = null;
  }

  void _callback(Duration delta) {
    if (_target == null) return;

    _progress = (_progress + _target!.direction * delta.inMicroseconds / duration.inMicroseconds).clamp(0, 1);
    if ((_progress - _target!.progress).abs() > 1e-3) {
      _scheduler(_callback);
    } else {
      _progress = _target!.progress;
      _target = null;
    }

    listener(value);
  }
}

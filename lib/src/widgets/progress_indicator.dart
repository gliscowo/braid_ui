import 'dart:math';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'theme.dart';

class ProgressIndicator extends StatefulWidget {
  final double? progress;

  const ProgressIndicator({super.key, double min = 0, double max = 1, required double progress})
    : progress = (progress - min) / (max - min);

  const ProgressIndicator.indeterminate({super.key}) : progress = null;

  bool get indeterminate => progress == null;

  @override
  WidgetState<ProgressIndicator> createState() => _ProgressIndicatorState();
}

class _ProgressIndicatorState extends WidgetState<ProgressIndicator> {
  double time = 0;

  @override
  void init() {
    if (widget.indeterminate) _trackTime(Duration.zero);
  }

  @override
  void didUpdateWidget(ProgressIndicator oldWidget) {
    if (!oldWidget.indeterminate && widget.indeterminate) {
      _trackTime(Duration.zero);
    }
  }

  void _trackTime(Duration delta) {
    setState(() => time += delta.inMicroseconds / Duration.microsecondsPerSecond);

    if (widget.indeterminate) scheduleAnimationCallback(_trackTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BraidTheme.of(context);
    double offset;
    double progress;

    if (widget.indeterminate) {
      offset = time;
      progress = 1 / 3;
    } else {
      offset = 0;
      progress = widget.progress!;
    }

    return Sized(
      width: 20,
      height: 20,
      child: CustomDraw(
        drawFunction: (ctx, transform) {
          ctx.transform.scope((mat4) {
            ctx.primitives.circle(
              transform.width / 2,
              theme.elevatedColor,
              ctx.transform,
              ctx.projection,
              innerRadius: transform.width / 2 - 3,
            );

            ctx.primitives.circle(
              transform.width / 2,
              theme.elementColor,
              ctx.transform,
              ctx.projection,
              innerRadius: transform.width / 2 - 3,
              toAngle: progress * 2 * pi,
              angleOffset: offset * 2 * pi,
            );
          });
        },
      ),
    );
  }
}

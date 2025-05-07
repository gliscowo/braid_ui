import 'dart:math';

import '../../braid_ui.dart';

class SpinningIndicator extends StatefulWidget {
  const SpinningIndicator({super.key});

  @override
  WidgetState<SpinningIndicator> createState() => _SpinningIndicatorState();
}

class _SpinningIndicatorState extends WidgetState<SpinningIndicator> {
  double time = 0;
  List<double> heights = List.filled(3, 0);

  @override
  void init() {
    _updateHeights(0);
  }

  @override
  Widget build(BuildContext context) {
    final color = BraidTheme.of(context).elementColor;
    return Sized(
      width: 8 * (heights.length) + 5 * (heights.length - 1),
      height: 20,
      child: CustomDraw(
        drawFunction: (ctx, transform) {
          ctx.transform.scope((mat4) {
            for (var i = 0; i < heights.length; i++) {
              ctx.transform.scope((mat4) {
                final height = 8 + heights[i] * (transform.height - 8);
                final offset = (transform.height - height) / 2;

                mat4.translate(0.0, offset);

                ctx.primitives.roundedRect(8, height, const CornerRadius.all(4), color, mat4, ctx.projection);
              });
              mat4.translate(8.0 + 5.0);
            }
          });
        },
      ),
    );
  }

  void _updateHeights(double delta) {
    scheduleAnimationCallback(_updateHeights);

    time += delta * 5;
    setState(() {
      for (var i = 0; i < heights.length; i++) {
        heights[i] = (sin(time + i) + 1) / 2;
      }
    });
  }
}

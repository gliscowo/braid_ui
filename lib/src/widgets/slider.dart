import 'package:diamond_gl/diamond_gl.dart';

import '../../braid_ui.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'layout_builder.dart';
import 'stack.dart';

class Slider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double? step;
  final LayoutAxis axis;
  final void Function(double value) onUpdate;

  const Slider({
    super.key,
    this.min = 0,
    this.max = 1,
    this.step,
    this.axis = LayoutAxis.horizontal,
    required this.value,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return RawSlider(
      min: min,
      max: max,
      step: step,
      value: value,
      axis: axis,
      onUpdate: onUpdate,
      handle: const _KnobHandle(),
    );
  }
}

class _KnobHandle extends StatefulWidget {
  const _KnobHandle();

  @override
  WidgetState<_KnobHandle> createState() => _KnobHandleState();
}

class _KnobHandleState extends WidgetState<_KnobHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      enterCallback: () => _hovered = true,
      exitCallback: () => _hovered = false,
      child: CustomDraw(
        drawFunction: (ctx, transform) {
          ctx.primitives.circle(
            transform.width / 2,
            _hovered ? const Color.rgb(0x684fb3) : const Color.rgb(0x5f43b2),
            ctx.transform,
            ctx.projection,
          );
        },
      ),
    );
  }
}

class RawSlider extends StatelessWidget {
  final double min;
  final double max;
  final double? step;
  final double normalizedValue;
  final LayoutAxis axis;
  final void Function(double) onUpdate;
  final Widget handle;

  RawSlider({
    super.key,
    required this.min,
    required this.max,
    required this.step,
    required double value,
    required this.axis,
    required this.onUpdate,
    required this.handle,
  }) : normalizedValue = ((value - min) / (max - min)).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseArea(
            cursorStyle: CursorStyle.hand,
            clickCallback: (x, y) => _updateForInput(constraints, x, y),
            dragCallback: (x, y, dx, dy) => _updateForInput(constraints, x, y),
            child: Stack(
              alignment: axis.choose(Alignment.left, Alignment.top),
              children: [
                Sized(
                  width: axis.choose(constraints.maxWidth, 3),
                  height: axis.choose(3, constraints.maxHeight),
                  child: Padding(
                    insets: axis.choose(
                      const Insets.axis(horizontal: _handleRadius),
                      const Insets.axis(vertical: _handleRadius),
                    ),
                    child: Panel(cornerRadius: const CornerRadius.all(2), color: Color.rgb(0xb1aebb)),
                  ),
                ),
                Padding(
                  insets: axis.chooseCompute(
                    () => Insets(left: normalizedValue * (constraints.maxWidth - _handleRadius * 2)),
                    () => Insets(top: normalizedValue * (constraints.maxHeight - _handleRadius * 2)),
                  ),
                  child: Sized(width: _handleRadius * 2, height: _handleRadius * 2, child: handle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateForInput(Constraints constraints, double x, double y) {
    final newNormalizedValue = ((axis.choose(x, y) - _handleRadius) / (constraints.maxOnAxis(axis) - _handleRadius * 2))
        .clamp(0, 1);
    final newValue = min + newNormalizedValue * (max - min);

    onUpdate(step != null ? (newValue / step!).roundToDouble() * step! : newValue);
  }

  static const _handleRadius = 10.0;
}

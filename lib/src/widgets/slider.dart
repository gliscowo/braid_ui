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
  final void Function(double value) onUpdate;

  const Slider({super.key, this.min = 0, this.max = 1, required this.value, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return RawSlider(min: min, max: max, value: value, onUpdate: onUpdate, handle: const _KnobHandle());
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
  final double normalizedValue;
  final void Function(double) onUpdate;
  final Widget handle;

  RawSlider({
    super.key,
    required this.min,
    required this.max,
    required double value,
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
              alignment: Alignment.left,
              children: [
                Sized(
                  width: constraints.maxWidth,
                  height: 3,
                  child: Padding(
                    insets: const Insets.axis(horizontal: _handleRadius),
                    child: Panel(cornerRadius: const CornerRadius.all(2), color: Color.rgb(0xb1aebb)),
                  ),
                ),
                Padding(
                  insets: Insets(left: normalizedValue * (constraints.maxWidth - _handleRadius * 2)),
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
    final newNormalizedValue = ((x - _handleRadius) / (constraints.maxWidth - _handleRadius * 2)).clamp(0, 1);
    onUpdate(min + newNormalizedValue * (max - min));
  }

  static const _handleRadius = 10.0;
}

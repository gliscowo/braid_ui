import '../../braid_ui.dart';

class SliderStyle {
  final double? trackThickness;
  final Color? trackColor;
  final Color? trackDisabledColor;

  final double? handleSize;
  final Color? handleColor;
  final Color? handleHighlightColor;
  final Color? handleDisabledColor;

  const SliderStyle({
    this.trackThickness,
    this.trackColor,
    this.trackDisabledColor,
    this.handleSize,
    this.handleColor,
    this.handleHighlightColor,
    this.handleDisabledColor,
  });

  SliderStyle copy({
    double? trackThickness,
    Color? trackColor,
    Color? trackDisabledColor,
    double? handleSize,
    Color? handleColor,
    Color? handleHighlightColor,
    Color? handleDisabledColor,
  }) => SliderStyle(
    trackThickness: trackThickness ?? this.trackThickness,
    trackColor: trackColor ?? this.trackColor,
    trackDisabledColor: trackDisabledColor ?? this.trackDisabledColor,
    handleSize: handleSize ?? this.handleSize,
    handleColor: handleColor ?? this.handleColor,
    handleHighlightColor: handleHighlightColor ?? this.handleHighlightColor,
    handleDisabledColor: handleDisabledColor ?? this.handleDisabledColor,
  );

  SliderStyle overriding(SliderStyle other) => SliderStyle(
    trackThickness: trackThickness ?? other.trackThickness,
    trackColor: trackColor ?? other.trackColor,
    trackDisabledColor: trackDisabledColor ?? other.trackDisabledColor,
    handleSize: handleSize ?? other.handleSize,
    handleColor: handleColor ?? other.handleColor,
    handleHighlightColor: handleHighlightColor ?? other.handleHighlightColor,
    handleDisabledColor: handleDisabledColor ?? other.handleDisabledColor,
  );

  get _props => (
    trackThickness,
    trackColor,
    trackDisabledColor,
    handleSize,
    handleColor,
    handleHighlightColor,
    handleDisabledColor,
  );

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is SliderStyle && other._props == _props;
}

class Slider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double? step;
  final LayoutAxis axis;
  final SliderStyle? style;
  final void Function(double value)? onUpdate;

  const Slider({
    super.key,
    this.min = 0,
    this.max = 1,
    this.step,
    this.axis = LayoutAxis.horizontal,
    this.style,
    required this.value,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onUpdate != null;

    final contextStyle = DefaultSliderStyle.of(context);
    final style = this.style?.overriding(contextStyle) ?? contextStyle;

    return RawSlider(
      min: min,
      max: max,
      step: step,
      value: value,
      axis: axis,
      onUpdate: onUpdate,
      style: style,
      track: Panel(
        cornerRadius: const CornerRadius.all(2),
        color: enabled ? style.trackColor! : style.trackDisabledColor!,
      ),
      handle: _DefaultHandle(
        color: enabled ? style.handleColor! : style.handleDisabledColor!,
        highlightColor: enabled ? style.handleHighlightColor! : style.handleDisabledColor!,
      ),
    );
  }
}

class _DefaultHandle extends StatefulWidget {
  final Color color;
  final Color highlightColor;

  const _DefaultHandle({required this.color, required this.highlightColor});

  @override
  WidgetState<_DefaultHandle> createState() => _DefaultHandleState();
}

class _DefaultHandleState extends WidgetState<_DefaultHandle> {
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
            _hovered ? widget.highlightColor : widget.color,
            ctx.transform,
            ctx.projection,
          );
        },
      ),
    );
  }
}

class DefaultSliderStyle extends InheritedWidget {
  final SliderStyle style;

  DefaultSliderStyle({super.key, required this.style, required super.child});

  static Widget merge({required SliderStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultSliderStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

  @override
  bool mustRebuildDependents(covariant DefaultSliderStyle newWidget) => newWidget.style != style;

  // ---

  static SliderStyle of(BuildContext context) {
    final widget = context.dependOnAncestor<DefaultSliderStyle>();
    assert(widget != null, 'expected an ambient DefaultSliderStyle');

    return widget!.style;
  }
}

class RawSlider extends StatefulWidget {
  final double min;
  final double max;
  final double? step;
  final double normalizedValue;
  final LayoutAxis axis;
  final void Function(double)? onUpdate;
  final SliderStyle style;
  final Widget? track;
  final Widget handle;

  RawSlider({
    super.key,
    required this.min,
    required this.max,
    required this.step,
    required double value,
    required this.axis,
    required this.onUpdate,
    required this.style,
    required this.track,
    required this.handle,
  }) : normalizedValue = ((value - min) / (max - min)).clamp(0, 1);

  @override
  WidgetState<RawSlider> createState() => _RawSliderState();
}

class _RawSliderState extends WidgetState<RawSlider> {
  double dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final axis = widget.axis;

    final handleSize = style.handleSize!;
    final enabled = widget.onUpdate != null;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseArea(
            cursorStyle: enabled ? CursorStyle.hand : null,
            clickCallback: enabled
                ? (x, y, _) {
                    y = axis == LayoutAxis.vertical ? constraints.maxOnAxis(axis) - y : y;
                    if (!isInHandle(constraints, x, y)) {
                      setAbsolute(constraints, x, y);
                    }

                    return true;
                  }
                : null,
            dragCallback: enabled
                ? (x, y, dx, dy) {
                    move(constraints, dx, axis == LayoutAxis.vertical ? -dy : dy);
                  }
                : null,
            dragStartCallback: (_) => dragValue = widget.normalizedValue,
            child: Stack(
              alignment: axis.choose(Alignment.left, Alignment.top),
              children: [
                Sized(
                  width: axis.choose(constraints.maxWidth, style.trackThickness!),
                  height: axis.choose(style.trackThickness!, constraints.maxHeight),
                  child: Padding(
                    insets: axis.choose(Insets.axis(horizontal: handleSize / 2), Insets.axis(vertical: handleSize / 2)),
                    child: widget.track,
                  ),
                ),
                Padding(
                  insets: axis.chooseCompute(
                    () => Insets(left: widget.normalizedValue * (constraints.maxWidth - handleSize)),
                    () => Insets(top: (1 - widget.normalizedValue) * (constraints.maxHeight - handleSize)),
                  ),
                  child: Sized(width: handleSize, height: handleSize, child: widget.handle),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool isInHandle(Constraints constraints, double x, double y) {
    final axis = widget.axis;

    final trackLength = constraints.maxOnAxis(axis) - widget.style.handleSize!;
    final handleMin = widget.normalizedValue * trackLength;
    final handleMax = handleMin + widget.style.handleSize!;

    final coordinate = axis.choose(x, y);
    return coordinate >= handleMin && coordinate <= handleMax;
  }

  void move(Constraints constraints, double dx, double dy) {
    dragValue += widget.axis.choose(dx, dy) / (constraints.maxOnAxis(widget.axis) - widget.style.handleSize!);

    applyValue(dragValue.clamp(0, 1));
  }

  void setAbsolute(Constraints constraints, double x, double y) {
    if (widget.onUpdate == null) return;

    final axis = widget.axis;
    final handleSize = widget.style.handleSize!;

    var newNormalizedValue = ((axis.choose(x, y) - handleSize / 2) / (constraints.maxOnAxis(axis) - handleSize))
        .clamp(0, 1)
        .toDouble();

    applyValue(newNormalizedValue);
  }

  void applyValue(double newNormalizedValue) {
    final step = widget.step;
    final newValue = widget.min + newNormalizedValue * (widget.max - widget.min);
    widget.onUpdate!(step != null ? (newValue / step).roundToDouble() * step : newValue);
  }
}

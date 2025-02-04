// TODO: separate theme and widget, use theme directly in [Button]
// TODO: descendant->ancestor layout dependencies

import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import '../text/text.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'widget.dart';
import 'widget_base.dart';

class ButtonStyleHost extends SingleChildWidget with ShrinkWrapLayout {
  ButtonStyle style;

  ButtonStyleHost({
    required this.style,
    required super.child,
  });
}

class ButtonStyle {
  static const empty = ButtonStyle();

  final Color? color;
  final Color? hoveredColor;
  final Color? disabledColor;
  final Color? textColor;
  final Insets? padding;
  final double? cornerRadius;

  const ButtonStyle({
    this.color,
    this.hoveredColor,
    this.disabledColor,
    this.textColor,
    this.padding,
    this.cornerRadius,
  });

  ButtonStyle copy({
    Color? color,
    Color? hoveredColor,
    Color? disabledColor,
    Color? textColor,
    Insets? padding,
    double? cornerRadius,
  }) =>
      ButtonStyle(
        color: color ?? this.color,
        hoveredColor: hoveredColor ?? this.hoveredColor,
        disabledColor: disabledColor ?? this.disabledColor,
        textColor: textColor ?? this.textColor,
        padding: padding ?? this.padding,
        cornerRadius: cornerRadius ?? this.cornerRadius,
      );

  ButtonStyle overriding(ButtonStyle other) => ButtonStyle(
        color: color ?? other.color,
        hoveredColor: hoveredColor ?? other.hoveredColor,
        disabledColor: disabledColor ?? other.disabledColor,
        textColor: textColor ?? other.textColor,
        padding: padding ?? other.padding,
        cornerRadius: cornerRadius ?? other.cornerRadius,
      );

  @override
  int get hashCode => Object.hash(color, hoveredColor, disabledColor, textColor, padding, cornerRadius);

  @override
  bool operator ==(Object other) =>
      other is ButtonStyle &&
      other.color == color &&
      other.hoveredColor == hoveredColor &&
      other.disabledColor == disabledColor &&
      other.textColor == textColor &&
      other.padding == padding &&
      other.cornerRadius == cornerRadius;
}

// TODO: actually usable default style
class Button extends SingleChildWidget with ShrinkWrapLayout {
  late Panel _panel;
  late Padding _padding;
  late Label _label;
  late MouseArea _mouseArea;

  void Function(Button button) onClick;
  ButtonStyle _style;
  ButtonStyle? _contextStyle;

  bool _enabled;

  Button({
    required Text text,
    required this.onClick,
    bool enabled = true,
    ButtonStyle style = ButtonStyle.empty,
  })  : _style = style,
        _enabled = enabled,
        super.lateChild() {
    initChild(_mouseArea = MouseArea(
      child: _panel = Panel(
        cornerRadius: _computedStyle.cornerRadius ?? _defaultCornerRadius,
        color: _computedStyle.color ?? _defaultColor,
        child: _padding = Padding(
          insets: _computedStyle.padding ?? _defaultPadding,
          // TODO make the inner widget customizable
          child: _label = Label(
            text: text,
            textColor: _computedStyle.textColor ?? _defaultTextColor,
            fontSize: 20.0,
            lineHeight: 1,
          ),
        ),
      ),
      clickCallback: () {
        if (_enabled) onClick(this);
      },
      enterCallback: () {
        if (_enabled) _panel.color = _computedStyle.hoveredColor ?? _defaultHoveredColor;
      },
      exitCallback: () {
        if (_enabled) _panel.color = _computedStyle.color ?? _defaultColor;
      },
      cursorStyle: CursorStyle.hand,
    ));
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    super.doLayout(ctx, constraints);

    final theme = ancestorOfType<ButtonStyleHost>();
    if (theme != null) {
      _contextStyle = theme.style;
      _applyComputedStyle();
    }
  }

  ButtonStyle get _computedStyle => _contextStyle != null ? _style.overriding(_contextStyle!) : _style;

  void _applyComputedStyle() {
    final computedStyle = _computedStyle;
    _padding.insets = computedStyle.padding ?? _defaultPadding;
    _label.textColor = computedStyle.textColor ?? _defaultTextColor;
    _panel.cornerRadius = computedStyle.cornerRadius ?? _defaultCornerRadius;
    _applyPanelColor(computedStyle);
  }

  void _applyPanelColor(ButtonStyle style) {
    _panel.color = _enabled
        ? _mouseArea.hovered
            ? (style.hoveredColor ?? _defaultHoveredColor)
            : (style.color ?? _defaultColor)
        : (style.disabledColor ?? _defaultDisabledColor);
  }

  ButtonStyle get style => _style;
  set style(ButtonStyle value) {
    if (_style == value) return;

    _style = value;
    _applyComputedStyle();
  }

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;

    _enabled = value;
    _applyPanelColor(_computedStyle);
  }

  Text get text => _label.text;
  set text(Text value) => _label.text = value;

  // ---

  static final _defaultColor = Color.ofRgb(0x3867d6);
  static final _defaultHoveredColor = Color.ofRgb(0x4b7bec);
  static final _defaultDisabledColor = Color.ofRgb(0x4b6584);
  static final _defaultTextColor = Color.white;
  static final _defaultPadding = Insets.all(3.0);
  static final _defaultCornerRadius = 3.0;
}

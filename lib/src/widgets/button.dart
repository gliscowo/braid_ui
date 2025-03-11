// TODO: descendant->ancestor layout dependencies

import 'package:diamond_gl/diamond_gl.dart';

import '../../braid_ui.dart';
import '../immediate/foundation.dart';

// class ButtonStyleHost extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   ButtonStyle style;

//   ButtonStyleHost({
//     required this.style,
//     required super.child,
//   });
// }

class ButtonStyle {
  static const empty = ButtonStyle();

  final Color? color;
  final Color? hoveredColor;
  final Color? disabledColor;
  final Insets? padding;
  final double? cornerRadius;

  const ButtonStyle({
    this.color,
    this.hoveredColor,
    this.disabledColor,
    this.padding,
    this.cornerRadius,
  });

  ButtonStyle copy({
    Color? color,
    Color? hoveredColor,
    Color? disabledColor,
    Insets? padding,
    double? cornerRadius,
  }) =>
      ButtonStyle(
        color: color ?? this.color,
        hoveredColor: hoveredColor ?? this.hoveredColor,
        disabledColor: disabledColor ?? this.disabledColor,
        padding: padding ?? this.padding,
        cornerRadius: cornerRadius ?? this.cornerRadius,
      );

  ButtonStyle overriding(ButtonStyle other) => ButtonStyle(
        color: color ?? other.color,
        hoveredColor: hoveredColor ?? other.hoveredColor,
        disabledColor: disabledColor ?? other.disabledColor,
        padding: padding ?? other.padding,
        cornerRadius: cornerRadius ?? other.cornerRadius,
      );

  @override
  int get hashCode => Object.hash(color, hoveredColor, disabledColor, padding, cornerRadius);

  @override
  bool operator ==(Object other) =>
      other is ButtonStyle &&
      other.color == color &&
      other.hoveredColor == hoveredColor &&
      other.disabledColor == disabledColor &&
      other.padding == padding &&
      other.cornerRadius == cornerRadius;
}

class Button extends StatefulWidget {
  final void Function() onClick;
  final ButtonStyle style;
  final bool enabled;
  final Widget child;

  const Button({
    super.key,
    this.style = ButtonStyle.empty,
    this.enabled = true,
    required this.onClick,
    required this.child,
  });

  Button.text({
    Key? key,
    ButtonStyle style = ButtonStyle.empty,
    bool enabled = true,
    required void Function() onClick,
    required String text,
  }) : this(key: key, style: style, enabled: enabled, onClick: onClick, child: Label(text: text));

  @override
  WidgetState createState() => ButtonState();
}

class ButtonState extends WidgetState<Button> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      cursorStyle: CursorStyle.hand,
      clickCallback: widget.onClick,
      enterCallback: () => setState(() => _hovered = true),
      exitCallback: () => setState(() => _hovered = false),
      child: Panel(
        cornerRadius: widget.style.cornerRadius ?? _defaultCornerRadius,
        color: widget.enabled
            ? _hovered
                ? widget.style.hoveredColor ?? _defaultHoveredColor
                : _defaultColor
            : _defaultDisabledColor,
        child: Padding(
          insets: widget.style.padding ?? _defaultPadding,
          child: widget.child,
        ),
      ),
    );
  }

  static final _defaultColor = Color.ofRgb(0x3867d6);
  static final _defaultHoveredColor = Color.ofRgb(0x4b7bec);
  static final _defaultDisabledColor = Color.ofRgb(0x4b6584);
  static final _defaultPadding = const Insets.all(3.0);
  static final _defaultCornerRadius = 3.0;
}

// class Button extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   late PanelInstance _panel;
//   late PaddingInstance _padding;
//   late MouseArea _mouseArea;

//   void Function(Button button) onClick;
//   ButtonStyle _style;
//   ButtonStyle? _contextStyle;

//   bool _enabled;

//   Button.text({
//     bool enabled = true,
//     ButtonStyle style = ButtonStyle.empty,
//     required String text,
//     required void Function(Button button) onClick,
//   }) : this(
//           enabled: enabled,
//           style: style,
//           child: LabelInstance(text: text),
//           onClick: onClick,
//         );

//   Button({
//     bool enabled = true,
//     ButtonStyle style = ButtonStyle.empty,
//     required WidgetInstance child,
//     required this.onClick,
//   })  : _style = style,
//         _enabled = enabled,
//         super.lateChild() {
//     initChild(_mouseArea = MouseArea(
//       child: _panel = PanelInstance(
//         cornerRadius: _computedStyle.cornerRadius ?? _defaultCornerRadius,
//         color: _computedStyle.color ?? _defaultColor,
//         child: _padding = PaddingInstance(
//           insets: _computedStyle.padding ?? _defaultPadding,
//           child: child,
//         ),
//       ),
//       clickCallback: () {
//         if (_enabled) onClick(this);
//       },
//       enterCallback: () {
//         if (_enabled) _panel.color = _computedStyle.hoveredColor ?? _defaultHoveredColor;
//       },
//       exitCallback: () {
//         if (_enabled) _panel.color = _computedStyle.color ?? _defaultColor;
//       },
//       cursorStyle: CursorStyle.hand,
//     ));
//   }

//   @override
//   set child(WidgetInstance widget) {
//     _padding.child = widget;
//   }

//   @override
//   void doLayout(LayoutContext ctx, Constraints constraints) {
//     super.doLayout(ctx, constraints);

//     final theme = ancestorOfType<ButtonStyleHost>();
//     if (theme != null) {
//       _contextStyle = theme.style;
//       _applyComputedStyle();
//     }
//   }

//   ButtonStyle get _computedStyle => _contextStyle != null ? _style.overriding(_contextStyle!) : _style;

//   void _applyComputedStyle() {
//     final computedStyle = _computedStyle;
//     _padding.insets = computedStyle.padding ?? _defaultPadding;
//     _panel.cornerRadius = computedStyle.cornerRadius ?? _defaultCornerRadius;
//     _applyPanelColor(computedStyle);
//   }

//   void _applyPanelColor(ButtonStyle style) {
//     _panel.color = _enabled
//         ? _mouseArea.hovered
//             ? (style.hoveredColor ?? _defaultHoveredColor)
//             : (style.color ?? _defaultColor)
//         : (style.disabledColor ?? _defaultDisabledColor);
//   }

//   ButtonStyle get style => _style;
//   set style(ButtonStyle value) {
//     if (_style == value) return;

//     _style = value;
//     _applyComputedStyle();
//   }

//   bool get enabled => _enabled;
//   set enabled(bool value) {
//     if (_enabled == value) return;

//     _enabled = value;
//     _applyPanelColor(_computedStyle);
//   }

//   // ---

//   static final _defaultColor = Color.ofRgb(0x3867d6);
//   static final _defaultHoveredColor = Color.ofRgb(0x4b7bec);
//   static final _defaultDisabledColor = Color.ofRgb(0x4b6584);
//   static final _defaultPadding = Insets.all(3.0);
//   static final _defaultCornerRadius = 3.0;
// }

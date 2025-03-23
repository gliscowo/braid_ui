import 'package:diamond_gl/diamond_gl.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'label.dart';

class DefaultButtonStyle extends InheritedWidget {
  final ButtonStyle style;

  DefaultButtonStyle({required this.style, required super.child});

  @override
  bool mustRebuildDependents(DefaultButtonStyle newWidget) => newWidget.style != style;

  static ButtonStyle? maybeOf(BuildContext context) => context.dependOnAncestor<DefaultButtonStyle>()?.style;
}

class ButtonStyle {
  static const empty = ButtonStyle();

  final Color? color;
  final Color? hoveredColor;
  final Color? disabledColor;
  final Insets? padding;
  final CornerRadius? cornerRadius;

  const ButtonStyle({this.color, this.hoveredColor, this.disabledColor, this.padding, this.cornerRadius});

  ButtonStyle copy({
    Color? color,
    Color? hoveredColor,
    Color? disabledColor,
    Insets? padding,
    CornerRadius? cornerRadius,
  }) => ButtonStyle(
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
  }) : this(
         key: key,
         style: style,
         enabled: enabled,
         onClick: onClick,
         // TODO: allow customizing this through the button style
         child: Label(text: text, style: LabelStyle(fontSize: 14, bold: true)),
       );

  @override
  WidgetState createState() => ButtonState();
}

class ButtonState extends WidgetState<Button> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    var style = widget.style;
    if (DefaultButtonStyle.maybeOf(context) case ButtonStyle contextStyle) {
      style = style.overriding(contextStyle);
    }

    Widget result = Panel(
      cornerRadius: style.cornerRadius ?? _defaultCornerRadius,
      color:
          widget.enabled
              ? _hovered
                  ? style.hoveredColor ?? _defaultHoveredColor
                  : style.color ?? _defaultColor
              : style.disabledColor ?? _defaultDisabledColor,
      child: Padding(insets: style.padding ?? _defaultPadding, child: widget.child),
    );

    if (widget.enabled) {
      result = MouseArea(
        cursorStyle: CursorStyle.hand,
        clickCallback: (_, _) => widget.onClick(),
        enterCallback: () => setState(() => _hovered = true),
        exitCallback: () => setState(() => _hovered = false),
        child: result,
      );
    }

    return result;
  }

  static const _defaultColor = Color.rgb(0x3867d6);
  static const _defaultHoveredColor = Color.rgb(0x4b7bec);
  static const _defaultDisabledColor = Color.rgb(0x4b6584);
  static const _defaultPadding = Insets.all(3.0);
  static const _defaultCornerRadius = CornerRadius.all(3.0);
}

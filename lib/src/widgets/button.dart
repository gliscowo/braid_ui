import 'package:diamond_gl/diamond_gl.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'text.dart';

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
  final TextStyle? textStyle;

  const ButtonStyle({
    this.color,
    this.hoveredColor,
    this.disabledColor,
    this.padding,
    this.cornerRadius,
    this.textStyle,
  });

  ButtonStyle copy({
    Color? color,
    Color? hoveredColor,
    Color? disabledColor,
    Insets? padding,
    CornerRadius? cornerRadius,
    TextStyle? textStyle,
  }) => ButtonStyle(
    color: color ?? this.color,
    hoveredColor: hoveredColor ?? this.hoveredColor,
    disabledColor: disabledColor ?? this.disabledColor,
    padding: padding ?? this.padding,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    textStyle: textStyle ?? this.textStyle,
  );

  ButtonStyle overriding(ButtonStyle other) {
    var textStyle = this.textStyle;
    if (textStyle != null && other.textStyle != null) {
      textStyle = textStyle.overriding(other.textStyle!);
    }
    textStyle ??= other.textStyle;

    return ButtonStyle(
      color: color ?? other.color,
      hoveredColor: hoveredColor ?? other.hoveredColor,
      disabledColor: disabledColor ?? other.disabledColor,
      padding: padding ?? other.padding,
      cornerRadius: cornerRadius ?? other.cornerRadius,
      textStyle: textStyle,
    );
  }

  @override
  int get hashCode => Object.hash(color, hoveredColor, disabledColor, padding, cornerRadius, textStyle);

  @override
  bool operator ==(Object other) =>
      other is ButtonStyle &&
      other.color == color &&
      other.hoveredColor == hoveredColor &&
      other.disabledColor == disabledColor &&
      other.padding == padding &&
      other.cornerRadius == cornerRadius &&
      other.textStyle == textStyle;
}

class Button extends StatelessWidget {
  final ButtonStyle? style;
  final bool enabled;
  final void Function() onClick;
  final String text;

  Button({super.key, this.style, this.enabled = true, required this.onClick, required this.text});

  @override
  Widget build(BuildContext context) {
    var effectiveStyle = style ?? ButtonStyle.empty;
    if (DefaultButtonStyle.maybeOf(context) case ButtonStyle contextStyle) {
      effectiveStyle = effectiveStyle.overriding(contextStyle);
    }

    return RawButton(
      style: effectiveStyle,
      enabled: enabled,
      onClick: onClick,
      child: Text(text: text, style: effectiveStyle.textStyle),
    );
  }
}

class RawButton extends StatefulWidget {
  final ButtonStyle style;
  final bool enabled;
  final void Function() onClick;
  final Widget child;

  const RawButton({super.key, required this.style, required this.enabled, required this.onClick, required this.child});

  @override
  WidgetState createState() => _RawButtonState();
}

class _RawButtonState extends WidgetState<RawButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;

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

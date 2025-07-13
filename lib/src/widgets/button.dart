import 'package:diamond_gl/diamond_gl.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'basic.dart';
import 'text.dart';

class DefaultButtonStyle extends InheritedWidget {
  final ButtonStyle style;

  DefaultButtonStyle({required this.style, required super.child});

  static Widget merge({required ButtonStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultButtonStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

  @override
  bool mustRebuildDependents(DefaultButtonStyle newWidget) => newWidget.style != style;

  // ---

  static ButtonStyle of(BuildContext context) {
    final widget = context.dependOnAncestor<DefaultButtonStyle>();
    assert(widget != null, 'expected an ambient DefaultButtonStyle');

    return widget!.style;
  }
}

class ButtonStyle {
  static const empty = ButtonStyle();

  final Color? color;
  final Color? highlightColor;
  final Color? disabledColor;
  final Insets? padding;
  final CornerRadius? cornerRadius;
  final TextStyle? textStyle;
  final TextStyle? highlightTextStyle;
  final TextStyle? disabledTextStyle;

  const ButtonStyle({
    this.color,
    this.highlightColor,
    this.disabledColor,
    this.padding,
    this.cornerRadius,
    this.textStyle,
    this.highlightTextStyle,
    this.disabledTextStyle,
  });

  ButtonStyle copy({
    Color? color,
    Color? highlightColor,
    Color? disabledColor,
    Insets? padding,
    CornerRadius? cornerRadius,
    TextStyle? textStyle,
    TextStyle? highlightTextStyle,
    TextStyle? disabledTextStyle,
  }) => ButtonStyle(
    color: color ?? this.color,
    highlightColor: highlightColor ?? this.highlightColor,
    disabledColor: disabledColor ?? this.disabledColor,
    padding: padding ?? this.padding,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    textStyle: textStyle ?? this.textStyle,
    highlightTextStyle: highlightTextStyle ?? this.highlightTextStyle,
    disabledTextStyle: disabledTextStyle ?? this.disabledTextStyle,
  );

  ButtonStyle overriding(ButtonStyle other) {
    var textStyle = this.textStyle;
    if (textStyle != null && other.textStyle != null) {
      textStyle = textStyle.overriding(other.textStyle!);
    }
    textStyle ??= other.textStyle;

    var highlightTextStyle = this.highlightTextStyle;
    if (highlightTextStyle != null && other.highlightTextStyle != null) {
      highlightTextStyle = highlightTextStyle.overriding(other.highlightTextStyle!);
    }
    highlightTextStyle ??= other.highlightTextStyle;

    var disabledTextStyle = this.disabledTextStyle;
    if (disabledTextStyle != null && other.disabledTextStyle != null) {
      disabledTextStyle = disabledTextStyle.overriding(other.disabledTextStyle!);
    }
    disabledTextStyle ??= other.disabledTextStyle;

    return ButtonStyle(
      color: color ?? other.color,
      highlightColor: highlightColor ?? other.highlightColor,
      disabledColor: disabledColor ?? other.disabledColor,
      padding: padding ?? other.padding,
      cornerRadius: cornerRadius ?? other.cornerRadius,
      textStyle: textStyle,
      highlightTextStyle: highlightTextStyle,
      disabledTextStyle: disabledTextStyle,
    );
  }

  @override
  int get hashCode => Object.hash(
    color,
    highlightColor,
    disabledColor,
    padding,
    cornerRadius,
    textStyle,
    highlightTextStyle,
    disabledTextStyle,
  );

  @override
  bool operator ==(Object other) =>
      other is ButtonStyle &&
      other.color == color &&
      other.highlightColor == highlightColor &&
      other.disabledColor == disabledColor &&
      other.padding == padding &&
      other.cornerRadius == cornerRadius &&
      other.textStyle == textStyle &&
      other.highlightTextStyle == highlightTextStyle &&
      other.disabledTextStyle == disabledTextStyle;
}

class Button extends StatelessWidget {
  final ButtonStyle? style;
  final void Function()? onClick;
  final Widget child;

  Button({super.key, this.style, required this.onClick, required this.child});

  @override
  Widget build(BuildContext context) {
    final contextStyle = DefaultButtonStyle.of(context);
    final style = this.style?.overriding(contextStyle) ?? contextStyle;

    return RawButton(style: style, onClick: onClick, child: child);
  }
}

class RawButton extends StatefulWidget {
  final ButtonStyle style;
  final void Function()? onClick;
  final Widget child;

  const RawButton({super.key, required this.style, required this.onClick, required this.child});

  @override
  WidgetState createState() => _RawButtonState();
}

class _RawButtonState extends WidgetState<RawButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;

    final style = widget.style;
    final textStyle = widget.onClick != null
        ? _hovered
              ? style.highlightTextStyle ?? style.textStyle
              : style.textStyle
        : style.disabledTextStyle;

    if (textStyle != null) {
      result = AnimatedDefaultTextStyle.merge(
        duration: const Duration(milliseconds: 100),
        style: textStyle,
        child: result,
      );
    }

    result = AnimatedPanel(
      duration: const Duration(milliseconds: 100),
      cornerRadius: style.cornerRadius!,
      color: widget.onClick != null
          ? _hovered
                ? style.highlightColor!
                : style.color!
          : style.disabledColor!,
      child: Padding(insets: style.padding!, child: result),
    );

    if (widget.onClick != null) {
      result = Actions.click(
        enterCallback: () => setState(() => _hovered = true),
        exitCallback: () => setState(() => _hovered = false),
        cursorStyle: CursorStyle.hand,
        onClick: () => widget.onClick!(),
        child: result,
      );
    }

    return result;
  }
}

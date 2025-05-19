import 'package:diamond_gl/diamond_gl.dart';

import '../animation/easings.dart';
import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'basic.dart';

class SwitchStyle {
  final Color? backgroundOffColor;
  final Color? backgroundOnColor;
  final Color? backgroundDisabledColor;
  final Color? switchOffColor;
  final Color? switchOnColor;
  final Color? switchDisabledColor;

  const SwitchStyle({
    this.backgroundOffColor,
    this.backgroundOnColor,
    this.backgroundDisabledColor,
    this.switchOffColor,
    this.switchOnColor,
    this.switchDisabledColor,
  });

  SwitchStyle copy({
    Color? backgroundOffColor,
    Color? backgroundOnColor,
    Color? backgroundDisabledColor,
    Color? switchOffColor,
    Color? switchOnColor,
    Color? switchDisabledColor,
  }) => SwitchStyle(
    backgroundOffColor: backgroundOffColor ?? this.backgroundOffColor,
    backgroundOnColor: backgroundOnColor ?? this.backgroundOnColor,
    backgroundDisabledColor: backgroundDisabledColor ?? this.backgroundDisabledColor,
    switchOffColor: switchOffColor ?? this.switchOffColor,
    switchOnColor: switchOnColor ?? this.switchOnColor,
    switchDisabledColor: switchDisabledColor ?? this.switchDisabledColor,
  );

  SwitchStyle overriding(SwitchStyle other) => SwitchStyle(
    backgroundOffColor: backgroundOffColor ?? other.backgroundOffColor,
    backgroundOnColor: backgroundOnColor ?? other.backgroundOnColor,
    backgroundDisabledColor: backgroundDisabledColor ?? other.backgroundDisabledColor,
    switchOffColor: switchOffColor ?? other.switchOffColor,
    switchOnColor: switchOnColor ?? other.switchOnColor,
    switchDisabledColor: switchDisabledColor ?? other.switchDisabledColor,
  );

  get _props => (
    backgroundOffColor,
    backgroundOnColor,
    backgroundDisabledColor,
    switchOffColor,
    switchOnColor,
    switchDisabledColor,
  );

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is SwitchStyle && other._props == _props;
}

class DefaultSwitchStyle extends InheritedWidget {
  final SwitchStyle style;

  DefaultSwitchStyle({super.key, required this.style, required super.child});

  static Widget merge({required SwitchStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultSwitchStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

  @override
  bool mustRebuildDependents(covariant DefaultSwitchStyle newWidget) => newWidget.style != style;

  // ---

  static SwitchStyle of(BuildContext context) {
    final widget = context.dependOnAncestor<DefaultSwitchStyle>();
    assert(widget != null, 'expected an ambient DefaultSwitchStyle');

    return widget!.style;
  }
}

class Switch extends StatelessWidget {
  final SwitchStyle? style;
  final bool on;
  final void Function()? onClick;

  const Switch({super.key, this.style, required this.on, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final contextStyle = DefaultSwitchStyle.of(context);
    final style = this.style?.overriding(contextStyle) ?? contextStyle;

    return Actions.click(
      cursorStyle: onClick != null ? CursorStyle.hand : null,
      onClick: onClick != null ? () => onClick!() : null,
      child: Sized(
        width: 40,
        height: 24,
        child: AnimatedPanel(
          easing: Easing.inOutCubic,
          duration: const Duration(milliseconds: 250),
          cornerRadius: const CornerRadius.all(12.5),
          color:
              onClick != null
                  ? on
                      ? style.backgroundOnColor!
                      : style.backgroundOffColor!
                  : style.backgroundDisabledColor!,
          child: AnimatedAlign(
            easing: Easing.inOutCubic,
            duration: const Duration(milliseconds: 250),
            alignment: on ? Alignment.right : Alignment.left,
            child: Padding(
              insets: const Insets.axis(horizontal: 4),
              child: Sized(
                width: 16,
                height: 16,
                child: AnimatedPanel(
                  easing: Easing.inOutCubic,
                  duration: const Duration(milliseconds: 250),
                  cornerRadius: const CornerRadius.all(8),
                  color:
                      onClick != null
                          ? on
                              ? style.switchOnColor!
                              : style.switchOffColor!
                          : style.switchDisabledColor!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

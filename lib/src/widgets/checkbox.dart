import 'package:diamond_gl/diamond_gl.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'icon.dart';

class CheckboxStyle {
  final Color? borderColor;
  final Color? checkedColor;
  final Color? checkedHighlightColor;
  final CornerRadius? cornerRadius;

  const CheckboxStyle({this.borderColor, this.checkedColor, this.checkedHighlightColor, this.cornerRadius});

  CheckboxStyle copy({
    Color? borderColor,
    Color? checkedColor,
    Color? checkedHighlightColor,
    CornerRadius? cornerRadius,
  }) => CheckboxStyle(
    borderColor: borderColor ?? this.borderColor,
    checkedColor: checkedColor ?? this.checkedColor,
    checkedHighlightColor: checkedHighlightColor ?? this.checkedHighlightColor,
    cornerRadius: cornerRadius ?? this.cornerRadius,
  );

  CheckboxStyle overriding(CheckboxStyle other) => CheckboxStyle(
    borderColor: borderColor ?? other.borderColor,
    checkedColor: checkedColor ?? other.checkedColor,
    checkedHighlightColor: checkedHighlightColor ?? other.checkedHighlightColor,
    cornerRadius: cornerRadius ?? other.cornerRadius,
  );

  get _props => (borderColor, checkedColor, checkedHighlightColor, cornerRadius);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is CheckboxStyle && other._props == _props;
}

class DefaultCheckboxStyle extends InheritedWidget {
  final CheckboxStyle style;

  DefaultCheckboxStyle({super.key, required this.style, required super.child});

  static Widget merge({required CheckboxStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultCheckboxStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

  @override
  bool mustRebuildDependents(covariant DefaultCheckboxStyle newWidget) => newWidget.style != style;

  // ---

  static CheckboxStyle of(BuildContext context) {
    final widget = context.dependOnAncestor<DefaultCheckboxStyle>();
    assert(widget != null, 'expected an ambient DefaultCheckboxStyle');

    return widget!.style;
  }
}

class Checkbox extends StatefulWidget {
  final CheckboxStyle? style;
  final bool checked;
  final void Function()? onClick;

  const Checkbox({super.key, this.style, required this.checked, this.onClick});

  @override
  WidgetState<StatefulWidget> createState() => _CheckboxState();
}

class _CheckboxState extends WidgetState<Checkbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final contextStyle = DefaultCheckboxStyle.of(context);
    final style = widget.style?.overriding(contextStyle) ?? contextStyle;

    return Actions.click(
      enterCallback: () => setState(() => _hovered = true),
      exitCallback: () => setState(() => _hovered = false),
      cursorStyle: CursorStyle.hand,
      onClick: () => widget.onClick?.call(),
      child: Sized(
        width: 20,
        height: 20,
        child: Panel(
          color: widget.checked
              ? _hovered
                    ? style.checkedHighlightColor!
                    : style.checkedColor!
              : style.borderColor!,
          cornerRadius: style.cornerRadius!,
          outlineThickness: !widget.checked ? .5 : null,
          child: widget.checked ? const Icon(icon: Icons.close, size: 16) : null,
        ),
      ),
    );
  }
}

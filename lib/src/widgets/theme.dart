import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../core/math.dart';
import '../framework/widget.dart';
import 'button.dart';
import 'checkbox.dart';
import 'combo_box.dart';
import 'slider.dart';
import 'switch.dart';
import 'text.dart';

class BraidThemeData extends InheritedWidget {
  final Color accentColor;
  final Color elementColor;
  final Color highlightColor;
  final Color disabledColor;
  final Color backgroundColor;
  final Color elevatedColor;

  const BraidThemeData({
    super.key,
    required this.accentColor,
    required this.elementColor,
    required this.highlightColor,
    required this.disabledColor,
    required this.backgroundColor,
    required this.elevatedColor,
    required super.child,
  });

  @protected
  @override
  Widget get child => super.child;

  @override
  bool mustRebuildDependents(covariant BraidThemeData newWidget) {
    return accentColor != newWidget.accentColor ||
        elementColor != newWidget.elementColor ||
        highlightColor != newWidget.highlightColor ||
        disabledColor != newWidget.disabledColor ||
        backgroundColor != newWidget.backgroundColor ||
        elevatedColor != newWidget.elevatedColor;
  }
}

class BraidTheme extends StatelessWidget {
  final Color? accentColor;
  final Color? elementColor;
  final Color? highlightColor;
  final Color? disabledColor;
  final Color? backgroundColor;
  final Color? elevatedColor;

  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;
  final SwitchStyle? switchStyle;
  final CheckboxStyle? checkboxStyle;
  final SliderStyle? sliderStyle;
  final ComboBoxStyle? comboBoxStyle;

  final Widget child;

  const BraidTheme({
    super.key,
    this.accentColor,
    this.elementColor,
    this.highlightColor,
    this.disabledColor,
    this.backgroundColor,
    this.elevatedColor,
    this.textStyle,
    this.buttonStyle,
    this.switchStyle,
    this.checkboxStyle,
    this.sliderStyle,
    this.comboBoxStyle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = this.accentColor ?? defaultAccentColor;
    final elementColor = this.elementColor ?? defaultElementColor;

    var highlightColor = this.highlightColor;
    if (highlightColor == null) {
      final accentHsv = accentColor.hsv;
      highlightColor = Color.ofHsv(accentHsv[0], accentHsv[1], min(1, accentHsv[2] + .1));
    }

    final disabledColor = this.disabledColor ?? defaultDisabledColor;
    final backgroundColor = this.backgroundColor ?? defaultBackgroundColor;
    final elevatedColor = this.elevatedColor ?? defaultElevatedColor;

    // ---

    final textStyle = this.textStyle?.overriding(defaultTextStyle) ?? defaultTextStyle;

    final baseButtonStyle = defaultButtonStyle.overriding(
      ButtonStyle(
        color: accentColor,
        highlightColor: highlightColor,
        disabledColor: disabledColor,
        disabledTextStyle: TextStyle(color: elementColor),
      ),
    );
    final buttonStyle = this.buttonStyle?.overriding(baseButtonStyle) ?? baseButtonStyle;

    final baseCheckboxStyle = defaultCheckboxStyle.overriding(
      CheckboxStyle(borderColor: elementColor, checkedColor: accentColor, checkedHighlightColor: highlightColor),
    );
    final checkboxStyle = this.checkboxStyle?.overriding(baseCheckboxStyle) ?? baseCheckboxStyle;

    final baseSwitchStyle = SwitchStyle(
      backgroundOffColor: elevatedColor,
      backgroundOnColor: accentColor,
      backgroundDisabledColor: disabledColor,
      switchOffColor: Color.white,
      switchOnColor: Color.white,
      switchDisabledColor: elementColor,
    );
    final switchStyle = this.switchStyle?.overriding(baseSwitchStyle) ?? baseSwitchStyle;

    final baseSliderStyle = defaultSliderStyle.overriding(
      SliderStyle(
        trackColor: elementColor,
        trackDisabledColor: elevatedColor,
        handleColor: accentColor,
        handleHighlightColor: highlightColor,
        handleDisabledColor: disabledColor,
      ),
    );
    final sliderStyle = this.sliderStyle?.overriding(baseSliderStyle) ?? baseSliderStyle;

    final baseComboBoxStyle = defaultComboBoxStyle.overriding(
      ComboBoxStyle(borderColor: elementColor, borderHighlightColor: highlightColor, backgroundColor: elevatedColor),
    );
    final comboBoxStyle = this.comboBoxStyle?.overriding(baseComboBoxStyle) ?? baseComboBoxStyle;

    return BraidThemeData(
      accentColor: accentColor,
      elementColor: elementColor,
      highlightColor: highlightColor,
      disabledColor: disabledColor,
      backgroundColor: backgroundColor,
      elevatedColor: elevatedColor,
      child: DefaultTextStyle(
        style: textStyle,
        child: DefaultButtonStyle(
          style: buttonStyle,
          child: DefaultSwitchStyle(
            style: switchStyle,
            child: DefaultCheckboxStyle(
              style: checkboxStyle,
              child: DefaultSliderStyle(
                style: sliderStyle,
                child: DefaultComboBoxStyle(style: comboBoxStyle, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---

  static BraidThemeData? maybeOf(BuildContext context) {
    return context.dependOnAncestor<BraidThemeData>();
  }

  static BraidThemeData of(BuildContext context) {
    final widget = maybeOf(context);
    assert(widget != null, 'expected an ambient BraidTheme');

    return widget!;
  }

  // ---

  static const defaultAccentColor = Color.rgb(0x5f43b2);
  static const defaultElementColor = Color.rgb(0xb1aebb);
  static const defaultDisabledColor = Color.rgb(0x2c2a6e);
  static const defaultBackgroundColor = Color.rgb(0x0f0f0f);
  static const defaultElevatedColor = Color.rgb(0x161616);

  static const defaultTextStyle = TextStyle(
    color: Color.white,
    fontSize: 16.0,
    bold: false,
    italic: false,
    underline: false,
  );
  static const defaultButtonStyle = ButtonStyle(
    padding: Insets.axis(horizontal: 6, vertical: 3),
    cornerRadius: CornerRadius.all(5),
    textStyle: TextStyle(fontSize: 14.0, bold: true),
    disabledTextStyle: TextStyle(fontSize: 14.0, bold: true),
  );
  static const defaultCheckboxStyle = CheckboxStyle(cornerRadius: CornerRadius.all(5));
  static const defaultSliderStyle = SliderStyle(trackThickness: 3, handleSize: 20);
  static const defaultComboBoxStyle = ComboBoxStyle(
    borderThickness: 1,
    cornerRadius: CornerRadius.all(5),
    textStyle: TextStyle(fontSize: 14.0, bold: true),
    optionButtonStyle: ButtonStyle(
      color: Color(0),
      cornerRadius: CornerRadius.all(0),
      padding: Insets.axis(horizontal: 6, vertical: 3),
      textStyle: TextStyle(bold: false),
    ),
  );
}

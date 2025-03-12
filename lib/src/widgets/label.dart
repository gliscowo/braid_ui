import 'package:diamond_gl/diamond_gl.dart';

import '../../braid_ui.dart';
import '../immediate/foundation.dart';

class LabelStyle {
  static const empty = LabelStyle();

  final Color? textColor;
  final double? fontSize;
  final String? fontFamily;
  final bool? bold;
  final bool? italic;
  final double? lineHeight;

  const LabelStyle({
    this.textColor,
    this.fontSize,
    this.fontFamily,
    this.bold,
    this.italic,
    this.lineHeight,
  });

  LabelStyle copy({
    Color? textColor,
    double? fontSize,
    String? fontFamily,
    bool? bold,
    bool? italic,
    double? lineHeight,
  }) =>
      LabelStyle(
        textColor: textColor ?? this.textColor,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        lineHeight: lineHeight ?? this.lineHeight,
      );

  LabelStyle overriding(LabelStyle other) => LabelStyle(
        textColor: textColor ?? other.textColor,
        fontSize: fontSize ?? other.fontSize,
        fontFamily: fontFamily ?? other.fontFamily,
        bold: bold ?? other.bold,
        italic: italic ?? other.italic,
        lineHeight: lineHeight ?? other.lineHeight,
      );

  // for now we'll leave it at this, since it's a lot nicer to implement and shorter.
  // however, quick benchmarks indicate that this is ~4x slower than a full manual
  // impl so we might change it in the future should it ever becomer relevant
  get _props => (textColor, fontSize, fontFamily, bold, italic, lineHeight);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is LabelStyle && other._props == _props;
}

// class LabelStyleHost extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   LabelStyle style;

//   LabelStyleHost({
//     required super.child,
//     required this.style,
//   });
// }

class LabelInstance extends WidgetInstance<Label> {
  late Text _styledText;
  LabelStyle? _contextStyle;

  LabelInstance({
    required super.widget,
  }) {
    _computeStyledText();
  }

  @override
  void draw(DrawContext ctx) {
    final style = _computedStyle;

    final textSize = ctx.textRenderer.sizeOf(
      _styledText,
      style.fontSize ?? _defaultFontSize,
      lineHeightOverride: style.lineHeight,
    );

    final xOffset = (transform.width - textSize.width) ~/ 2;
    final yOffset = (transform.height - textSize.height) ~/ 2;

    ctx.transform.scope((mat4) {
      mat4.translate(xOffset.toDouble(), yOffset.toDouble());
      ctx.textRenderer.drawText(
        _styledText,
        style.fontSize ?? _defaultFontSize,
        style.textColor ?? _defaultTextColor,
        mat4,
        ctx.projection,
        lineHeightOverride: style.lineHeight,
        // debugCtx: ctx,
      );
    });
  }

  @override
  void doLayout(Constraints constraints) {
    // if (ancestorOfType<LabelStyleHost>() case var styleHost?) {
    //   _contextStyle = styleHost.style;
    //   _computeStyledText();
    // }

    final style = _computedStyle;
    final size = host!.textRenderer
        .sizeOf(_styledText, style.fontSize ?? _defaultFontSize, lineHeightOverride: style.lineHeight)
        .constrained(constraints);

    transform.setSize(size.ceil());
  }

  LabelStyle get _computedStyle => _contextStyle != null ? widget.style.overriding(_contextStyle!) : widget.style;

  void _computeStyledText() {
    final style = _computedStyle;
    _styledText = widget.text.copy(
      style: TextStyle(
        fontFamily: style.fontFamily,
        color: style.textColor,
        bold: style.bold,
        italic: style.italic,
      ).overriding(widget.text.style),
    );
  }

  @override
  set widget(Label value) {
    if (widget.text == value.text && widget.style == value.style) return;

    super.widget = value;
    _computeStyledText();

    markNeedsLayout();
  }

  // LabelStyle get style => _style;
  // set style(LabelStyle value) {
  //   if (_style == value) return;

  //   _style = value;
  //   _computeStyledText();
  //   markNeedsLayout();
  // }

  // Text get text => _text;
  // set text(Text value) {
  //   if (_text == value) return;

  //   _text = value;
  //   _computeStyledText();
  //   markNeedsLayout();
  // }

  // set string(String value) {
  //   _text = Text.string(value);

  //   _computeStyledText();
  //   markNeedsLayout();
  // }

  // ---

  static final _defaultFontSize = 16.0;
  static final _defaultTextColor = Color.white;
}

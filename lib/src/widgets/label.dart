import 'package:collection/collection.dart';
import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import '../text/text.dart';

class TextStyle {
  static const empty = TextStyle();

  final Color? color;
  final double? fontSize;
  final String? fontFamily;
  final bool? bold;
  final bool? italic;
  final double? lineHeight;

  const TextStyle({this.color, this.fontSize, this.fontFamily, this.bold, this.italic, this.lineHeight});

  TextStyle copy({Color? color, double? fontSize, String? fontFamily, bool? bold, bool? italic, double? lineHeight}) =>
      TextStyle(
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        lineHeight: lineHeight ?? this.lineHeight,
      );

  TextStyle overriding(TextStyle other) => TextStyle(
    color: color ?? other.color,
    fontSize: fontSize ?? other.fontSize,
    fontFamily: fontFamily ?? other.fontFamily,
    bold: bold ?? other.bold,
    italic: italic ?? other.italic,
    lineHeight: lineHeight ?? other.lineHeight,
  );

  SpanStyle _toSpanStyle() => SpanStyle(
    color: color ?? _defaultTextColor,
    fontSize: fontSize ?? _defaultFontSize,
    fontFamily: fontFamily ?? 'Noto Sans',
    bold: bold ?? false,
    italic: italic ?? false,
    lineHeight: lineHeight,
  );

  // --- TEMPORARY ---
  static final _defaultFontSize = 16.0;
  static final _defaultTextColor = Color.white;
  // -----------------

  // for now we'll leave it at this, since it's a lot nicer to implement and shorter.
  // however, quick benchmarks indicate that this is ~4x slower than a full manual
  // impl so we might change it in the future should it ever becomer relevant
  get _props => (color, fontSize, fontFamily, bold, italic, lineHeight);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is TextStyle && other._props == _props;
}

class DefaultTextStyle extends InheritedWidget {
  final TextStyle style;
  const DefaultTextStyle({super.key, required this.style, required super.child});

  @override
  bool mustRebuildDependents(DefaultTextStyle newWidget) => newWidget.style != style;

  static TextStyle? maybeOf(BuildContext context) => context.dependOnAncestor<DefaultTextStyle>()?.style;
}

class Text extends StatelessWidget {
  final String text;
  final TextStyle style;

  const Text({super.key, required this.text, this.style = TextStyle.empty});

  @override
  Widget build(BuildContext context) {
    final contextStyle = DefaultTextStyle.maybeOf(context);
    final computedStyle = contextStyle != null ? style.overriding(contextStyle) : style;

    return RawText(spans: [Span(text, computedStyle._toSpanStyle())]);
  }
}

class RawText extends LeafInstanceWidget {
  final List<Span> spans;

  const RawText({super.key, required this.spans});

  @override
  RawTextInstance instantiate() => RawTextInstance(widget: this);
}

class RawTextInstance extends LeafWidgetInstance<RawText> {
  Paragraph _styledText;

  RawTextInstance({required super.widget}) : _styledText = Paragraph(widget.spans);

  @override
  void draw(DrawContext ctx) {
    final textSize = ctx.textRenderer.sizeOf(_styledText);

    final xOffset = (transform.width - textSize.width) ~/ 2;
    final yOffset = (transform.height - textSize.height) ~/ 2;

    ctx.transform.scope((mat4) {
      mat4.translate(xOffset.toDouble(), yOffset.toDouble());
      ctx.textRenderer.drawText(
        _styledText,
        mat4,
        ctx.projection,
        // debugCtx: ctx,
      );
    });
  }

  @override
  void doLayout(Constraints constraints) {
    final size = host!.textRenderer.sizeOf(_styledText).constrained(constraints);

    transform.setSize(size.ceil());
  }

  @override
  set widget(RawText value) {
    if (const ListEquality<Span>().equals(widget.spans, value.spans)) return;

    super.widget = value;
    _styledText = Paragraph(widget.spans);

    markNeedsLayout();
  }
}

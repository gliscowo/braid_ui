import 'package:diamond_gl/diamond_gl.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import '../text/text_layout.dart';
import 'basic.dart';

class TextStyle {
  static const empty = TextStyle();

  final Color? color;
  final double? fontSize;
  final String? fontFamily;
  final bool? bold;
  final bool? italic;
  final double? lineHeight;
  final Alignment? alignment;

  const TextStyle({
    this.color,
    this.fontSize,
    this.fontFamily,
    this.bold,
    this.italic,
    this.lineHeight,
    this.alignment,
  });

  TextStyle copy({
    Color? color,
    double? fontSize,
    String? fontFamily,
    bool? bold,
    bool? italic,
    double? lineHeight,
    Alignment? alignment,
  }) => TextStyle(
    color: color ?? this.color,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    lineHeight: lineHeight ?? this.lineHeight,
    alignment: alignment ?? this.alignment,
  );

  TextStyle overriding(TextStyle other) => TextStyle(
    color: color ?? other.color,
    fontSize: fontSize ?? other.fontSize,
    fontFamily: fontFamily ?? other.fontFamily,
    bold: bold ?? other.bold,
    italic: italic ?? other.italic,
    lineHeight: lineHeight ?? other.lineHeight,
    alignment: alignment ?? other.alignment,
  );

  SpanStyle toSpanStyle() {
    assert(color != null, 'only text styles which define \'color\' may be converted into a SpanStyle');
    assert(fontSize != null, 'only text styles which define \'fontSize\' may be converted into a SpanStyle');
    assert(bold != null, 'only text styles which define \'bold\' may be converted into a SpanStyle');
    assert(italic != null, 'only text styles which define \'italic\' may be converted into a SpanStyle');

    return SpanStyle(
      color: color!,
      fontSize: fontSize!,
      fontFamily: fontFamily,
      bold: bold!,
      italic: italic!,
      lineHeight: lineHeight,
    );
  }

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

  static TextStyle of(BuildContext context) {
    final ancestorStyle = context.dependOnAncestor<DefaultTextStyle>()?.style;
    assert(
      ancestorStyle != null,
      'an ambient DefaultTextStyle which defines \'color\', \'fontSize\', \'bold\' '
      'and \'italic\' must be present in every app which wants to display text',
    );

    return ancestorStyle!;
  }
}

class Text extends StatelessWidget {
  final TextStyle? style;
  final String text;

  const Text({super.key, this.style, required this.text});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? TextStyle.empty;
    final spanStyle = effectiveStyle.overriding(DefaultTextStyle.of(context)).toSpanStyle();

    return RawText(spans: [Span(text, spanStyle)], alignment: effectiveStyle.alignment ?? Alignment.center);
  }
}

class RawText extends LeafInstanceWidget {
  final Alignment alignment;
  final List<Span> spans;

  const RawText({super.key, required this.alignment, required this.spans});

  @override
  RawTextInstance instantiate() => RawTextInstance(widget: this);
}

class RawTextInstance extends LeafWidgetInstance<RawText> {
  Paragraph _styledText;

  RawTextInstance({required super.widget}) : _styledText = Paragraph(widget.spans);

  @override
  void draw(DrawContext ctx) {
    ctx.textRenderer.drawText(
      _styledText,
      widget.alignment,
      transform.toSize(),
      ctx.transform,
      ctx.projection,
      // debugCtx: ctx,
    );
  }

  @override
  void doLayout(Constraints constraints) {
    final size = host!.textRenderer.layoutParagraph(_styledText, constraints.maxWidth).size.constrained(constraints);
    transform.setSize(size.ceil());
  }

  @override
  set widget(RawText value) {
    final spansComp = Span.comapreLists(widget.spans, value.spans);
    if (spansComp == SpanComparison.equal && widget.alignment == value.alignment) return;

    super.widget = value;
    if (spansComp == SpanComparison.visualsChanged) {
      _styledText.updateSpans(value.spans);
    } else {
      _styledText = Paragraph(widget.spans);
      markNeedsLayout();
    }
  }
}

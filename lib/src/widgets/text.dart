import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

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
  final bool? underline;
  final double? lineHeight;
  final Alignment? alignment;

  @literal
  const TextStyle({
    this.color,
    this.fontSize,
    this.fontFamily,
    this.bold,
    this.italic,
    this.underline,
    this.lineHeight,
    this.alignment,
  });

  TextStyle copy({
    Color? color,
    double? fontSize,
    String? fontFamily,
    bool? bold,
    bool? italic,
    bool? underline,
    double? lineHeight,
    Alignment? alignment,
  }) => TextStyle(
    color: color ?? this.color,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    lineHeight: lineHeight ?? this.lineHeight,
    alignment: alignment ?? this.alignment,
  );

  TextStyle overriding(TextStyle other) => TextStyle(
    color: color ?? other.color,
    fontSize: fontSize ?? other.fontSize,
    fontFamily: fontFamily ?? other.fontFamily,
    bold: bold ?? other.bold,
    italic: italic ?? other.italic,
    underline: underline ?? other.underline,
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
      underline: underline!,
      lineHeight: lineHeight,
    );
  }

  // for now we'll leave it at this, since it's a lot nicer to implement and shorter.
  // however, quick benchmarks indicate that this is ~4x slower than a full manual
  // impl so we might change it in the future should it ever becomer relevant
  get _props => (color, fontSize, fontFamily, bold, italic, underline, lineHeight);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is TextStyle && other._props == _props;
}

class DefaultTextStyle extends InheritedWidget {
  final TextStyle style;
  const DefaultTextStyle({super.key, required this.style, required super.child});

  static Widget merge({required TextStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultTextStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

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
  final bool softWrap;

  const Text(this.text, {super.key, this.style, this.softWrap = true});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? TextStyle.empty;
    final spanStyle = effectiveStyle.overriding(DefaultTextStyle.of(context)).toSpanStyle();

    return RawText(
      softWrap: softWrap,
      spans: [Span(text, spanStyle)],
      alignment: effectiveStyle.alignment ?? Alignment.center,
    );
  }
}

class RawText extends LeafInstanceWidget {
  final bool softWrap;
  final Alignment alignment;
  final List<Span> spans;

  const RawText({super.key, required this.softWrap, required this.alignment, required this.spans});

  @override
  RawTextInstance instantiate() => RawTextInstance(widget: this);
}

class RawTextInstance extends LeafWidgetInstance<RawText> {
  Paragraph _paragraph;

  RawTextInstance({required super.widget}) : _paragraph = Paragraph(widget.spans);

  @override
  set widget(RawText value) {
    final spansComp = Span.comapreLists(widget.spans, value.spans);
    if (spansComp == .equal && widget.alignment == value.alignment && widget.softWrap == value.softWrap) {
      return;
    }

    super.widget = value;
    if (spansComp == .visualsChanged) {
      _paragraph.updateSpans(value.spans);
    } else {
      _paragraph = Paragraph(widget.spans);
      markNeedsLayout();
    }
  }

  @override
  void draw(DrawContext ctx) {
    ctx.textRenderer.drawText(
      _paragraph,
      widget.alignment,
      transform.toSize(),
      ctx.transform,
      ctx.projection,
      // debugCtx: ctx,
    );
  }

  @override
  void doLayout(Constraints constraints) {
    final size = host!.textRenderer
        .layoutParagraph(_paragraph, widget.softWrap ? constraints.maxWidth : double.infinity)
        .size
        .constrained(constraints);
    transform.setSize(size.ceil());
  }

  @override
  double measureIntrinsicWidth(double height) =>
      host!.textRenderer.layoutParagraph(Paragraph(widget.spans), double.infinity).width;

  @override
  double measureIntrinsicHeight(double width) =>
      host!.textRenderer.layoutParagraph(Paragraph(widget.spans), widget.softWrap ? width : double.infinity).height;

  @override
  double? measureBaselineOffset() => _paragraph.metrics.initialBaselineY;
}

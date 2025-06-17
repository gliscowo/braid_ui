import '../../braid_ui.dart';

export '../baked_assets.g.dart' show Icons;

extension type const IconSpec(int _codepoint) {
  String asString() => String.fromCharCode(_codepoint);
}

class Icon extends StatelessWidget {
  final double size;
  final IconSpec icon;
  final Color? color;

  const Icon({super.key, this.size = 24, this.color, required this.icon});

  Span toSpan(Color color) => Span(
    icon.asString(),
    SpanStyle(
      fontFamily: 'MaterialSymbols',
      fontSize: size,
      lineHeight: 1.0,
      color: color,
      bold: false,
      italic: false,
      underline: false,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).color!;
    return RawText(spans: [toSpan(color)], softWrap: false, alignment: Alignment.center);
  }
}

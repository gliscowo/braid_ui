import 'package:diamond_gl/diamond_gl.dart';

import '../framework/widget.dart';
import '../text/text_layout.dart';
import 'basic.dart';
import 'text.dart';

export '../baked_assets.g.dart' show Icons;

extension type const IconSpec(int _codepoint) {
  String asString() => String.fromCharCode(_codepoint);
}

class Icon extends StatelessWidget {
  final double size;
  final IconSpec icon;
  final Color color;

  const Icon({super.key, this.size = 24, this.color = Color.white, required this.icon});

  Span toSpan() => Span(
    icon.asString(),
    SpanStyle(fontFamily: 'MaterialSymbols', fontSize: size, lineHeight: 1.0, color: color, bold: false, italic: false),
  );

  @override
  Widget build(BuildContext context) {
    return RawText(spans: [toSpan()], softWrap: false, alignment: Alignment.center);
  }
}

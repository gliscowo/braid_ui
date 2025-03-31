import 'package:diamond_gl/diamond_gl.dart';

import '../framework/widget.dart';
import 'label.dart';

extension type const IconSpec(int _codepoint) {
  String asString() => String.fromCharCode(_codepoint);
}

class Icon extends StatelessWidget {
  final double size;
  final IconSpec icon;
  final Color color;

  const Icon({super.key, this.size = 24, this.color = Color.white, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Text(
      text: icon.asString(),
      style: TextStyle(fontFamily: 'MaterialSymbols', fontSize: size, lineHeight: 1.0, color: color),
    );
  }
}

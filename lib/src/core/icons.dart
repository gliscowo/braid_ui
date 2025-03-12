import 'package:diamond_gl/diamond_gl.dart';

import '../baked_assets.g.dart';
import '../text/text.dart';

class Icon extends Span {
  Icon(String name, {Color? color})
      : super(
          lookupIcon(name),
          style: TextStyle(
            fontFamily: 'MaterialSymbols',
            scale: .75,
            color: color ?? const Color.rgb(0xe8eaed),
          ),
        );
}

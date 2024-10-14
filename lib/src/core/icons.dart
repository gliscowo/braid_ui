import 'dart:io';

import 'package:braid_ui/src/text/text.dart';
import 'package:diamond_gl/diamond_gl.dart';

final _iconMap = loadIcons();

Map<String, int> loadIcons() {
  final lines = File('resources/icon_mappings.codepoints').readAsLinesSync();
  final result = <String, int>{};

  for (final line in lines) {
    final [name, codepoint, ...] = line.split(' ');
    result[name] = int.parse(codepoint, radix: 16);
  }

  return result;
}

class Icon extends TextSpan {
  Icon(String name, {Color? color})
      : super(
          String.fromCharCode(_iconMap[name] ?? 0),
          style: TextStyle(
            fontFamily: 'MaterialSymbols',
            scale: .75,
            color: color ?? Color.ofRgb(0xe8eaed),
          ),
        );
}

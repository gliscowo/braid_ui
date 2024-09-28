import 'dart:ffi';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math_64.dart';

import '../native/harfbuzz.dart';
import 'text_renderer.dart';

class StyledString {
  final String content;
  final TextStyle style;
  const StyledString(this.content, {this.style = const TextStyle()});
}

class TextStyle {
  final Color? color;
  final String? fontFamily;
  final bool bold, italic;
  final double scale;

  const TextStyle({this.color, this.fontFamily, this.bold = false, this.italic = false, this.scale = 1});
}

typedef FontLookup = FontFamily Function(String? fontFamily);

class Text {
  final List<StyledString> _segments;
  final List<ShapedGlyph> _shapedGlyphs = [];
  bool _isShaped = false;

  Text.string(String value, {TextStyle style = const TextStyle()}) : this([StyledString(value, style: style)]);

  Text(this._segments) {
    if (_segments.isEmpty) throw ArgumentError('Text must have at least one segment');
  }

  List<ShapedGlyph> get glyphs => _shapedGlyphs;

  bool get isShaped => _isShaped;

  void shape(FontLookup fontLookup) {
    int cursorX = 0, cursorY = 0;

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    for (final segment in _segments) {
      final segmentFont = fontLookup(segment.style.fontFamily);

      final buffer = harfbuzz.buffer_create();

      final bufferContent = /*String.fromCharCodes(logicalToVisual(*/ segment.content /*))*/ .toNativeUtf16();
      harfbuzz.buffer_add_utf16(buffer, bufferContent.cast(), -1, 0, -1);
      malloc.free(bufferContent);

      harfbuzz.buffer_guess_segment_properties(buffer);
      harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
      harfbuzz.shape(segmentFont.fontForStyle(segment.style).hbFont, buffer, features, 1);

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

      final glyphs = glpyhCount.value;
      malloc.free(glpyhCount);

      for (var i = 0; i < glyphs; i++) {
        _shapedGlyphs.add(ShapedGlyph._(
          segmentFont.fontForStyle(segment.style),
          glyphInfo[i].codepoint,
          Vector2(
            cursorX + glyphPos[i].x_offset.toDouble() * segment.style.scale,
            cursorY + glyphPos[i].y_offset.toDouble() * segment.style.scale,
          ),
          Vector2(
            glyphPos[i].x_advance.toDouble(),
            glyphPos[i].y_advance.toDouble(),
          ),
          segment.style,
          glyphInfo[i].cluster,
        ));

        cursorX += (glyphPos[i].x_advance * segment.style.scale).round();
        cursorY += (glyphPos[i].y_advance * segment.style.scale).round();
      }

      harfbuzz.buffer_destroy(buffer);
    }

    malloc.free(features);
    _isShaped = true;
  }
}

class ShapedGlyph {
  final Font font;
  final int index;
  final Vector2 position;
  final Vector2 advance;
  final TextStyle style;
  final int cluster;
  ShapedGlyph._(this.font, this.index, this.position, this.advance, this.style, this.cluster);
}

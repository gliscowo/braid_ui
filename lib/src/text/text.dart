import 'dart:ffi';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../native/harfbuzz.dart';
import 'text_renderer.dart';

class TextSpan {
  final String content;
  final TextStyle style;
  const TextSpan(this.content, {this.style = const TextStyle()});
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
  final List<TextSpan> _spans;
  final List<ShapedGlyph> _shapedGlyphs = [];
  (int, int)? _lastShapingKey;

  Text.string(String value, {TextStyle style = const TextStyle()}) : this([TextSpan(value, style: style)]);

  Text(this._spans) {
    if (_spans.isEmpty) throw ArgumentError('Text must have at least one span');
  }

  List<ShapedGlyph> get glyphs => _shapedGlyphs;

  bool isShapingCacheValid(double size, int generation) => (Font.toPixelSize(size), generation) == _lastShapingKey;

  @internal
  void shape(FontLookup fontLookup, double size, int generation) {
    _shapedGlyphs.clear();
    int cursorX = 0, cursorY = 0;

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    for (final span in _spans) {
      final spanFont = fontLookup(span.style.fontFamily);

      final buffer = harfbuzz.buffer_create();

      final bufferContent = /*String.fromCharCodes(logicalToVisual(*/
          span.content /*))*/ .toNativeUtf16();
      harfbuzz.buffer_add_utf16(buffer, bufferContent.cast(), -1, 0, -1);
      malloc.free(bufferContent);

      harfbuzz.buffer_guess_segment_properties(buffer);
      harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
      harfbuzz.shape(spanFont.fontForStyle(span.style).getHbFont(size), buffer, features, 1);

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

      final glyphs = glpyhCount.value;
      malloc.free(glpyhCount);

      for (var i = 0; i < glyphs; i++) {
        _shapedGlyphs.add(ShapedGlyph._(
          spanFont.fontForStyle(span.style),
          glyphInfo[i].codepoint,
          Vector2(
            cursorX + glyphPos[i].x_offset.toDouble() * span.style.scale,
            cursorY + glyphPos[i].y_offset.toDouble() * span.style.scale,
          ),
          Vector2(
            glyphPos[i].x_advance.toDouble(),
            glyphPos[i].y_advance.toDouble(),
          ),
          span.style,
          glyphInfo[i].cluster,
        ));

        cursorX += (glyphPos[i].x_advance * span.style.scale).round();
        cursorY += (glyphPos[i].y_advance * span.style.scale).round();
      }

      harfbuzz.buffer_destroy(buffer);
    }

    malloc.free(features);
    _lastShapingKey = (Font.toPixelSize(size), generation);
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

import 'dart:ffi';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../native/harfbuzz.dart';
import 'text_renderer.dart';

typedef FontLookup = FontFamily Function(String? fontFamily);

// ---

class TextStyle {
  static const empty = TextStyle();

  final Color? color;
  final String? fontFamily;
  final bool? bold;
  final bool? italic;
  final double? scale;

  const TextStyle({
    this.color,
    this.fontFamily,
    this.bold,
    this.italic,
    this.scale,
  });

  TextStyle copy({
    Color? color,
    String? fontFamily,
    bool? bold,
    bool? italic,
    double? scale,
  }) =>
      TextStyle(
        color: color ?? this.color,
        fontFamily: fontFamily ?? this.fontFamily,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        scale: scale ?? this.scale,
      );

  TextStyle overriding(TextStyle other) => TextStyle(
        color: color ?? other.color,
        fontFamily: fontFamily ?? other.fontFamily,
        bold: bold ?? other.bold,
        italic: italic ?? other.italic,
        scale: scale ?? other.scale,
      );

  get _props => (color, fontFamily, bold, italic, scale);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is TextStyle && other._props == _props;
}

// ---

class Span {
  final String content;
  final TextStyle style;
  const Span(this.content, {this.style = const TextStyle()});
}

class Text {
  final List<Span> _spans;
  final List<ShapedGlyph> _shapedGlyphs = [];
  final TextStyle style;

  (int, int)? _lastShapingKey;

  Text.string(String value, {TextStyle style = TextStyle.empty}) : this([Span(value)], style: style);

  Text(this._spans, {this.style = TextStyle.empty}) {
    if (_spans.isEmpty) throw ArgumentError('Text must have at least one span');
  }

  Text copy({TextStyle? style}) => Text(_spans, style: style ?? this.style);

  List<ShapedGlyph> get glyphs => _shapedGlyphs;

  @internal
  bool isShapingCacheValid(double size, int generation) => (Font.toPixelSize(size), generation) == _lastShapingKey;

  @internal
  void shape(FontLookup fontLookup, double size, int generation) {
    _shapedGlyphs.clear();
    int cursorX = 0, cursorY = 0;

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    for (final span in _spans) {
      final spanStyle = span.style.overriding(style);
      final spanScale = spanStyle.scale ?? 1;
      final spanFontFamily = fontLookup(spanStyle.fontFamily);

      final buffer = harfbuzz.buffer_create();

      final bufferContent = /*String.fromCharCodes(logicalToVisual(*/ span.content /*))*/ .toNativeUtf16();
      harfbuzz.buffer_add_utf16(buffer, bufferContent.cast(), -1, 0, -1);
      malloc.free(bufferContent);

      harfbuzz.buffer_guess_segment_properties(buffer);
      harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
      harfbuzz.shape(spanFontFamily.fontForStyle(spanStyle).getHbFont(size), buffer, features, 1);

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

      final glyphs = glpyhCount.value;
      malloc.free(glpyhCount);

      for (var i = 0; i < glyphs; i++) {
        _shapedGlyphs.add(ShapedGlyph._(
          spanFontFamily.fontForStyle(spanStyle),
          glyphInfo[i].codepoint,
          (
            x: cursorX + glyphPos[i].x_offset.toDouble() * spanScale,
            y: cursorY + glyphPos[i].y_offset.toDouble() * spanScale,
          ),
          (
            x: glyphPos[i].x_advance.toDouble(),
            y: glyphPos[i].y_advance.toDouble(),
          ),
          spanStyle,
          glyphInfo[i].cluster,
        ));

        cursorX += (glyphPos[i].x_advance * spanScale).round();
        cursorY += (glyphPos[i].y_advance * spanScale).round();
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
  final ({double x, double y}) position;
  final ({double x, double y}) advance;
  final TextStyle style;
  final int cluster;
  ShapedGlyph._(this.font, this.index, this.position, this.advance, this.style, this.cluster);
}

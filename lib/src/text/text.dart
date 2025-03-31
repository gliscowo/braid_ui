import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../native/harfbuzz.dart';
import 'text_renderer.dart';

typedef FontLookup = FontFamily Function(String? fontFamily);

// ---

class SpanStyle {
  final Color color;
  final double fontSize;
  final String fontFamily;
  final bool bold;
  final bool italic;
  final double? lineHeight;

  const SpanStyle({
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.bold,
    required this.italic,
    this.lineHeight,
  });

  // for now we'll leave it at this, since it's a lot nicer to implement and shorter.
  // however, quick benchmarks indicate that this is ~4x slower than a full manual
  // impl so we might change it in the future should it ever becomer relevant
  get _props => (color, fontSize, fontFamily, bold, italic, lineHeight);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is SpanStyle && other._props == _props;
}

// ---

class Span {
  final String content;
  final SpanStyle style;
  const Span(this.content, this.style);

  @override
  int get hashCode => Object.hash(content, style);

  @override
  bool operator ==(Object other) => other is Span && other.content == content && other.style == style;
}

class Paragraph {
  final List<Span> _spans;
  final List<ShapedGlyph> _shapedGlyphs = [];

  int? _lastShapingKey;

  Paragraph(this._spans) {
    assert(_spans.isNotEmpty, 'each paragraph must have at least one span');
  }

  List<Span> get spans => UnmodifiableListView(_spans);
  List<ShapedGlyph> get glyphs => UnmodifiableListView(_shapedGlyphs);

  @internal
  bool isShapingCacheValid(int generation) => generation == _lastShapingKey;

  @internal
  void shape(FontLookup fontLookup, int generation) {
    _shapedGlyphs.clear();
    int cursorX = 0, cursorY = 0;

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    for (final span in _spans) {
      final spanSize = span.style.fontSize;
      final spanFontFamily = fontLookup(span.style.fontFamily);

      final buffer = harfbuzz.buffer_create();

      final bufferContent = /*String.fromCharCodes(logicalToVisual(*/ span.content /*))*/ .toNativeUtf16();
      harfbuzz.buffer_add_utf16(buffer, bufferContent.cast(), -1, 0, -1);
      malloc.free(bufferContent);

      harfbuzz.buffer_guess_segment_properties(buffer);
      harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
      harfbuzz.shape(spanFontFamily.fontForStyle(span.style).getHbFont(spanSize), buffer, features, 1);

      final glpyhCount = malloc<UnsignedInt>();
      final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
      final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

      final glyphs = glpyhCount.value;
      malloc.free(glpyhCount);

      for (var i = 0; i < glyphs; i++) {
        _shapedGlyphs.add(
          ShapedGlyph._(
            spanFontFamily.fontForStyle(span.style),
            glyphInfo[i].codepoint,
            (x: cursorX + glyphPos[i].x_offset.toDouble(), y: cursorY + glyphPos[i].y_offset.toDouble()),
            (x: glyphPos[i].x_advance.toDouble(), y: glyphPos[i].y_advance.toDouble()),
            span.style,
            glyphInfo[i].cluster,
          ),
        );

        cursorX += (glyphPos[i].x_advance).round();
        cursorY += (glyphPos[i].y_advance).round();
      }

      harfbuzz.buffer_destroy(buffer);
    }

    malloc.free(features);
    _lastShapingKey = generation;
  }

  @override
  int get hashCode => const ListEquality<Span>().hash(_spans);

  @override
  bool operator ==(Object other) => other is Paragraph && const ListEquality<Span>().equals(other._spans, _spans);
}

class ShapedGlyph {
  final Font font;
  final int index;
  final ({double x, double y}) position;
  final ({double x, double y}) advance;
  final SpanStyle style;
  final int cluster;
  ShapedGlyph._(this.font, this.index, this.position, this.advance, this.style, this.cluster);
}

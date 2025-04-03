import 'dart:collection';
import 'dart:ffi' hide Size;
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../core/math.dart';
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

final class Span {
  final String content;
  final SpanStyle style;
  const Span(this.content, this.style);

  (Span, Span) _split(int at, {bool keepSplitChar = true}) => (
    Span(content.substring(0, at), style),
    Span(content.substring(keepSplitChar ? at : at + 1), style),
  );

  @override
  int get hashCode => Object.hash(content, style);

  @override
  bool operator ==(Object other) => other is Span && other.content == content && other.style == style;
}

class Paragraph {
  final List<Span> _spans;
  final List<ShapedGlyph> _shapedGlyphs = [];

  (int, double)? _lastShapingKey;
  ParagraphMetrics? _metrics;

  Paragraph(this._spans) {
    assert(_spans.isNotEmpty, 'each paragraph must have at least one span');
  }

  List<Span> get spans => UnmodifiableListView(_spans);
  List<ShapedGlyph> get glyphs => UnmodifiableListView(_shapedGlyphs);

  @internal
  ParagraphMetrics get metrics {
    assert(_lastShapingKey != null, 'paragraph metrics may only be accessed after the paragraph has been shaped');
    return _metrics!;
  }

  @internal
  bool isShapingCacheValid(int generation, double maxWidth) => (generation, maxWidth) == _lastShapingKey;

  // ---
  static const _newline = 0xa;
  static const _space = 0x20;
  static const _zwsp = 0x200b;
  // ---

  @internal
  void layout(FontLookup fontLookup, double maxWidth, int generation) {
    _shapedGlyphs.clear();

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    final session = _LayoutSession(features, fontLookup, maxWidth);
    final spansForShaping = Queue.of(spans);

    while (spansForShaping.isNotEmpty) {
      var spanToShape = spansForShaping.removeFirst();

      final breakPoints = Queue<int>();
      var insertBreakAfterShaping = false;

      for (final (index, codeUnit) in spanToShape.content.codeUnits.indexed) {
        if (codeUnit == _space || codeUnit == _zwsp) {
          breakPoints.addLast(index);
        } else if (codeUnit == _newline) {
          final (left, right) = spanToShape._split(index, keepSplitChar: false);

          spanToShape = left;
          spansForShaping.addFirst(right);
          insertBreakAfterShaping = true;

          break;
        }
      }

      final shapedSpan = _ShapedSpan(spanToShape, breakPoints, session.state.copy());
      session.shapedSpans.addLast(shapedSpan);
      if (breakPoints.isNotEmpty) {
        session.lastSpanWithBreakPoint = shapedSpan;
      }

      if (!_shapeSpan(session, shapedSpan)) {
        ({_ShapedSpan span, int index, bool keepSplit})? breakPoint;
        if (session.lastSpanWithBreakPoint != null) {
          while (session.shapedSpans.last != session.lastSpanWithBreakPoint) {
            session.shapedSpans.removeLast();
          }

          while (session.lastSpanWithBreakPoint!.possibleBreakIndices.isNotEmpty) {
            final (index, position) = (
              session.lastSpanWithBreakPoint!.possibleBreakIndices.removeLast(),
              session.lastSpanWithBreakPoint!.possibleBreakPositions.removeLast(),
            );
            if (position <= session.maxWidth) {
              breakPoint = (span: session.lastSpanWithBreakPoint!, index: index, keepSplit: false);
              break;
            }
          }
        }

        if (breakPoint == null) {
          for (final glyph in shapedSpan.shapedGlyphs.reversed) {
            if (glyph.position.x + glyph.advance.x < session.maxWidth) {
              breakPoint = (span: shapedSpan, index: glyph.cluster + 1, keepSplit: true);
              break;
            }
          }
        }

        if (breakPoint != null) {
          session.state.setFrom(breakPoint.span.stateBeforeShaping);
          final (left, right) = breakPoint.span.split(breakPoint.index, keepSplitChar: breakPoint.keepSplit);

          spansForShaping.addFirst(right);

          session.shapedSpans.removeLast();
          session.lastSpanWithBreakPoint = null;

          session.shapedSpans.add(left);
          if (left.possibleBreakIndices.isNotEmpty) {
            session.lastSpanWithBreakPoint = left;
          }

          if (_shapeSpan(session, left)) {
            _insertLineBreak(session);
          } else {
            // if the left span has somehow gotten longer after splitting, we must simply
            // repeat the entire shaping and splitting process, no two ways about it
            spansForShaping.addFirst(left.span);
          }
        } else {
          // if we somehow ended up here there is (probably) only two possible cases:
          // 1 - this span is after another span (ie. the cursor's x position is not zero)
          //     and just so happens to start with the character where the line break must be.
          //     in this case we insert a line break and try again
          // 2 - this span is at the beginning of a new line and even just the first glyph does
          //     not fit in the width limit. in that case there is really nothing to do but give up,
          //     so that's what we do

          if (shapedSpan.stateBeforeShaping.cursorX != 0) {
            _insertLineBreak(session);
            spansForShaping.addFirst(shapedSpan.span);
          }
        }

        continue;
      }

      if (insertBreakAfterShaping) {
        _insertLineBreak(session);
      }
    }

    if (session.state.currentLineWidth != 0 || session.state.currentLineHeight != 0) {
      _insertLineBreak(session);
    }

    malloc.free(features);
    _lastShapingKey = (generation, maxWidth);
    _metrics = ParagraphMetrics(
      width: session.paragraphWidth ?? session.state.currentLineWidth,
      height: (session.paragraphHeight ?? 0) + session.state.currentLineHeight,
      initialBaselineY: session.initialBaselineY ?? session.state.currentLineBaseline,
      lineMetrics: session.lineMetrics,
    );
  }

  bool _shapeSpan(_LayoutSession session, _ShapedSpan shapedSpan) {
    final state = session.state;
    final span = shapedSpan.span;

    final spanSize = span.style.fontSize;
    final spanFont = session.fontLookup(span.style.fontFamily).fontForStyle(span.style);

    final buffer = harfbuzz.buffer_create();

    final bufferContent = /*String.fromCharCodes(logicalToVisual(*/ span.content /*))*/ .toNativeUtf16();
    harfbuzz.buffer_add_utf16(buffer, bufferContent.cast(), -1, 0, -1);
    malloc.free(bufferContent);

    harfbuzz.buffer_guess_segment_properties(buffer);
    harfbuzz.buffer_set_cluster_level(buffer, hb_buffer_cluster_level.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS);
    harfbuzz.shape(spanFont.getHbFont(spanSize), buffer, session.features, 1);

    final glpyhCount = malloc<UnsignedInt>();
    final glyphInfo = harfbuzz.buffer_get_glyph_infos(buffer, glpyhCount);
    final glyphPos = harfbuzz.buffer_get_glyph_positions(buffer, glpyhCount);

    final glyphs = glpyhCount.value;
    malloc.free(glpyhCount);

    final shapedGlyphs = <ShapedGlyph>[];

    for (var i = 0; i < glyphs; i++) {
      shapedGlyphs.add(
        ShapedGlyph._(
          spanFont,
          glyphInfo[i].codepoint,
          (
            x: state.cursorX + hbToPixels(glyphPos[i].x_offset).toDouble(),
            y: state.cursorY + hbToPixels(glyphPos[i].y_offset).toDouble(),
          ),
          (x: hbToPixels(glyphPos[i].x_advance).toDouble(), y: hbToPixels(glyphPos[i].y_advance).toDouble()),
          span.style,
          glyphInfo[i].cluster,
        ),
      );

      state.cursorX += hbToPixels(glyphPos[i].x_advance);
      state.cursorY += hbToPixels(glyphPos[i].y_advance);
    }

    harfbuzz.buffer_destroy(buffer);

    shapedSpan.shapedGlyphs = shapedGlyphs;
    for (final breakPosition in shapedSpan.possibleBreakIndices) {
      shapedSpan.possibleBreakPositions.add(
        shapedSpan.stateBeforeShaping.cursorX + _charIdxToClusterPos(shapedGlyphs, breakPosition),
      );
    }

    if (state.cursorX > session.maxWidth) {
      return false;
    }

    _shapedGlyphs.addAll(shapedGlyphs);

    var spanBaselineY = spanFont.ascender * spanSize;

    if (span.style.lineHeight != null) {
      spanBaselineY += ((span.style.lineHeight! - spanFont.lineHeight) * .5 * spanSize).ceil();
    }

    state.currentLineBaseline = max(state.currentLineBaseline, spanBaselineY);

    state.currentLineWidth = max(state.currentLineWidth, state.cursorX.toDouble());
    state.currentLineHeight = max(state.currentLineHeight, (span.style.lineHeight ?? spanFont.lineHeight) * spanSize);

    return true;
  }

  void _insertLineBreak(_LayoutSession session) {
    final state = session.state;

    state.cursorX = 0;
    state.cursorY += state.currentLineHeight.ceil();

    session.initialBaselineY ??= state.currentLineBaseline;
    session.paragraphWidth = max(session.paragraphWidth ?? 0, state.currentLineWidth);
    session.paragraphHeight = (session.paragraphHeight ?? 0) + state.currentLineHeight;

    session.lineMetrics.add(LineMetrics(width: state.currentLineWidth, height: state.currentLineHeight));

    state.currentLineWidth = 0;
    state.currentLineHeight = 0;
    state.currentLineBaseline = 0;
  }

  double _charIdxToClusterPos(List<ShapedGlyph> glyphs, int charIdx) {
    if (glyphs.isEmpty || charIdx == 0) return 0;

    var pos = 0.0;

    for (var glyphIdx = 0; glyphIdx < glyphs.length && glyphs[glyphIdx].cluster < charIdx; glyphIdx++) {
      var glyph = glyphs[glyphIdx];
      pos += glyph.advance.x;
    }

    return pos;
  }

  @override
  int get hashCode => const ListEquality<Span>().hash(_spans);

  @override
  bool operator ==(Object other) => other is Paragraph && const ListEquality<Span>().equals(other._spans, _spans);
}

class _LayoutSession {
  final Pointer<hb_feature> features;
  final FontLookup fontLookup;
  final double maxWidth;

  final Queue<_ShapedSpan> shapedSpans = Queue();
  _ShapedSpan? lastSpanWithBreakPoint;

  final _LayoutState state = _LayoutState();

  final List<LineMetrics> lineMetrics = [];
  double? paragraphWidth, paragraphHeight;
  double? initialBaselineY;

  _LayoutSession(this.features, this.fontLookup, this.maxWidth);
}

class _LayoutState {
  double cursorX, cursorY;

  double currentLineWidth;
  double currentLineHeight;
  double currentLineBaseline;

  _LayoutState({
    this.cursorX = 0,
    this.cursorY = 0,
    this.currentLineWidth = 0,
    this.currentLineHeight = 0,
    this.currentLineBaseline = 0,
  });

  void setFrom(_LayoutState source) {
    cursorX = source.cursorX;
    cursorY = source.cursorY;
    currentLineWidth = source.currentLineWidth;
    currentLineHeight = source.currentLineHeight;
    currentLineBaseline = source.currentLineBaseline;
  }

  _LayoutState copy() => _LayoutState(
    cursorX: cursorX,
    cursorY: cursorY,
    currentLineWidth: currentLineWidth,
    currentLineHeight: currentLineHeight,
    currentLineBaseline: currentLineBaseline,
  );
}

class _ShapedSpan {
  final Span span;
  final Queue<int> possibleBreakIndices;
  final Queue<double> possibleBreakPositions = Queue();
  final _LayoutState stateBeforeShaping;

  late List<ShapedGlyph> shapedGlyphs;

  (_ShapedSpan, Span) split(int at, {bool keepSplitChar = true}) {
    final (leftSpan, rightSpan) = span._split(at, keepSplitChar: keepSplitChar);
    final leftIndices = Queue.of(possibleBreakIndices.takeWhile((value) => value < at));

    return (_ShapedSpan(leftSpan, leftIndices, stateBeforeShaping), rightSpan);
  }

  _ShapedSpan(this.span, this.possibleBreakIndices, this.stateBeforeShaping);
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

class ParagraphMetrics {
  final double width, height;
  final double initialBaselineY;
  final List<LineMetrics> lineMetrics;

  ParagraphMetrics({
    required this.width,
    required this.height,
    required this.initialBaselineY,
    required this.lineMetrics,
  });

  Size get size => Size(width, height);

  @override
  String toString() =>
      'ParagraphMetrics(width=$width, height=$height, initialBaselineY=$initialBaselineY, lineMetrics=$lineMetrics)';
}

class LineMetrics {
  final double width, height;
  LineMetrics({required this.width, required this.height});

  @override
  String toString() => 'LineMetrics(width=$width, height=$height)';
}

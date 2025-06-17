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

enum SpanComparison {
  /// The spans describe the same text, nothing changed
  equal,

  /// The spans describe different text, but a purely
  /// visual attribute (like color) changed, which does
  /// not affect the layout
  visualsChanged,

  /// The spans describe different text and the
  /// layout must be recomputed
  layoutChanged;

  static SpanComparison max(SpanComparison a, SpanComparison b) {
    if (a == layoutChanged || b == layoutChanged) return layoutChanged;
    if (a == visualsChanged || b == visualsChanged) return visualsChanged;
    return equal;
  }
}

// ---

class SpanStyle {
  final Color color;
  final double fontSize;
  final String? fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;
  final double? lineHeight;

  const SpanStyle({
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.bold,
    required this.italic,
    required this.underline,
    this.lineHeight,
  });

  SpanStyle copy({
    Color? color,
    double? fontSize,
    String? fontFamily,
    bool? bold,
    bool? italic,
    bool? underline,
    double? lineHeight,
  }) => SpanStyle(
    color: color ?? this.color,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    lineHeight: lineHeight ?? this.lineHeight,
  );

  static SpanComparison compare(SpanStyle a, SpanStyle b) {
    if (a.fontSize != b.fontSize ||
        a.fontFamily != b.fontFamily ||
        a.bold != b.bold ||
        a.italic != b.italic ||
        a.lineHeight != b.lineHeight) {
      return SpanComparison.layoutChanged;
    }

    if (a.color != b.color || a.underline != b.underline) {
      return SpanComparison.visualsChanged;
    }

    return SpanComparison.equal;
  }

  @Deprecated('use SpanStyle.compare instead')
  @override
  int get hashCode => super.hashCode;

  @Deprecated('use SpanStyle.compare instead')
  @override
  bool operator ==(Object other) => super == other;
}

// ---

final class Span {
  final String content;
  final SpanStyle style;
  const Span(this.content, this.style);

  (Span, Span) _split(int at, {int? to, bool keepSplit = true}) =>
      (Span(content.substring(0, at), style), Span(content.substring(keepSplit ? at : (to ?? at + 1)), style));

  static SpanComparison compare(Span a, Span b) {
    if (a.content != b.content) return SpanComparison.layoutChanged;
    return SpanStyle.compare(a.style, b.style);
  }

  static SpanComparison comapreLists(List<Span> a, List<Span> b) {
    if (a.length != b.length) return SpanComparison.layoutChanged;

    var result = SpanComparison.equal;
    for (var i = 0; i < a.length; i++) {
      result = SpanComparison.max(result, compare(a[i], b[i]));

      if (result == SpanComparison.layoutChanged) {
        return SpanComparison.layoutChanged;
      }
    }

    return result;
  }

  @Deprecated('use Span.compare instead')
  @override
  int get hashCode => super.hashCode;

  @Deprecated('use Span.compare instead')
  @override
  bool operator ==(Object other) => super == other;
}

typedef _BreakPoint = ({_LayoutSpan span, int index, bool keepSplit});

sealed class _LayoutInstruction {}

class _ShapeSpan extends _LayoutInstruction {
  final Span span;
  final int index;
  final int startRune, endRune;
  _ShapeSpan(this.span, this.index, this.startRune, this.endRune);
}

class _InsertNewlines extends _LayoutInstruction {
  final List<_LineBreakIndices> breakIndices;
  _InsertNewlines(this.breakIndices);
}

typedef _LineBreakIndices = ({int endIdx, int startIdx});

class Paragraph {
  List<Span> _spans;
  final List<ShapedGlyph> _shapedGlyphs = [];

  (int, double)? _lastLayoutKey;
  ParagraphMetrics? _metrics;

  Paragraph(this._spans) {
    assert(_spans.isNotEmpty, 'each paragraph must have at least one span');
  }

  void updateSpans(List<Span> newSpans) {
    assert(
      Span.comapreLists(_spans, newSpans) != SpanComparison.layoutChanged,
      'when updating the spans of a paragraph, it is the responsibility of the caller '
      'to ensure that there is no difference larger than SpanComparison.visualsChanged '
      'between the old and new lists',
    );

    _spans = newSpans;
  }

  ShapedGlyph? getGlyphForCharIndex(int charIdx) => _getGlyphForCluster(glyphs, charIdx);

  List<Span> get spans => UnmodifiableListView(_spans);
  List<ShapedGlyph> get glyphs => UnmodifiableListView(_shapedGlyphs);

  @internal
  ParagraphMetrics get metrics {
    assert(
      _lastLayoutKey != null,
      'attempted to query metrics on a paragraph which has not been laid out. '
      'was TextRenderer.layoutParagraph invoked first?',
    );
    return _metrics!;
  }

  @internal
  SpanStyle styleFor(ShapedGlyph glyph) {
    return _spans[glyph._spanIndex].style;
  }

  @internal
  bool isLayoutCacheValid(int generation, double maxWidth) => (generation, maxWidth) == _lastLayoutKey;

  @internal
  void layout(FontLookup fontLookup, double maxWidth, int generation) {
    _shapedGlyphs.clear();

    final features = malloc<hb_feature>();
    'calt on'.withAsNative((flag) => harfbuzz.feature_from_string(flag.cast(), -1, features));

    final session = _LayoutSession(features, fontLookup, maxWidth);

    final instructions = DoubleLinkedQueue<_LayoutInstruction>();
    var runeCount = 0;
    for (final (idx, span) in _spans.indexed) {
      instructions.add(_ShapeSpan(span, idx, runeCount, runeCount + span.content.length));
      runeCount += span.content.length;
    }

    while (instructions.isNotEmpty) {
      switch (instructions.removeFirst()) {
        case _ShapeSpan(
          span: var spanToShape,
          index: final spanIdx,
          startRune: final spanStartRune,
          endRune: var spanEndRune,
        ):
          final breakPoints = DoubleLinkedQueue<int>();

          final iter = spanToShape.content.runes.indexed.iterator;
          while (iter.moveNext()) {
            final (index, codeUnit) = iter.current;

            const newline = 0xa; // '\n'
            const space = 0x20; // ' '

            if (codeUnit == space) {
              breakPoints.addLast(index);
            } else if (codeUnit == newline) {
              // if we encountered a newline, we can simply split immediately
              // and queue the right half of the span for next round - this saves a trip

              var lineBreaks = [(endIdx: spanStartRune + index, startIdx: spanStartRune + index + 1)];
              while (iter.moveNext() && iter.current.$2 == newline) {
                lineBreaks.add((
                  endIdx: spanStartRune + iter.current.$1,
                  startIdx: spanStartRune + iter.current.$1 + 1,
                ));
              }

              final (left, right) = spanToShape._split(
                index,
                to: lineBreaks.last.startIdx - spanStartRune,
                keepSplit: false,
              );

              final baseEndRune = spanEndRune;
              spanToShape = left;
              spanEndRune = lineBreaks.last.startIdx;

              instructions.addFirst(_ShapeSpan(right, spanIdx, spanEndRune, baseEndRune));
              instructions.addFirst(_InsertNewlines(lineBreaks));

              break;
            }
          }

          final layoutSpan = _LayoutSpan(
            spanToShape,
            breakPoints,
            session.state.copy(),
            spanIdx,
            session.lineMetrics.length,
            spanStartRune,
            spanEndRune,
          );
          session.layoutSpans.add(layoutSpan);

          if (!_shapeSpan(session, layoutSpan, spanIdx)) {
            _BreakPoint? breakPoint;

            // first, try to find a suitable user-indicated break point in the input text
            for (var candidateIdx = session.layoutSpans.length - 1; candidateIdx >= 0; candidateIdx--) {
              final candidateSpan = session.layoutSpans[candidateIdx];

              if (breakPoint != null || candidateSpan.lineIdx < session.lineMetrics.length) {
                break;
              }

              while (candidateSpan.possibleBreakPoints.isNotEmpty) {
                final breakIndex = candidateSpan.possibleBreakPoints.removeLast();
                final glyph = _getGlyphForCluster(candidateSpan.shapedGlyphs, candidateSpan.startRune + breakIndex)!;

                if (glyph.position.x <= session.maxWidth) {
                  breakPoint = (span: candidateSpan, index: breakIndex, keepSplit: false);

                  for (var popIdx = session.layoutSpans.length - 1; popIdx > candidateIdx; popIdx--) {
                    final poppedSpan = session.layoutSpans.removeAt(popIdx);
                    instructions.addFirst(
                      _ShapeSpan(poppedSpan.content, poppedSpan.contentIdx, poppedSpan.startRune, poppedSpan.endRune),
                    );
                  }

                  break;
                }
              }
            }

            // now, if that didn't work, try to find the last glyph (and corresponding char)
            // which fully fits into the width limit and break after that
            if (breakPoint == null) {
              for (final glyph in layoutSpan.shapedGlyphs.reversed) {
                if (glyph.position.x + glyph.advance.x < session.maxWidth) {
                  breakPoint = (span: layoutSpan, index: glyph.cluster + 1 - layoutSpan.startRune, keepSplit: true);
                  break;
                }
              }
            }

            if (breakPoint != null) {
              // now, that we've hopefully finally found a reasonable spot for the line break,
              // reset the cursor position and line metrics to the appropriate point and split
              // the corresponding span
              session.state.setFrom(breakPoint.span.stateBeforeShaping);
              final (left, right) = breakPoint.span.split(breakPoint.index, keepSplit: breakPoint.keepSplit);

              // we must also take care to remove the span we just tried
              // to shape from the output
              session.layoutSpans.removeLast();

              if (_shapeSpan(session, left, spanIdx)) {
                // if we managed to successfully shape the span now
                // (ideally the 99% case), record that fact
                session.layoutSpans.add(left);

                _startNewLine(session, [
                  (
                    endIdx: breakPoint.span.startRune + breakPoint.index,
                    startIdx:
                        breakPoint.span.startRune + (breakPoint.keepSplit ? breakPoint.index : breakPoint.index + 1),
                  ),
                ]);
              } else {
                // if the left span has somehow gotten longer after splitting, we must simply
                // repeat the entire shaping and splitting process, no two ways about it
                instructions.addFirst(_ShapeSpan(left.content, spanIdx, left.startRune, left.endRune));
              }

              // finally, queue up the other half we just split off
              instructions.addFirst(_ShapeSpan(right, spanIdx, left.endRune, breakPoint.span.endRune));
            } else {
              // if we somehow ended up here there is (probably) only two possible cases:
              // 1 - this span is after another span (ie. the cursor's x position is not zero)
              //     and just so happens to start with the character where the line break must be.
              //     in this case we insert a line break and try again
              // 2 - this span is at the beginning of a new line and even just the first glyph does
              //     not fit in the width limit. in that case there is really nothing to do but give up,
              //     so that's what we do
              //     TODO: ok, actually we maybe do still wanna split after the first char

              if (layoutSpan.stateBeforeShaping.cursorX != 0) {
                _startNewLine(session, [(endIdx: spanStartRune, startIdx: spanStartRune)]);

                // let's pretend everything we just did never happened :)
                session.layoutSpans.removeLast();
                instructions.addFirst(_ShapeSpan(layoutSpan.content, spanIdx, spanStartRune, spanEndRune));
              }
            }

            continue;
          }

        case _InsertNewlines(breakIndices: final breakIndices):
          _startNewLine(session, breakIndices);
      }
    }

    for (final layoutSpan in session.layoutSpans) {
      _shapedGlyphs.addAll(layoutSpan.shapedGlyphs);
    }

    if (session.state.currentLineWidth != 0 || session.state.currentLineHeight != 0) {
      _startNewLine(session, [(endIdx: session.layoutSpans.last.endRune, startIdx: 0)]);
    }

    malloc.free(features);
    _lastLayoutKey = (generation, maxWidth);
    _metrics = ParagraphMetrics(
      width: session.paragraphWidth ?? session.state.currentLineWidth,
      height: (session.paragraphHeight ?? 0) + session.state.currentLineHeight,
      initialBaselineY: session.initialBaselineY ?? session.state.currentLineBaseline,
      lineMetrics: session.lineMetrics,
    );
  }

  bool _shapeSpan(_LayoutSession session, _LayoutSpan layoutSpan, int spanIdx) {
    final state = session.state;
    final span = layoutSpan.content;

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
          (x: state.cursorX, y: state.cursorY),
          (x: hbToPixels(glyphPos[i].x_offset).toDouble(), y: hbToPixels(glyphPos[i].y_offset).toDouble()),
          (x: hbToPixels(glyphPos[i].x_advance).toDouble(), y: hbToPixels(glyphPos[i].y_advance).toDouble()),
          spanIdx,
          layoutSpan.startRune + glyphInfo[i].cluster,
          layoutSpan.lineIdx,
        ),
      );

      state.cursorX += hbToPixels(glyphPos[i].x_advance);
      state.cursorY += hbToPixels(glyphPos[i].y_advance);
    }

    harfbuzz.buffer_destroy(buffer);

    layoutSpan.shapedGlyphs = shapedGlyphs;

    if (state.cursorX > session.maxWidth) {
      return false;
    }

    var spanBaselineY = spanFont.ascender * spanSize;
    var spanDescender = spanFont.descender.abs() * spanSize;

    if (span.style.lineHeight != null) {
      final adjustment = (span.style.lineHeight! - spanFont.lineHeight) * .5 * spanSize;
      spanBaselineY += adjustment;
      spanDescender += adjustment;
    }

    state.currentLineBaseline = max(state.currentLineBaseline, spanBaselineY);
    state.currentLineDescender = max(state.currentLineDescender, spanDescender);

    state.currentLineWidth = max(state.currentLineWidth, state.cursorX.toDouble());
    state.currentLineHeight = max(state.currentLineHeight, (span.style.lineHeight ?? spanFont.lineHeight) * spanSize);

    return true;
  }

  void _startNewLine(_LayoutSession session, List<_LineBreakIndices> breaks) {
    final state = session.state;

    session.initialBaselineY ??= state.currentLineBaseline;
    session.paragraphWidth = max(session.paragraphWidth ?? 0, state.currentLineWidth);
    session.paragraphHeight = session.initialBaselineY! + state.cursorY + state.currentLineDescender;

    for (final lineBreak in breaks) {
      session.lineMetrics.add(
        LineMetrics(
          yOffset: state.cursorY,
          width: state.currentLineWidth,
          height: state.currentLineHeight,
          descender: state.currentLineDescender,
          startRune: session.state.currentLineStartIdx,
          endRune: lineBreak.endIdx,
        ),
      );

      state.cursorY += state.currentLineHeight.ceil();
      session.state.currentLineStartIdx = lineBreak.startIdx;
    }

    state.cursorX = 0;

    state.currentLineWidth = 0;
    state.currentLineHeight = 0;
    state.currentLineBaseline = 0;
  }

  ShapedGlyph? _getGlyphForCluster(List<ShapedGlyph> glyphs, int charIdx) {
    if (glyphs.isEmpty) return null;
    if (charIdx <= 0) return glyphs.first;

    for (var glyphIdx = 0; glyphIdx < glyphs.length; glyphIdx++) {
      final glyph = glyphs[glyphIdx];

      if (glyph.cluster == charIdx) {
        return glyph;
      } else if (glyph.cluster > charIdx) {
        return glyphs[glyphIdx - 1];
      }
    }

    return glyphs.last;
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

  final List<_LayoutSpan> layoutSpans = [];

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
  double currentLineDescender;
  int currentLineStartIdx;

  _LayoutState({
    this.cursorX = 0,
    this.cursorY = 0,
    this.currentLineWidth = 0,
    this.currentLineHeight = 0,
    this.currentLineBaseline = 0,
    this.currentLineDescender = 0,
    this.currentLineStartIdx = 0,
  });

  void setFrom(_LayoutState source) {
    cursorX = source.cursorX;
    cursorY = source.cursorY;
    currentLineWidth = source.currentLineWidth;
    currentLineHeight = source.currentLineHeight;
    currentLineBaseline = source.currentLineBaseline;
    currentLineDescender = source.currentLineDescender;
    currentLineStartIdx = source.currentLineStartIdx;
  }

  _LayoutState copy() => _LayoutState(
    cursorX: cursorX,
    cursorY: cursorY,
    currentLineWidth: currentLineWidth,
    currentLineHeight: currentLineHeight,
    currentLineBaseline: currentLineBaseline,
    currentLineDescender: currentLineDescender,
    currentLineStartIdx: currentLineStartIdx,
  );
}

class _LayoutSpan {
  final Span content;
  final Queue<int> possibleBreakPoints;
  final _LayoutState stateBeforeShaping;
  final int contentIdx;
  final int lineIdx;

  final int startRune;
  final int endRune;

  late List<ShapedGlyph> shapedGlyphs;

  (_LayoutSpan, Span) split(int at, {bool keepSplit = true}) {
    final (leftSpan, rightSpan) = content._split(at, keepSplit: keepSplit);
    final leftBreakPoints = DoubleLinkedQueue.of(possibleBreakPoints.takeWhile((value) => value < at));

    return (
      _LayoutSpan(
        leftSpan,
        leftBreakPoints,
        stateBeforeShaping,
        contentIdx,
        lineIdx,
        startRune,
        startRune + (keepSplit ? at : at + 1),
      ),
      rightSpan,
    );
  }

  _LayoutSpan(
    this.content,
    this.possibleBreakPoints,
    this.stateBeforeShaping,
    this.contentIdx,
    this.lineIdx,
    this.startRune,
    this.endRune,
  );
}

class ShapedGlyph {
  final Font font;
  final int index;
  final ({double x, double y}) position;
  final ({double x, double y}) drawOffset;
  final ({double x, double y}) advance;
  final int _spanIndex;
  final int cluster;
  final int line;
  ShapedGlyph._(
    this.font,
    this.index,
    this.position,
    this.drawOffset,
    this.advance,
    this._spanIndex,
    this.cluster,
    this.line,
  );
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
  final double yOffset;
  final double width, height;
  final double descender;
  final int startRune, endRune;
  LineMetrics({
    required this.yOffset,
    required this.width,
    required this.height,
    required this.descender,
    required this.startRune,
    required this.endRune,
  });

  @override
  String toString() => 'LineMetrics(width=$width, height=$height, startRune=$startRune, endRune=$endRune)';
}

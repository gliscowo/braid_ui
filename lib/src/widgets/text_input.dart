import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:unicode/unicode.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../core/cursors.dart';
import '../core/key_modifiers.dart';
import '../core/listenable.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import '../text/text_layout.dart';
import 'basic.dart';

class TextSelection {
  final int start, end;

  const TextSelection(this.start, this.end);
  const TextSelection.collapsed(int cursorPosition) : start = cursorPosition, end = cursorPosition;

  int get lower => min(start, end);
  int get upper => max(start, end);

  bool get collapsed => start == end;
}

class TextEditingController with Listenable {
  String _text;
  TextSelection _selection;

  TextEditingController({String text = '', TextSelection? selection})
    : _selection = selection ?? TextSelection.collapsed(text.length),
      _text = text;

  String get text => _text;
  set text(String value) {
    if (_text == value) return;

    _text = value;
    notifyListeners();
  }

  TextSelection get selection => _selection;
  set selection(TextSelection value) {
    if (_selection == value) return;

    _selection = value;
    notifyListeners();
  }

  List<Span> createSpans(SpanStyle baseStyle) => [Span(_text, baseStyle)];
}

class TextInput extends LeafInstanceWidget {
  final TextEditingController controller;
  final bool showCursor;
  final bool softWrap;
  final bool autoFocus;
  final bool allowMultipleLines;
  final SpanStyle style;

  TextInput({
    super.key,
    required this.controller,
    required this.showCursor,
    required this.softWrap,
    required this.autoFocus,
    required this.allowMultipleLines,
    required this.style,
  });

  @override
  LeafWidgetInstance<InstanceWidget> instantiate() => TextInputInstance(widget: this);
}

typedef _CursorLocation = ({int line, int rune});

class TextInputInstance extends LeafWidgetInstance<TextInput> with KeyboardListener, MouseListener {
  String _text;
  TextSelection _selection;

  String _layoutText;
  TextSelection _layoutSelection;

  _CursorLocation _cursorLocation = (line: 0, rune: 0);

  late Paragraph _paragraph;

  TextInputInstance({required super.widget})
    : _text = widget.controller.text,
      _selection = widget.controller.selection,
      _layoutText = widget.controller.text,
      _layoutSelection = widget.controller.selection {
    if (widget.autoFocus) requestFocus();
  }

  ({double x, double y}) get cursorPosition {
    final (x, y, _) = _coordinatesAtRuneIdx(_selection.end);
    return (x: x, y: y);
  }

  LineMetrics get currentLine => _paragraph.metrics.lineMetrics[_cursorLocation.line];

  @override
  set widget(TextInput value) {
    if (!(_layoutText == value.controller.text &&
        _layoutSelection == value.controller.selection &&
        widget.softWrap == value.softWrap &&
        widget.allowMultipleLines == value.allowMultipleLines &&
        SpanStyle.compare(widget.style, value.style) == SpanComparison.equal)) {
      _layoutText = _text = widget.controller.text;
      _layoutSelection = _selection = widget.controller.selection;

      markNeedsLayout();
    }

    super.widget = value;
  }

  @override
  void doLayout(Constraints constraints) {
    final maxWidth = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;

    _paragraph = Paragraph(widget.controller.createSpans(widget.style));
    host!.textRenderer.layoutParagraph(_paragraph, widget.softWrap ? maxWidth : double.infinity);

    var size = Size(_paragraph.metrics.width + 2, _paragraph.metrics.height).constrained(constraints);
    transform.setSize(size);

    final newLineIdx = _lineIdxAtRuneIdx(_selection.end);
    _cursorLocation = (line: newLineIdx, rune: _selection.end - _paragraph.metrics.lineMetrics[newLineIdx].startRune);
  }

  @override
  double measureIntrinsicWidth(double height) =>
      host!.textRenderer
          .layoutParagraph(Paragraph(widget.controller.createSpans(widget.style)), double.infinity)
          .width +
      2;

  @override
  double measureIntrinsicHeight(double width) => host!.textRenderer
      .layoutParagraph(
        Paragraph(widget.controller.createSpans(widget.style)),
        widget.softWrap ? width : double.infinity,
      )
      .height;

  @override
  double? measureBaselineOffset() => _paragraph.metrics.initialBaselineY;

  @override
  void draw(DrawContext ctx) {
    if (!_selection.collapsed) {
      final startLine = _lineIdxAtRuneIdx(_selection.lower);
      final endLine = _lineIdxAtRuneIdx(_selection.upper);

      void drawSelection(int startRune, int endRune) {
        final (startX, _, _) = _coordinatesAtRuneIdx(startRune);
        final (endX, y, height) = _coordinatesAtRuneIdx(endRune);
        ctx.transform.scope((mat4) {
          mat4.translate(startX, y - height - 1);

          var width = endX - startX;
          if (startRune == endRune) width = 5;

          ctx.primitives.rect(width, height + 2, const Color.rgb(0x3A59D1), mat4, ctx.projection);
        });
      }

      if (startLine == endLine) {
        drawSelection(_selection.lower, _selection.upper);
      } else {
        drawSelection(_selection.lower, _paragraph.metrics.lineMetrics[startLine].endRune);
        for (var lineIdx = startLine + 1; lineIdx < endLine; lineIdx++) {
          final line = _paragraph.metrics.lineMetrics[lineIdx];
          drawSelection(line.startRune, line.endRune);
        }
        drawSelection(_paragraph.metrics.lineMetrics[startLine].startRune, _selection.upper);
      }
    }

    ctx.textRenderer.drawText(_paragraph, Alignment.topLeft, transform.toSize(), ctx.transform, ctx.projection);

    if (widget.showCursor) {
      final (xPos, yPos, lineHeight) = _coordinatesAtRuneIdx(_selection.end);

      ctx.transform.scope((mat4) {
        mat4.translate(xPos, yPos);
        ctx.primitives.rect(2, -lineHeight, Color.white, mat4, ctx.projection);
      });
    }

    // final cursorParagraph = Paragraph([
    //   Span(
    //     'length: ${_text.length} cursor: ${_selection.lower}\n$_cursorLocation',
    //     SpanStyle(color: const Color.rgb(0x94B4C1), fontSize: 10.0, fontFamily: 'cascadia', bold: false, italic: false),
    //   ),
    // ]);

    // host!.textRenderer.layoutParagraph(cursorParagraph, transform.width);
    // host!.textRenderer.drawText(
    //   cursorParagraph,
    //   Alignment.bottomRight,
    //   transform.toSize(),
    //   ctx.transform,
    //   ctx.projection,
    // );
  }

  int _lineIdxAtRuneIdx(int runeIdx) {
    int? matchedLineIdx;
    final lines = _paragraph.metrics.lineMetrics;

    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      if (runeIdx >= line.startRune && runeIdx <= line.endRune) {
        matchedLineIdx = lineIdx;

        break;
      }
    }

    return matchedLineIdx ?? lines.length - 1;
  }

  (double, double, double) _coordinatesAtRuneIdx(int runeIdx) {
    final line = _paragraph.metrics.lineMetrics[_lineIdxAtRuneIdx(runeIdx)];

    final cursorGlyph = runeIdx != line.startRune ? _paragraph.getGlyphForCharIndex(runeIdx - 1) : null;
    final x = cursorGlyph != null ? cursorGlyph.position.x + cursorGlyph.advance.x : 0.0;

    final y = line.yOffset + line.descender + _paragraph.metrics.initialBaselineY;

    return (x, y, line.height);
  }

  static final _lineBreaks = RegExp('[\r\n]');
  void _insert(String insertion) {
    if (!widget.allowMultipleLines) {
      insertion = insertion.replaceAll(_lineBreaks, '');
    }

    final runes = _text.runes.toList();
    runes.replaceRange(_selection.lower, _selection.upper, insertion.runes);

    _text = widget.controller.text = String.fromCharCodes(runes);
    _selection = widget.controller.selection = TextSelection.collapsed(_selection.lower + insertion.runes.length);
  }

  void _deleteSelection() => _insert('');

  void _moveCursorVertically(int byLines, bool selecting) {
    final newLineIdx = (_cursorLocation.line + byLines).clamp(0, _paragraph.metrics.lineMetrics.length - 1);
    final currentX = cursorPosition.x;

    final newLine = _paragraph.metrics.lineMetrics[newLineIdx];
    var newLocalRune = 0;

    while (newLocalRune < (newLine.endRune - newLine.startRune)) {
      final currentGlyph = _paragraph.getGlyphForCharIndex(newLine.startRune + newLocalRune)!;

      if (currentGlyph.position.x >= currentX) {
        final previousGlyph = _paragraph.getGlyphForCharIndex(max(0, newLine.startRune + newLocalRune - 1))!;

        if ((currentX - previousGlyph.position.x).abs() < (currentX - currentGlyph.position.x).abs()) {
          newLocalRune--;
        }

        break;
      }

      newLocalRune++;
    }

    _moveCursor(newLine.startRune + newLocalRune, selecting);
  }

  int _runeIdxAt(double x, double y) {
    LineMetrics? clickedLine;
    for (final line in _paragraph.metrics.lineMetrics) {
      if (line.yOffset <= y && y <= line.yOffset + line.height) {
        clickedLine = line;
        break;
      }
    }

    clickedLine ??= y < 0 ? _paragraph.metrics.lineMetrics.first : _paragraph.metrics.lineMetrics.last;

    var clickedRuneIdx = x < 0 ? clickedLine.startRune : clickedLine.endRune;
    for (var runeIdx = clickedLine.startRune; runeIdx < clickedLine.endRune; runeIdx++) {
      final glyph = _paragraph.getGlyphForCharIndex(runeIdx)!;

      if (glyph.position.x <= x && x <= glyph.position.x + glyph.advance.x) {
        clickedRuneIdx = min(clickedLine.endRune, x > glyph.position.x + glyph.advance.x / 2 ? runeIdx + 1 : runeIdx);
        break;
      }
    }

    return clickedRuneIdx;
  }

  void _moveCursor(int toRune, bool selecting) {
    if (selecting) {
      _selection = widget.controller.selection = TextSelection(_selection.start, toRune);
    } else {
      _selection = widget.controller.selection = TextSelection.collapsed(toRune);
    }
  }

  int _nextWordBoundary(bool forwards, {int? fromRuneIdx}) {
    fromRuneIdx ??= _selection.end;

    var direction = forwards ? 1 : -1;
    var lookAhead = forwards ? 0 : -1;
    var bound = forwards ? _text.runes.length + 1 : -1;

    var startingClass = _SkipClass(_safeCharCodeAt(fromRuneIdx + lookAhead));
    var idx = fromRuneIdx + direction;

    while (idx != bound && startingClass.shouldSkip(_safeCharCodeAt(idx + lookAhead))) {
      idx += direction;
    }

    return idx;
  }

  int _safeCharCodeAt(int runeIdx) => _text.runes.toList()[runeIdx.clamp(0, _text.runes.length - 1)];

  @override
  bool onChar(int charCode, KeyModifiers modifiers) {
    _insert(String.fromCharCode(charCode));
    return true;
  }

  @override
  bool onKeyDown(int keyCode, KeyModifiers modifiers) {
    final cursorPosition = _selection.end;

    if (keyCode == glfwKeyBackspace) {
      if (!_selection.collapsed) {
        _deleteSelection();
      } else if (cursorPosition > 0) {
        final runes = _text.runes.toList();
        runes.removeAt(cursorPosition - 1);

        _selection = widget.controller.selection = TextSelection.collapsed(cursorPosition - 1);
        _text = widget.controller.text = String.fromCharCodes(runes);
      }

      return true;
    } else if (keyCode == glfwKeyDelete) {
      if (!_selection.collapsed) {
        _deleteSelection();
      } else if (cursorPosition < _text.runes.length) {
        final runes = _text.runes.toList();
        runes.removeAt(cursorPosition);

        _text = widget.controller.text = String.fromCharCodes(runes);
      }

      return true;
    } else if (keyCode == glfwKeyV && modifiers.ctrl) {
      // TODO: abstract clipboard handling

      // final clipboardString = glfw.getClipboardString(host!.surface.handle);
      // if (clipboardString.address != 0) {
      //   _insert(clipboardString.cast<Utf8>().toDartString());
      // }

      return true;
    } else if ((keyCode == glfwKeyC || keyCode == glfwKeyX) && modifiers.ctrl) {
      // if (!_selection.collapsed) {
      //   malloc.arena((arena) {
      //     glfw.setClipboardString(
      //       host!.surface.handle,
      //       _text.substring(_selection.lower, _selection.upper).toNativeUtf8(allocator: arena).cast(),
      //     );
      //   });

      //   if (keyCode == glfwKeyX) {
      //     _deleteSelection();
      //   }
      // }

      return true;
    } else if (keyCode == glfwKeyA && modifiers.ctrl) {
      _selection = widget.controller.selection = TextSelection(0, _text.length);
      return true;
    } else if (keyCode == glfwKeyLeft) {
      final endingSelection = !_selection.collapsed && !modifiers.shift;
      _moveCursor(
        max(
          0,
          endingSelection
              ? _selection.lower
              : modifiers.ctrl
              ? _nextWordBoundary(false)
              : cursorPosition - 1,
        ),
        modifiers.shift,
      );
      return true;
    } else if (keyCode == glfwKeyRight) {
      final endingSelection = !_selection.collapsed && !modifiers.shift;
      _moveCursor(
        min(
          _text.runes.length,
          endingSelection
              ? _selection.upper
              : modifiers.ctrl
              ? _nextWordBoundary(true)
              : cursorPosition + 1,
        ),
        modifiers.shift,
      );
      return true;
    } else if (keyCode == glfwKeyHome) {
      _moveCursor(currentLine.startRune, modifiers.shift);
      return true;
    } else if (keyCode == glfwKeyEnd) {
      _moveCursor(currentLine.endRune, modifiers.shift);
      return true;
    }

    if (widget.allowMultipleLines) {
      if (keyCode == glfwKeyEnter || keyCode == glfwKeyKpEnter) {
        _insert('\n');
        return true;
      } else if (keyCode == glfwKeyUp) {
        _moveCursorVertically(-1, modifiers.shift);
        return true;
      } else if (keyCode == glfwKeyDown) {
        _moveCursorVertically(1, modifiers.shift);
        return true;
      }
    }

    return false;
  }

  @override
  CursorStyle? cursorStyleAt(double x, double y) => CursorStyle.text;

  DateTime _lastClickTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _maxDoubleClickDelay = Duration(milliseconds: 250);

  @override
  bool onMouseDown(double x, double y, int button) {
    final clickedIdx = _runeIdxAt(x, y);

    if (DateTime.now().difference(_lastClickTime) < _maxDoubleClickDelay) {
      final start = _nextWordBoundary(false, fromRuneIdx: clickedIdx);
      final end = _nextWordBoundary(true, fromRuneIdx: clickedIdx);

      _selection = widget.controller.selection = TextSelection(max(0, start), end);
    } else {
      _lastClickTime = DateTime.now();
      _moveCursor(clickedIdx, host!.eventsBinding.isKeyPressed(glfwKeyLeftShift));
    }

    return true;
  }

  @override
  void onMouseDrag(double x, double y, double dx, double dy) {
    _moveCursor(_runeIdxAt(x, y), true);
  }
}

sealed class _SkipClass {
  const _SkipClass._();
  bool shouldSkip(int charCode);

  factory _SkipClass(int charCode) {
    const newline = 0xa; // '\n'
    if (charCode == newline) {
      return const _LineBreakClass();
    }

    if (_WordClass.isWordChar(charCode)) {
      return const _WordClass();
    }

    return _NonWordClass(charCode);
  }
}

final class _WordClass extends _SkipClass {
  const _WordClass() : super._();

  @override
  bool shouldSkip(int charCode) => isWordChar(charCode);

  static const _underscore = 0x5f; // '_'
  static bool isWordChar(int charCode) =>
      isUpperCaseLetter(charCode) ||
      isLowerCaseLetter(charCode) ||
      isTitleCaseLetter(charCode) ||
      isModifierLetter(charCode) ||
      isOtherLetter(charCode) ||
      isLetterNumber(charCode) ||
      isDecimalNumber(charCode) ||
      charCode == _underscore;
}

final class _NonWordClass extends _SkipClass {
  final int specimen;
  _NonWordClass(this.specimen) : super._();

  @override
  bool shouldSkip(int charCode) => charCode == specimen;
}

final class _LineBreakClass extends _SkipClass {
  const _LineBreakClass() : super._();

  @override
  bool shouldSkip(int charCode) => false;
}

import 'dart:async';

import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');
  final (app, _) = await createBraidAppWithWindow(
    baseLogger: Logger('text-sizes'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const TextSizesApp(),
  );

  await app.loadFontFamily('CascadiaCode', 'cascadia');

  runBraidApp(app: app, reloadHook: true);
}

class TextSizesApp extends StatelessWidget {
  const TextSizesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Panel(
        color: BraidTheme.defaultBackgroundColor,
        child: Center(
          child: Flex(
            mainAxis: LayoutAxis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Scrollable.vertical(
                  child: Flex(
                    mainAxis: LayoutAxis.horizontal,
                    children: [
                      Flex(
                        mainAxis: LayoutAxis.vertical,
                        children: [for (var size = 8.0; size < 52; size += 2) _testLabel(size)],
                      ),
                      Flex(
                        mainAxis: LayoutAxis.vertical,
                        children: [
                          for (var size = 8.0; size < 52; size += 2)
                            _testLabel(size, fontFamily: 'cascadia', underline: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _testLabel(double size, {String fontFamily = 'NotoSans', bool underline = false}) => Padding(
  insets: const Insets.all(10),
  child: /* Text(
    'bruhve ${size}px',
    style: TextStyle(fontSize: size, fontFamily: fontFamily, underline: underline),
  ), */ RawText(
    softWrap: false,
    alignment: Alignment.left,
    spans: [
      Span(
        'bruhve',
        SpanStyle(
          color: Color.white,
          fontSize: size,
          fontFamily: fontFamily,
          bold: false,
          italic: false,
          underline: underline,
        ),
      ),
      Span(
        ' ',
        SpanStyle(
          color: Color.white,
          fontSize: size,
          fontFamily: fontFamily,
          bold: false,
          italic: false,
          underline: false,
        ),
      ),
      Span(
        '$size',
        SpanStyle(
          color: const Color.rgb(0x56DFCF),
          fontSize: size,
          fontFamily: fontFamily,
          bold: false,
          italic: false,
          underline: underline,
        ),
      ),
      Span(
        'px',
        SpanStyle(
          color: Color.white,
          fontSize: size,
          fontFamily: fontFamily,
          bold: false,
          italic: false,
          underline: false,
        ),
      ),
    ],
  ),
);

// class TextField extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   String _content = "";
//   int _cursorPosition = 0;

//   final _changeEvents = StreamController<String>.broadcast(sync: true);

//   TextField() : super.lateChild() {
//     initChild(
//       KeyboardInput(
//         charCallback: (charCode, modifiers) => onCharTyped(String.fromCharCode(charCode), modifiers),
//         keyDownCallback: (keyCode, modifiers) => onKeyPress(keyCode, modifiers),
//         child: Panel(color: Color.black, cornerRadius: 5.0),
//       ),
//     );
//   }

//   @override
//   void draw(DrawContext ctx) {
//     super.draw(ctx);

//     // final focused = focusHandler?.focused == this;
//     final focused = true;

//     final renderText = Text.string(_content);
//     final renderTextSize = ctx.textRenderer.sizeOf(renderText, 15);

//     ctx.transform.scope((mat4) {
//       ctx.primitives.roundedRect(transform.width, transform.height, 5, Color.black, ctx.transform, mat4);

//       if (focused) {
//         mat4.translate(5.0 + _charIdxToClusterPos(renderText, _cursorPosition, 15), 6.0);
//         ctx.primitives.roundedRect(
//           1,
//           transform.height.toDouble() - 12,
//           1,
//           Color.white.interpolate(Color(Vector4.zero()), sin(DateTime.now().millisecondsSinceEpoch * .005)),
//           mat4,
//           ctx.projection,
//         );
//       }
//     });

//     if (_content.isEmpty) return;
//     ctx.transform.scope((mat4) {
//       mat4.translate(5.0, (transform.height - renderTextSize.height) / 2);
//       ctx.textRenderer.drawText(renderText, 15, Color.white, mat4, ctx.projection);
//     });
//   }

//   double _charIdxToClusterPos(Text text, int charIdx, double size) {
//     if (text.glyphs.isEmpty || charIdx == 0) return 0;

//     var pos = 0.0;
//     var glyphs = text.glyphs;

//     for (var glyphIdx = 0; glyphIdx < glyphs.length && glyphs[glyphIdx].cluster < charIdx; glyphIdx++) {
//       var glyph = glyphs[glyphIdx];
//       pos += (glyph.advance.x / 64) * (size / Font.toPixelSize(size));
//     }

//     return pos;
//   }

//   void _insert(String insertion) {
//     final runes = _content.runes.toList();
//     runes.insertAll(_cursorPosition, insertion.runes);

//     content = String.fromCharCodes(runes);
//     _cursorPosition += insertion.runes.length;
//   }

//   bool onCharTyped(String chr, int modifiers) {
//     _insert(chr);
//     return true;
//   }

//   bool onKeyPress(int keyCode, int modifiers) {
//     if (keyCode == glfwKeyBackspace) {
//       if (_content.isEmpty) return true;

//       final runes = _content.runes.toList();
//       runes.removeAt(_cursorPosition - 1);
//       _cursorPosition--;

//       content = String.fromCharCodes(runes);
//       return true;
//     } else if (keyCode == glfwKeyDelete) {
//       if (_content.isEmpty) return true;

//       final runes = _content.runes.toList();
//       runes.removeAt(_cursorPosition);
//       content = String.fromCharCodes(runes);

//       return true;
//     } else if (keyCode == glfwKeyV && (modifiers & glfwModControl) != 0) {
//       _insert(glfw.getClipboardString(layoutData!.ctx.window.handle).cast<Utf8>().toDartString());
//       return true;
//     } else if (keyCode == glfwKeyLeft) {
//       _cursorPosition = max(0, _cursorPosition - 1);
//       return true;
//     } else if (keyCode == glfwKeyRight) {
//       _cursorPosition = min(_content.runes.length, _cursorPosition + 1);
//       return true;
//     } else if (keyCode == glfwKeyHome) {
//       _cursorPosition = 0;
//       return true;
//     } else if (keyCode == glfwKeyEnd) {
//       _cursorPosition = _content.runes.length;
//       return true;
//     } else {
//       return false;
//     }
//   }

//   set content(String value) {
//     if (value == _content) return;

//     _content = value;
//     _changeEvents.add(value);
//   }

//   Stream<String> get changeEvents => _changeEvents.stream;
// }

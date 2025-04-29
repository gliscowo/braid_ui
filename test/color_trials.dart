import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/animation/lerp.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/checkbox.dart';
import 'package:braid_ui/src/widgets/collapsible.dart';
import 'package:braid_ui/src/widgets/drag_arena.dart';
import 'package:braid_ui/src/widgets/icon.dart';
import 'package:braid_ui/src/widgets/scroll.dart';
import 'package:braid_ui/src/widgets/slider.dart';
import 'package:braid_ui/src/widgets/split_pane.dart';
import 'package:braid_ui/src/widgets/stack.dart';
import 'package:braid_ui/src/widgets/switch.dart';
import 'package:braid_ui/src/widgets/text_field.dart';
import 'package:braid_ui/src/widgets/theme.dart';
import 'package:braid_ui/src/widgets/window.dart';
import 'package:diamond_gl/diamond_gl.dart' hide Window;
import 'package:endec/endec.dart';
import 'package:endec_json/endec_json.dart';
import 'package:image/image.dart' hide Color;
import 'package:logging/logging.dart';

AppState? app;
CursorStyle? cursor;

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');
  final icon = decodePngFile('test/color_trials_icon.png');

  app = await createBraidApp(
    name: 'colors !!',
    baseLogger: Logger('colors_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const ColorApp(),
  );

  app!.window.setIcon((await icon)!);
  cursor = CursorStyle.custom((await icon)!, 32, 32);
  await app!.loadFontFamily('CascadiaCode', 'cascadia');

  runBraidApp(app: app!, experimentalReloadHook: true);
}

class ColorApp extends StatelessWidget {
  const ColorApp();

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Constrain(
                constraints: Constraints.only(minHeight: 50),
                child: Panel(
                  color: BraidTheme.of(context).elevatedColor,
                  child: Padding(
                    insets: const Insets.all(10).copy(left: 15),
                    child: Align(
                      alignment: Alignment.left,
                      child: Text('cool & based colors test :o', style: TextStyle(bold: true)),
                    ),
                  ),
                ),
              ),
              const AppBody(),
            ],
          );
        },
      ),
    );
  }
}

class AppBody extends StatefulWidget {
  const AppBody({super.key});

  @override
  WidgetState<AppBody> createState() => _AppBodyState();
}

enum Test { checkboxes, cursors, textWrapping, textInput, collapsible }

class _AppBodyState extends WidgetState<AppBody> {
  static final _windowEndec = structEndec<(String, WindowController)>().with2Fields(
    Endec.string.fieldOf('title', (struct) => struct.$1),
    structEndec<WindowController>()
        .with4Fields(
          Endec.f32.fieldOf('x', (struct) => struct.x),
          Endec.f32.fieldOf('y', (struct) => struct.y),
          structEndec<Size>()
              .with2Fields(
                Endec.f32.fieldOf('width', (struct) => struct.width),
                Endec.f32.fieldOf('height', (struct) => struct.height),
                (f1, f2) => Size(f1, f2),
              )
              .fieldOf('size', (struct) => struct.size),
          Endec.bool.fieldOf('expanded', (struct) => struct.expanded),
          (x, y, size, expanded) => WindowController(x: x, y: y, size: size, expanded: expanded),
        )
        .flatFieldOf((struct) => struct.$2),
    (f1, f2) => (f1, f2),
  );

  final List<(String, WindowController)> windows = [];
  Test test = Test.checkboxes;

  @override
  void init() {
    super.init();
    _loadWindowState();
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Stack(
        children: [
          Panel(
            color: BraidTheme.of(context).backgroundColor,
            child: Column(
              children: [
                Flexible(
                  child: Stack(
                    children: [
                      switch (test) {
                        Test.checkboxes => const CheckBoxesTest(),
                        Test.cursors => const CursorTest(),
                        Test.textWrapping => const TextWrappingTest(),
                        Test.textInput => const TextInputTest(),
                        Test.collapsible => const CollapsibleTest(),
                      },
                      Align(
                        alignment: Alignment.left,
                        child: Panel(
                          color: BraidTheme.of(context).elevatedColor,
                          cornerRadius: const CornerRadius.right(10),
                          child: Padding(
                            insets: const Insets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (final test in Test.values)
                                  Padding(
                                    insets: const Insets.all(5),
                                    child: Sized(
                                      width: 115,
                                      child: Button(
                                        onClick: () => setState(() => this.test = test),
                                        child: Text(test.name),
                                        style: const ButtonStyle(
                                          cornerRadius: CornerRadius.all(10),
                                          padding: Insets.axis(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                const Padding(insets: Insets(top: 10), child: Text('test selection')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ),
                    ],
                  ),
                ),
                Padding(
                  insets: const Insets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Padding(insets: Insets(right: 5), child: DebugToggle()),
                          Text('Draw instance outlines'),
                        ],
                      ),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Button(
                              child: Text('Spawn window'),
                              onClick: () {
                                setState(() {
                                  windows.add((
                                    Random().nextInt(10000000).toRadixString(16),
                                    WindowController(size: const Size(400, 300)),
                                  ));
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Button(onClick: null, child: Text('Unavailable')),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: _saveWindowState, child: Text('Save')),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: _loadWindowState, child: Text('Load')),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: () => app!.scheduleShutdown(), child: Text('Quit')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DragArena(
            children: [
              for (final window in windows)
                Window(
                  key: Key(window.$1),
                  controller: window.$2,
                  title: 'window ${window.$1}',
                  onClose: () {
                    setState(() {
                      windows.remove(window);
                    });
                  },
                  content: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      children: [
                        Button(onClick: () {}, child: Text('bruh')),
                        ColorSlider(from: Color.white, to: Color.black),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveWindowState() {
    final endec = _windowEndec.listOf();
    File('window_state.json').writeAsString(const JsonEncoder.withIndent('  ').convert(toJson(endec, windows)));
  }

  void _loadWindowState() async {
    final endec = _windowEndec.listOf();
    final state = fromJson(endec, jsonDecode(await File('window_state.json').readAsString()));

    setState(() {
      windows.clear();
      windows.addAll(state);
    });
  }
}

class CheckBoxesTest extends StatelessWidget {
  const CheckBoxesTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Constrain(
                constraints: Constraints.only(maxWidth: 150),
                child: ColorSlider(from: const Color.rgb(0x5f43b2), to: const Color.rgb(0x1bd664)),
              ),
              const Padding(insets: Insets.axis(vertical: 25)),
              for (final color in const [
                Color.rgb(0x5f43b2),
                Color.rgb(0xfefdfd),
                Color.rgb(0xb1aebb),
                Color.rgb(0x3a3135),
              ])
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ToggleBox(),
                    Padding(
                      insets: const Insets.all(10).copy(left: 15),
                      child: Constrain(
                        constraints: Constraints.tight(const Size(65, 35)),
                        child: Panel(color: color, cornerRadius: const CornerRadius.all(5)),
                      ),
                    ),
                    Panel(
                      color: Color.rgb(0x161616),
                      cornerRadius: const CornerRadius.all(5),
                      child: Padding(
                        insets: const Insets.all(5),
                        child: Text(
                          '0x${color.toHexString(false)}',
                          style: TextStyle(fontSize: 14, fontFamily: 'cascadia'),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CursorTest extends StatelessWidget {
  const CursorTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Sized(width: 100, height: 100, child: MouseArea(cursorStyle: cursor, child: Panel(color: Color.white))),
    );
  }
}

class TextWrappingTest extends StatelessWidget {
  const TextWrappingTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Sized(
        width: 200,
        height: 100,
        child: Panel(
          color: Color.red,
          child: HorizontalSplitPane(
            leftChild: RawText(
              softWrap: true,
              alignment: Alignment.center,
              spans: [
                Span('THIS', DefaultTextStyle.of(context).toSpanStyle()),
                Span(' is ', DefaultTextStyle.of(context).copy(bold: true).toSpanStyle()),
                Span('a looooooo', DefaultTextStyle.of(context).toSpanStyle()),
                Span('oooooong word', DefaultTextStyle.of(context).copy(color: Color.blue).toSpanStyle()),
              ],
            ),
            rightChild: Text(
              'this is simply some\n\nnormal text that i\'d like to see',
              style: TextStyle(alignment: Alignment.bottomRight),
            ),
          ),
        ),
      ),
    );
  }
}

class TextInputTest extends StatefulWidget {
  const TextInputTest({super.key});

  @override
  WidgetState<TextInputTest> createState() => _TextInputTestState();
}

class DartController extends TextEditingController {
  @override
  List<Span> createSpans(SpanStyle baseStyle) {
    final parseResult = parseString(content: text, throwIfDiagnostics: false);
    Token? token = parseResult.unit.beginToken;

    var spans = <Span>[];
    int lastEnd = 0;
    while (token != null && token != parseResult.unit.endToken) {
      if (token.charOffset != lastEnd) {
        spans.add(Span(text.substring(lastEnd, token.charOffset), baseStyle));
      }

      var style = baseStyle;
      if (token.type.isKeyword ||
          token.type == TokenType.SEMICOLON ||
          token.type == TokenType.COMMA ||
          token.type == TokenType.PERIOD ||
          token.type == TokenType.PERIOD_PERIOD ||
          token.type == TokenType.PERIOD_PERIOD_PERIOD ||
          token.type == TokenType.COLON) {
        style = style.copy(color: const Color.rgb(0x89DDFF));
      } else if (token.type == TokenType.STRING) {
        style = style.copy(color: const Color.rgb(0xFFECA0));
      } else if (token.type == TokenType.OPEN_CURLY_BRACKET ||
          token.type == TokenType.CLOSE_CURLY_BRACKET ||
          token.type == TokenType.OPEN_PAREN ||
          token.type == TokenType.CLOSE_PAREN) {
        style = style.copy(color: const Color.rgb(0x5060bb));
      } else if (token.type == TokenType.FUNCTION) {
        style = style.copy(color: const Color.rgb(0x57B2FF));
      } else if (token.isOperator) {
        style = style.copy(color: const Color.rgb(0xABC8FF));
      } else if (token.type == TokenType.INT ||
          token.type == TokenType.DOUBLE ||
          token.type == TokenType.HEXADECIMAL ||
          token.type == TokenType.HEXADECIMAL_WITH_SEPARATORS) {
        style = style.copy(color: const Color.rgb(0xA0FFE0));
      }

      spans.add(Span(text.substring(token.charOffset, token.charEnd), style));
      lastEnd = token.charEnd;

      token = token.next;
    }

    if (text.length != lastEnd) {
      spans.add(Span(text.substring(lastEnd, text.length), baseStyle));
    }

    if (spans.isEmpty) {
      spans.add(Span('', baseStyle));
    }

    return spans;
  }
}

class _TextInputTestState extends WidgetState<TextInputTest> {
  final TextEditingController controller = TextEditingController();

  Timer? blinkTimer;
  bool showCursor = true;

  @override
  void init() {
    blinkTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      setState(() {
        showCursor = !showCursor;
      });
    });
  }

  @override
  void dispose() {
    blinkTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Sized(
        height: 450,
        width: 500,
        child: Panel(
          color: const Color.rgb(0x202531),
          cornerRadius: const CornerRadius.all(5),
          child: Padding(
            insets: const Insets.all(5),
            child: Scrollable.vertical(
              child: Constrain(
                constraints: Constraints.only(minHeight: 450),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, child) {
                    return TextInput(
                      controller: controller,
                      showCursor: showCursor,
                      softWrap: true,
                      allowMultipleLines: true,
                      style: const SpanStyle(
                        color: Color.white,
                        fontSize: 14,
                        fontFamily: 'cascadia',
                        bold: true,
                        italic: false,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CollapsibleTest extends StatelessWidget {
  const CollapsibleTest({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.top,
      child: CollapsibleThing(
        title: Text('collapsible thing'),
        content: Column(
          children: [
            CollapsibleThing(
              title: Text('a'),
              content: CollapsibleThing(
                title: Text('d'),
                content: CollapsibleThing(
                  title: Text('c'),
                  content: Sized(width: 100, height: 100, child: Panel(color: Color.white)),
                ),
              ),
            ),
            Row(children: [Icon(icon: Icons.fiber_manual_record), Text('just some text')]),
            CollapsibleThing(
              title: Text('b'),
              content: Sized(width: 100, height: 100, child: Panel(color: Color.blue)),
            ),
          ],
        ),
      ),
    );
  }
}

class CollapsibleThing extends StatefulWidget {
  final Widget title;
  final Widget content;

  const CollapsibleThing({super.key, required this.title, required this.content});

  @override
  WidgetState<CollapsibleThing> createState() => _CollapsibleTestState();
}

class _CollapsibleTestState extends WidgetState<CollapsibleThing> {
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Collapsible(
      collapsed: collapsed,
      onToggled:
          (nowCollapsed) => setState(() {
            collapsed = nowCollapsed;
          }),
      title: widget.title,
      content: widget.content,
    );
  }
}

class ColorSlider extends StatefulWidget {
  final Color from;
  final Color to;

  const ColorSlider({super.key, required this.from, required this.to});

  @override
  WidgetState<ColorSlider> createState() => _ColorSliderState();
}

class _ColorSliderState extends WidgetState<ColorSlider> {
  double _value = 0;
  late ColorLerp _lerp;

  @override
  void init() {
    _lerp = ColorLerp(widget.from, widget.to);
  }

  @override
  void didUpdateWidget(ColorSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lerp = ColorLerp(widget.from, widget.to);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Constrain(
          constraints: Constraints.tight(const Size(65, 35)),
          child: Panel(color: _lerp.compute(_value), cornerRadius: const CornerRadius.all(5)),
        ),
        Padding(insets: const Insets.axis(vertical: 5)),
        Slider(value: _value, onUpdate: (value) => setState(() => _value = value)),
      ],
    );
  }
}

class DebugToggle extends StatefulWidget {
  const DebugToggle({super.key});

  @override
  WidgetState<DebugToggle> createState() => _DebugToggleState();
}

class _DebugToggleState extends WidgetState<DebugToggle> {
  @override
  Widget build(BuildContext context) {
    return Checkbox(
      onClick: () => setState(() => app!.debugDrawInstanceBoxes = !app!.debugDrawInstanceBoxes),
      checked: app?.debugDrawInstanceBoxes ?? false,
    );
  }
}

class ToggleBox extends StatefulWidget {
  @override
  WidgetState<ToggleBox> createState() => _ToggleBoxState();
}

class _ToggleBoxState extends WidgetState<ToggleBox> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Switch(on: _checked, onClick: () => setState(() => _checked = !_checked)),
        const Padding(insets: Insets.all(5)),
        Checkbox(onClick: () => setState(() => _checked = !_checked), checked: _checked),
      ],
    );
  }
}

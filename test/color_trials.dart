import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/widgets/app_stack.dart';
import 'package:braid_ui/src/widgets/combo_box.dart';
import 'package:braid_ui/src/widgets/input_handling.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:endec/endec.dart';
import 'package:endec_json/endec_json.dart';
import 'package:image/image.dart' as image;
import 'package:logging/logging.dart';

CursorStyle? cursor;

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');
  final icon = image.decodePngFile('test/color_trials_icon.png');

  final (app, window) = await createBraidAppWithWindow(
    name: 'colors !!',
    baseLogger: Logger('colors_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const ColorApp(),
  );

  window.setIcon((await icon)!);
  cursor = CursorStyle.custom((await icon)!, 32, 32);
  await app.loadFontFamily('CascadiaCode', 'cascadia');

  runBraidApp(app: app, reloadHook: true);
}

class ColorApp extends StatelessWidget {
  const ColorApp();

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      // accentColor: Color.rgb(0xFF9C73),
      // highlightColor: Color.rgb(0xFBD288),
      // backgroundColor: Color.rgb(0xEEE6CA),
      // elevatedColor: Color.rgb(0xF5FAE1),
      // elementColor: Color.rgb(0x7A7A73),
      // disabledColor: Color.rgb(0x3B060A),
      // textStyle: const TextStyle(color: Color.rgb(0x57564F)),
      // switchStyle: const SwitchStyle(switchOffColor: Color.rgb(0xFF9C73)),
      // comboBoxStyle: const ComboBoxStyle(borderHighlightColor: Color.rgb(0xFF9C73)),
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
                      child: Text('cool & based colors test :o', style: const TextStyle(bold: true)),
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

enum Test { checkboxes, cursors, textWrapping, textInput, collapsible, grids, swapnite, dropdowns, intents }

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
                        Test.grids => const GridsTest(),
                        Test.swapnite => const SwapTest(),
                        Test.dropdowns => const DropdownTest(),
                        Test.intents => const IntentTest(),
                      },
                      Align(
                        key: Key('buttons'),
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
                      Button(onClick: () => AppState.of(context).scheduleShutdown(), child: Text('Quit')),
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
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              insets: const Insets.all(15),
              child: Sized(
                width: 35.0,
                height: 35.0,
                child: Button(
                  onClick: () async {
                    final screenshot = await AppState.of(context).debugCapture();
                    image.encodePngFile('screenshot.png', screenshot);
                  },
                  child: Icon(icon: Icons.screenshot),
                ),
              ),
            ),
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
                          style: const TextStyle(fontSize: 14, fontFamily: 'cascadia'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        separator: const Padding(insets: Insets.all(10)),
        children: [
          const Padding(insets: Insets.all(10), child: ProgressIndicator.indeterminate()),
          const ProgressIndicatorTest(),
          Sized(
            width: 100,
            height: 100,
            child: MouseArea(
              cursorStyle: cursor,
              child: Panel(color: Color.white),
            ),
          ),
          const Stack(
            children: [
              Panel(color: Color.green),
              StackBase(child: Text(key: Key('a'), 'some text')),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressIndicatorTest extends StatefulWidget {
  const ProgressIndicatorTest({super.key});

  @override
  WidgetState<ProgressIndicatorTest> createState() => _ProgressIndicatorTestState();
}

class _ProgressIndicatorTestState extends WidgetState<ProgressIndicatorTest> {
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      separator: const Padding(insets: Insets.all(10)),
      children: [
        Sized(
          height: 100,
          child: Slider(
            value: progress,
            onUpdate: (value) => setState(() => progress = value),
            axis: LayoutAxis.vertical,
          ),
        ),
        ProgressIndicator(progress: progress),
      ],
    );
  }
}

class TextWrappingTest extends StatelessWidget {
  const TextWrappingTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Sized(
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
                  style: const TextStyle(alignment: Alignment.bottomRight),
                ),
              ),
            ),
          ),
          const Padding(insets: Insets.all(10)),
          Panel(
            color: Color.black.copyWith(a: .25),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              children: [
                Panel(
                  color: Color.black,
                  child: Column(
                    children: [
                      Sized(width: 25, height: 25, child: Panel(color: Color.blue)),
                      Text('some text', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Panel(
                  color: Color.black,
                  child: Text(' and some\nwrapped text', style: TextStyle(fontSize: 14)),
                ),
                Panel(
                  color: Color.black,
                  child: Text(' and more\ntext', style: TextStyle(bold: true, fontSize: 32)),
                ),
                Panel(color: Color.black, child: Text('and an icon')),
                Panel(
                  color: Color.black,
                  child: Icon(icon: Icons.ac_unit),
                ),
              ],
            ),
          ),
        ],
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
    _restartBlinkTimer();
    controller.addListener(_restartBlinkTimer);
  }

  @override
  void dispose() => blinkTimer?.cancel();

  void _restartBlinkTimer() {
    blinkTimer?.cancel();
    showCursor = true;

    blinkTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      setState(() {
        showCursor = !showCursor;
      });
    });
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
            child: EditableText(
              controller: controller,
              softWrap: false,
              allowMultipleLines: true,
              style: const SpanStyle(
                color: Color.white,
                fontSize: 14,
                fontFamily: 'cascadia',
                bold: true,
                italic: false,
                underline: false,
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
    return Align(
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
            Row(
              children: [
                Icon(icon: Icons.fiber_manual_record),
                Text('just some text'),
              ],
            ),
            CollapsibleThing(
              title: Text('b'),
              content: Sized(
                width: 100,
                height: 100,
                child: Actions(
                  actions: {
                    [ActionTrigger.click]: () => print('primary hi'),
                    [ActionTrigger.secondaryClick]: () => print('hi'),
                    [ActionTrigger.secondaryClick, ActionTrigger.secondaryClick]: () => print('double hi'),
                    [ActionTrigger.secondaryClick, ActionTrigger.secondaryClick, ActionTrigger.secondaryClick]: () =>
                        print('triple hi'),
                    [ActionTrigger.secondaryClick, ActionTrigger.secondaryClick, ActionTrigger.click]: () =>
                        print('triple hi 2'),
                    [ActionTrigger.click, ActionTrigger.click, ActionTrigger.secondaryClick]: () =>
                        print('triple hi 3'),
                    [
                      ActionTrigger(keyCodes: {glfwKey1}),
                    ]: () =>
                        print('1'),
                    [
                      ActionTrigger(keyCodes: {glfwKey2}),
                    ]: () =>
                        print('2'),
                    [
                      ActionTrigger(keyCodes: {glfwKey1}),
                      ActionTrigger.click,
                      ActionTrigger(keyCodes: {glfwKey2}),
                    ]: () =>
                        print('1 click 2'),
                    [
                      ActionTrigger(keyCodes: {glfwKeyB}),
                    ]: () =>
                        print('b'),
                    [
                      ActionTrigger(keyCodes: {glfwKeyR}),
                    ]: () =>
                        print('r'),
                    [
                      ActionTrigger(keyCodes: {glfwKeyB}),
                      ActionTrigger(keyCodes: {glfwKeyR}),
                      ActionTrigger(keyCodes: {glfwKeyU}),
                      ActionTrigger(keyCodes: {glfwKeyH}),
                    ]: () =>
                        print('bruh'),
                    [
                      ActionTrigger.secondaryClick,
                      ActionTrigger.secondaryClick,
                      ActionTrigger(keyCodes: {glfwKey1}),
                      ActionTrigger.click,
                      ActionTrigger(keyCodes: {glfwKey2}),
                    ]: () =>
                        print('yeah uhh'),
                  },
                  child: Panel(color: Color.blue),
                ),
              ),
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
      onToggled: (nowCollapsed) => setState(() {
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
    final app = AppState.of(context);

    return Checkbox(
      onClick: () => setState(() => app.debugDrawInstanceBoxes = !app.debugDrawInstanceBoxes),
      checked: app.debugDrawInstanceBoxes,
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

class GridsTest extends StatelessWidget {
  const GridsTest({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Grid(
        mainAxis: LayoutAxis.vertical,
        crossAxisCells: 2,
        children: [
          Sized(width: 100, height: 100, child: Panel(color: Color.white)),
          Sized(width: 50, height: 50, child: Panel(color: Color.white)),
          Sized(width: 50, height: 50, child: Panel(color: Color.white)),
          Sized(width: 100, height: 100, child: Panel(color: Color.white)),
          Sized(width: 100, height: 100, child: Panel(color: Color.white)),
          Sized(width: 50, height: 50, child: Panel(color: Color.white)),
        ],
      ),
    );
  }
}

class SwapTest extends StatefulWidget {
  const SwapTest({super.key});

  @override
  WidgetState<SwapTest> createState() => _SwapTestState();
}

class _SwapTestState extends WidgetState<SwapTest> {
  bool enabled = false;
  int depth = 5;

  @override
  Widget build(BuildContext context) {
    Widget child = Text("it's all labels?");

    for (var i = 0; i < depth; i++) {
      child = Padding(insets: const Insets(top: 10), child: child);
    }

    return Align(
      alignment: Alignment.top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Button(
            onClick: () => setState(() {
              enabled = !enabled;
            }),
            child: Icon(icon: Icons.swap_horizontal_circle),
          ),
          Sized(
            width: 300,
            child: Slider(
              value: depth.toDouble(),
              step: 1,
              min: 2,
              max: 30,
              onUpdate: (value) => setState(() {
                depth = value.toInt();
              }),
            ),
          ),
          enabled ? Padding(insets: const Insets(), child: child) : Sized(child: child),
        ],
      ),
    );
  }
}

class DropdownTest extends StatefulWidget {
  const DropdownTest({super.key});

  @override
  WidgetState<DropdownTest> createState() => _DropdownTestState();
}

class _DropdownTestState extends WidgetState<DropdownTest> {
  Test? selected;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          separator: const Padding(insets: Insets.axis(vertical: 10)),
          children: [
            Text(selected != null ? 'selection: $selected' : 'no selection'),
            Sized(
              width: 150,
              child: ComboBox<Test>(
                options: Test.values,
                selectedOption: selected,
                optionToString: (option) =>
                    option.name.replaceAllMapped(capitals, (match) => '${match[1]} ${match[2]!.toLowerCase()}'),
                onSelect: (option) => setState(() {
                  selected = option;
                }),
              ),
            ),
            Sized(
              width: 150,
              child: ComboBox<Test>(
                options: Test.values,
                selectedOption: selected,
                optionToString: (option) =>
                    option.name.replaceAllMapped(capitals, (match) => '${match[1]} ${match[2]!.toLowerCase()}'),
                onSelect: (option) => setState(() {
                  selected = option;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---

  static final capitals = RegExp('([a-z])([A-Z])');
}

// ---

class ClickIntent extends Intent {
  final String message;
  const ClickIntent(this.message);
}

class AnotherIntent extends Intent {
  const AnotherIntent();
}

class IntentTest extends StatefulWidget {
  const IntentTest({super.key});

  @override
  WidgetState<IntentTest> createState() => _IntentTestState();
}

class _IntentTestState extends WidgetState<IntentTest> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Center(
          child: Shortcuts(
            shortcuts: const {
              [ActionTrigger.click]: ClickIntent('click'),
              [
                ActionTrigger(keyCodes: {glfwKeyA}),
              ]: ClickIntent(
                'a',
              ),
            },
            child: Intents(
              actions: ActionsMap([CallbackAction<ClickIntent>((intent) => print(intent.message))]),
              child: Sized(
                width: 200,
                height: 100,
                child: Panel(
                  color: Color.white,
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      separator: const Padding(insets: Insets.axis(horizontal: 10)),
                      children: [
                        Button(
                          onClick: () => Intents.invoke(context, const ClickIntent('button')),
                          child: Text('clicc'),
                        ),
                        const InnerIntentsTest(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class InnerIntentsTest extends StatefulWidget {
  const InnerIntentsTest({super.key});

  @override
  WidgetState<InnerIntentsTest> createState() => _InnerIntentsTestState();
}

class _InnerIntentsTestState extends WidgetState<InnerIntentsTest> {
  bool show = true;

  @override
  Widget build(BuildContext context) {
    return Sized(
      height: double.infinity,
      child: Column(
        children: [
          Switch(
            on: show,
            onClick: () => setState(() {
              show = !show;
            }),
          ),
          if (show)
            Intents(
              actions: ActionsMap([CallbackAction<ClickIntent>((intent) => print('inner: ${intent.message}'))]),
              child: Panel(color: Color.red, child: Text('b')),
            ),
        ],
      ),
    );
  }
}

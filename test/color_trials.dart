import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/animation/lerp.dart';
import 'package:braid_ui/src/baked_assets.g.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/drag_arena.dart';
import 'package:braid_ui/src/widgets/icon.dart';
import 'package:braid_ui/src/widgets/slider.dart';
import 'package:braid_ui/src/widgets/split_pane.dart';
import 'package:braid_ui/src/widgets/stack.dart';
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
    return DefaultTextStyle(
      style: TextStyle(color: Color.white, fontSize: 16.0, bold: false, italic: false),
      child: DefaultButtonStyle(
        style: const ButtonStyle(
          color: Color.rgb(0x5f43b2),
          hoveredColor: Color.rgb(0x684fb3),
          disabledColor: Color.rgb(0x3a3135),
          padding: Insets.axis(horizontal: 6, vertical: 3),
          cornerRadius: CornerRadius.all(5),
          textStyle: TextStyle(fontSize: 14.0, bold: true),
        ),
        child: Column(
          children: [
            Constrain(
              constraints: Constraints.only(minHeight: 50),
              child: Panel(
                color: Color.rgb(0x161616),
                child: Padding(
                  insets: const Insets.all(10).copy(left: 15),
                  child: Align(
                    alignment: Alignment.left,
                    child: Text(text: 'cool & based colors test :o', style: TextStyle(bold: true)),
                  ),
                ),
              ),
            ),
            const AppBody(),
          ],
        ),
      ),
    );
  }
}

class AppBody extends StatefulWidget {
  const AppBody({super.key});

  @override
  WidgetState<AppBody> createState() => _AppBodyState();
}

enum Test { checkboxes, cursors, textWrapping }

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
            color: Color.rgb(0x0f0f0f),
            child: Column(
              children: [
                Flexible(
                  child: Stack(
                    children: [
                      Center(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: switch (test) {
                            Test.checkboxes => const [CheckBoxesTest()],
                            Test.cursors => const [CursorTest()],
                            Test.textWrapping => const [TextWrappingTest()],
                          },
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.left,
                          child: Panel(
                            color: const Color.rgb(0x161616),
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
                                        width: 150,
                                        child: Button(
                                          onClick: () => setState(() => this.test = test),
                                          text: test.name,
                                          style: const ButtonStyle(
                                            cornerRadius: CornerRadius.all(10),
                                            padding: Insets.axis(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const Padding(insets: Insets(top: 10), child: Text(text: 'test selection')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                          Text(text: 'Draw instance outlines'),
                        ],
                      ),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Button(
                              text: 'Spawn window',
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
                      Button(onClick: () {}, text: 'Unavailable', enabled: false),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: _saveWindowState, text: 'Save'),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: _loadWindowState, text: 'Load'),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button(onClick: () => app!.scheduleShutdown(), text: 'Quit'),
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
                      children: [Button(onClick: () {}, text: 'bruh'), ColorSlider(from: Color.white, to: Color.black)],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Constrain(
          constraints: Constraints.only(maxWidth: 150),
          child: ColorSlider(from: const Color.rgb(0x5f43b2), to: const Color.rgb(0x1bd664)),
        ),
        const Padding(insets: Insets.axis(vertical: 25)),
        for (final color in const [Color.rgb(0x5f43b2), Color.rgb(0xfefdfd), Color.rgb(0xb1aebb), Color.rgb(0x3a3135)])
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
                    text: '0x${color.toHexString(false)}',
                    style: TextStyle(fontSize: 14, fontFamily: 'cascadia'),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class CursorTest extends StatelessWidget {
  const CursorTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Sized(width: 100, height: 100, child: MouseArea(cursorStyle: cursor, child: Panel(color: Color.white)));
  }
}

class TextWrappingTest extends StatelessWidget {
  const TextWrappingTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Sized(
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
            text: 'this is simply some normal text that i\'d like to see',
            style: TextStyle(alignment: Alignment.bottomRight),
          ),
        ),
      ),
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
      clickCallback: () => setState(() => app!.debugDrawInstanceBoxes = !app!.debugDrawInstanceBoxes),
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
    return Checkbox(clickCallback: () => setState(() => _checked = !_checked), checked: _checked);
  }
}

class Checkbox extends StatefulWidget {
  final bool checked;
  final void Function()? clickCallback;

  const Checkbox({super.key, this.clickCallback, required this.checked});

  @override
  WidgetState<StatefulWidget> createState() => _CheckboxState();
}

class _CheckboxState extends WidgetState<Checkbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      clickCallback: (_, _) => widget.clickCallback?.call(),
      enterCallback: () => setState(() => _hovered = true),
      exitCallback: () => setState(() => _hovered = false),
      cursorStyle: CursorStyle.hand,
      child: Constrain(
        constraints: const Constraints.only(minWidth: 20, minHeight: 20),
        child: Panel(
          color:
              widget.checked
                  ? _hovered
                      ? const Color.rgb(0x684fb3)
                      : const Color.rgb(0x5f43b2)
                  : _hovered
                  ? Color.white
                  : const Color.rgb(0xb1aebb),
          cornerRadius: const CornerRadius.all(5),
          outlineThickness: !widget.checked ? .5 : null,
          child: widget.checked ? const Icon(icon: Icons.close, size: 16) : null,
        ),
      ),
    );
  }
}

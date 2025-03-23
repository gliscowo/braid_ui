import 'dart:math';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/animation/lerp.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/drag_arena.dart';
import 'package:braid_ui/src/widgets/slider.dart';
import 'package:braid_ui/src/widgets/stack.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:image/image.dart' hide Color;
import 'package:logging/logging.dart';

AppState? app;

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
  await app!.loadFontFamily('CascadiaCode', 'cascadia');

  runBraidApp(app: app!, experimentalReloadHook: true);
}

class ColorApp extends StatelessWidget {
  const ColorApp();

  @override
  Widget build(BuildContext context) {
    return DefaultButtonStyle(
      style: const ButtonStyle(
        color: Color.rgb(0x5f43b2),
        hoveredColor: Color.rgb(0x684fb3),
        disabledColor: Color.rgb(0x3a3135),
        padding: Insets.axis(horizontal: 6, vertical: 3),
        cornerRadius: CornerRadius.all(5),
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
                  child: Label(text: 'cool & based colors test :o', style: LabelStyle(bold: true)),
                ),
              ),
            ),
          ),
          const AppBody(),
        ],
      ),
    );
  }
}

class AppBody extends StatefulWidget {
  const AppBody({super.key});

  @override
  WidgetState<AppBody> createState() => _AppBodyState();
}

class _AppBodyState extends WidgetState<AppBody> {
  final List<String> windows = [];

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
                  child: Center(
                    child: Column(
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
                                  child: Label(
                                    text: '0x${color.toHexString(false)}',
                                    style: LabelStyle(fontSize: 14, fontFamily: 'cascadia'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  insets: const Insets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Padding(insets: Insets(right: 5), child: DebugToggle()),
                          Label(text: 'Draw instance outlines'),
                        ],
                      ),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Button.text(
                              onClick: () {
                                setState(() {
                                  windows.add(Random().nextInt(10000000).toRadixString(16));
                                });
                              },
                              text: 'Spawn window',
                            ),
                          ],
                        ),
                      ),
                      Button.text(onClick: () {}, text: 'Unavailable', enabled: false),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button.text(onClick: () {}, text: 'Save'),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button.text(onClick: () => app!.scheduleShutdown(), text: 'Quit'),
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
                  key: Key(window),
                  initialSize: const Size(400, 300),
                  title: 'window $window',
                  content: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      children: [
                        Button.text(onClick: () {}, text: 'bruh'),
                        ColorSlider(from: Color.white, to: Color.black),
                        Button.text(
                          onClick: () {
                            setState(() {
                              windows.remove(window);
                            });
                          },
                          text: 'close',
                        ),
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
          child: widget.checked ? Label.text(text: Text([Icon('close')])) : null,
        ),
      ),
    );
  }
}

class Window extends StatefulWidget {
  final Size initialSize;
  final ({double x, double y}) initialPosition;
  final bool collapsible;
  final String title;
  final Widget content;

  const Window({
    super.key,
    required this.initialSize,
    this.initialPosition = (x: 0, y: 0),
    this.collapsible = true,
    required this.title,
    required this.content,
  });

  @override
  WidgetState<Window> createState() => _WindowState();
}

class _WindowState extends WidgetState<Window> {
  late double x;
  late double y;
  late Size size;

  bool expanded = true;
  Set<_WindowEdge>? draggingEdges;

  @override
  void init() {
    super.init();
    x = widget.initialPosition.x;
    y = widget.initialPosition.y;
    size = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    return DragArenaElement(
      x: x,
      y: y,
      child: MouseArea(
        cursorStyleSupplier:
            (x, y) => switch (_edgesAt(x, y).toList()) {
              [_WindowEdge.top] || [_WindowEdge.bottom] => CursorStyle.verticalResize,
              [_WindowEdge.left] || [_WindowEdge.right] => CursorStyle.horizontalResize,
              [_WindowEdge.top, _WindowEdge.left] || [_WindowEdge.bottom, _WindowEdge.right] => CursorStyle.nwseResize,
              [_WindowEdge.bottom, _WindowEdge.left] || [_WindowEdge.top, _WindowEdge.right] => CursorStyle.neswResize,
              _ => null,
            },
        clickCallback: (x, y) => draggingEdges = _edgesAt(x, y),
        dragCallback: (x, y, dx, dy) => setState(() => _resize(dx, dy)),
        dragEndCallback: () => draggingEdges = null,
        child: Padding(
          insets: const Insets.all(10),
          child: HitTestOccluder(
            child: MouseArea(
              dragCallback:
                  (_, _, dx, dy) => setState(() {
                    x += dx;
                    y += dy;
                  }),
              child: Column(
                children: [
                  Sized(
                    width: size.width,
                    height: 25,
                    child: Panel(
                      color: const Color.rgb(0x5f43b2),
                      cornerRadius: expanded ? const CornerRadius.top(10.0) : const CornerRadius.all(10.0),
                      child: Padding(
                        insets: const Insets.axis(horizontal: 5),
                        child: Row(
                          children: [
                            Label(text: widget.title, style: LabelStyle(fontSize: 14.0, bold: true)),
                            Flexible(child: Padding(insets: Insets.zero)),
                            if (widget.collapsible)
                              MouseArea(
                                cursorStyle: CursorStyle.hand,
                                clickCallback:
                                    (_, _) => setState(() {
                                      expanded = !expanded;
                                    }),
                                child: Label.text(text: Text([Icon(expanded ? 'arrow_drop_up' : 'arrow_drop_down')])),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: expanded,
                    child: Panel(
                      color: const Color(0xbb161616),
                      cornerRadius: const CornerRadius.bottom(10.0),
                      child: Sized(
                        width: size.width,
                        height: size.height,
                        child: Clip(child: Padding(insets: const Insets.all(10), child: widget.content)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Set<_WindowEdge> _edgesAt(double x, double y) {
    final result = <_WindowEdge>{};

    if (y < 10) result.add(_WindowEdge.top);
    if (y > size.height + 10) result.add(_WindowEdge.bottom);

    if (x < 10) result.add(_WindowEdge.left);
    if (x > size.width + 10) result.add(_WindowEdge.right);

    return result;
  }

  void _resize(double dx, double dy) {
    if (draggingEdges!.contains(_WindowEdge.top)) {
      size = size.copy(height: size.height - dy);
      y += dy;
    } else if (draggingEdges!.contains(_WindowEdge.bottom)) {
      size = size.copy(height: size.height + dy);
    }

    if (draggingEdges!.contains(_WindowEdge.left)) {
      size = size.copy(width: size.width - dx);
      x += dx;
    } else if (draggingEdges!.contains(_WindowEdge.right)) {
      size = size.copy(width: size.width + dx);
    }
  }
}

enum _WindowEdge { top, left, right, bottom }

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/animation/lerp.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/slider.dart';
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
        cornerRadius: 5,
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
          Flexible(
            child: Panel(
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
                                    child: Panel(color: color, cornerRadius: 5),
                                  ),
                                ),
                                Panel(
                                  color: Color.rgb(0x161616),
                                  cornerRadius: 5,
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
                        Flexible(child: Panel(color: Color.black)),
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
          child: Panel(color: _lerp.compute(_value), cornerRadius: 5),
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
          cornerRadius: 5,
          outlineThickness: !widget.checked ? .5 : null,
          child: widget.checked ? Label.text(text: Text([Icon('close')])) : null,
        ),
      ),
    );
  }
}

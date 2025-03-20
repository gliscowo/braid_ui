import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';

AppState? app;

Future<void> main() async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  app = await createBraidApp(
    name: 'colors !!',
    baseLogger: Logger('colors_app'),
    resources: BraidResources.filesystem(
      fontDirectory: 'resources/font',
      shaderDirectory: 'resources/shader',
    ),
    widget: const ColorApp(),
  );

  await app!.loadFontFamily('CascadiaCode', 'cascadia');

  runBraidApp(
    app: app!,
    experimentalReloadHook: true,
  );
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
          Constrained(
            constraints: Constraints.only(minHeight: 50),
            child: Panel(
              color: Color.rgb(0x161616),
              child: Padding(
                insets: const Insets.all(10).copy(left: 15),
                child: Align(
                  alignment: Alignment.left,
                  child: Label(
                    text: 'cool & based colors test :o',
                    style: LabelStyle(bold: true),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: Panel(
              color: Color.rgb(0x0f0f0f),
              child: Column(children: [
                Flexible(
                  child: Center(
                    child: Column(
                      children: [
                        for (final color in const [
                          Color.rgb(0x5f43b2),
                          Color.rgb(0xfefdfd),
                          Color.rgb(0xb1aebb),
                          Color.rgb(0x3a3135)
                        ])
                          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            ToggleBox(),
                            Padding(
                              insets: const Insets.all(10).copy(left: 15),
                              child: Constrained(
                                constraints: Constraints.tight(const Size(65, 35)),
                                child: Panel(
                                  color: color,
                                  cornerRadius: 5,
                                ),
                              ),
                            ),
                            Panel(
                              color: Color.rgb(0x161616),
                              cornerRadius: 5,
                              child: Padding(
                                insets: const Insets.all(5),
                                child: Label(
                                  text: '0x${color.toHexString(false)}',
                                  style: LabelStyle(
                                    fontSize: 14,
                                    fontFamily: 'cascadia',
                                  ),
                                ),
                              ),
                            )
                          ])
                      ],
                    ),
                  ),
                ),
                Padding(
                  insets: const Insets.all(15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(children: [
                        const Padding(insets: Insets(right: 5), child: DebugToggle()),
                        Label(text: 'Draw instance outlines'),
                      ]),
                      Flexible(child: Panel(color: Color.black)),
                      Button.text(onClick: () {}, text: 'Unavailable', enabled: false),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button.text(onClick: () {}, text: 'Save'),
                      Padding(insets: const Insets.axis(horizontal: 5)),
                      Button.text(onClick: () => app!.scheduleShutdown(), text: 'Quit'),
                    ],
                  ),
                )
              ]),
            ),
          )
        ],
      ),
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
    return Checkbox(
      clickCallback: () => setState(() => _checked = !_checked),
      checked: _checked,
    );
  }
}

class Checkbox extends StatefulWidget {
  final bool checked;
  final void Function()? clickCallback;

  const Checkbox({
    super.key,
    this.clickCallback,
    required this.checked,
  });

  @override
  WidgetState<StatefulWidget> createState() => _CheckboxState();
}

class _CheckboxState extends WidgetState<Checkbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      clickCallback: widget.clickCallback,
      enterCallback: () => setState(() => _hovered = true),
      exitCallback: () => setState(() => _hovered = false),
      cursorStyle: CursorStyle.hand,
      child: Constrained(
        constraints: const Constraints.only(minWidth: 20, minHeight: 20),
        child: Panel(
          color: widget.checked
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

import 'dart:async';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/animated_widgets.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/layout_builder.dart';
import 'package:braid_ui/src/widgets/theme.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'fancy clock moment',
    baseLogger: Logger('yep'),
    windowWidth: 600,
    windowHeight: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const ClockApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class ColorProvider extends InheritedWidget {
  final Color color;

  const ColorProvider({super.key, required this.color, required super.child});

  @override
  bool mustRebuildDependents(ColorProvider newWidget) => color != newWidget.color;
}

// ---

class ClockApp extends StatelessWidget {
  const ClockApp();

  @override
  Widget build(BuildContext context) {
    Widget widget = BraidTheme(
      child: Column(
        children: [
          Flexible(
            key: Key('a'),
            child: Panel(
              color: Color.white,
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [TimeText(), Button(onClick: () => print('yup'), child: Text('a'))],
                ),
              ),
            ),
          ),
          Flexible(
            key: Key('b'),
            child: LayoutBuilder(
              builder:
                  (context, constraints) => Panel(
                    color: constraints.maxWidth > 600 ? Color.green : Color.blue,
                    child: const AnimatedPadding(
                      easing: Easing.inOutExpo,
                      duration: Duration(milliseconds: 1000),
                      insets: Insets(top: 10, bottom: 10, left: 10, right: 10),
                      child: AnimatedPanel(
                        easing: Easing.outExpo,
                        duration: Duration(seconds: 1),
                        cornerRadius: CornerRadius.all(15),
                        color: Color.white,
                      ),
                    ),
                  ),
            ),
            flexFactor: .5,
          ),
          Constrain(constraints: Constraints.tightOnAxis(vertical: 75), child: Panel(color: Color.black)),
          AnimatedAlign(
            duration: Duration(milliseconds: 1000),
            easing: Easing.inOutCubic,
            alignment: Alignment.right,
            child: AnimatedSized(
              duration: Duration(milliseconds: 500),
              easing: Easing.inOutExpo,
              height: 50,
              width: 200,
              child: DependencyTest(),
            ),
          ),
        ],
      ),
    );

    const orange = false;
    if (orange) {
      widget = DefaultButtonStyle(
        style: const ButtonStyle(color: Color.rgb(0xEB5B00), highlightColor: Color.rgb(0xEB5B00)),
        child: widget,
      );
    }

    return widget;
  }
}

class DependencyTest extends StatefulWidget {
  @override
  WidgetState<StatefulWidget> createState() => DependencyTestState();
}

class DependencyTestState extends WidgetState<DependencyTest> {
  Color color = Color.red;

  @override
  Widget build(BuildContext context) {
    return ColorProvider(
      color: color,
      child: Row(
        children: [
          Button(
            onClick:
                () => setState(() {
                  color = color == Color.red ? Color.green : Color.red;
                }),
            child: Text('toggle'),
          ),
          Constrain(constraints: Constraints.only(minWidth: 10), child: Panel(color: color)),
          const Flexible(child: Builder(builder: _innerBuild)),
        ],
      ),
    );
  }

  static Widget _innerBuild(BuildContext context) {
    return Panel(color: context.dependOnAncestor<ColorProvider>()!.color);
  }
}

class TimeText extends StatefulWidget {
  const TimeText();

  @override
  WidgetState createState() => TimeTextState();
}

class TimeTextState extends WidgetState<TimeText> {
  DateTime _time = DateTime.now();
  late Timer _timer;

  @override
  void init() {
    super.init();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) => setState(() => _time = DateTime.now()));
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${DateFormat('Hms').format(_time)}:${_time.millisecond}',
      style: TextStyle(fontSize: 80.0, bold: true, color: Color.ofHsv(_time.second / 60.0, 1.0, 1.0)),
    );
  }
}

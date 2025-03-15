import 'dart:async';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
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
    resources: BraidResources.filesystem(
      fontDirectory: 'resources/font',
      shaderDirectory: 'resources/shader',
    ),
    widget: const ClockApp(),
  );

  runBraidApp(
    app: app,
    experimentalReloadHook: true,
  );
}

// ---

class ClockApp extends StatelessWidget {
  const ClockApp();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Flexible(
        key: Key('a'),
        child: Panel(
          color: Color.white,
          cornerRadius: 0.0,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TimeText(),
                Button.text(onClick: () => print('yup'), text: 'a'),
              ],
            ),
          ),
        ),
      ),
      Flexible(
        key: Key('b'),
        child: Panel(
          color: Color.blue,
          cornerRadius: 0.0,
        ),
        flexFactor: .5,
      ),
      Constrained(
        constraints: Constraints.tightOnAxis(vertical: 75),
        child: Panel(
          color: Color.black,
          cornerRadius: 0.0,
        ),
      ),
    ]);
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
    _timer = Timer.periodic(
      Duration(seconds: 1),
      (timer) => setState(() => _time = DateTime.now()),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Label(
      text: '${DateFormat('Hms').format(_time)}:${_time.millisecond}',
      style: LabelStyle(fontSize: 80.0, bold: true, textColor: Color.ofHsv(_time.second / 60.0, 1.0, 1.0)),
    );
  }
}

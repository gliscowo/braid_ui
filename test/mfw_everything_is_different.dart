import 'dart:async';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/theme.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

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
    return MouseArea(
      cursorStyle: CursorStyle.hand,
      // clickCallback: () => setState(() => _time = DateTime.now()),
      child: Text(DateFormat('Hms').format(_time), style: TextStyle(fontSize: 40.0, bold: true)),
    );
  }
}

class Clock extends StatelessWidget {
  const Clock();

  @override
  Widget build(BuildContext context) {
    return Panel(color: Color.blue, child: const Padding(insets: Insets.all(10), child: TimeText()));
  }
}

class App extends StatelessWidget {
  const App();

  @override
  Widget build(BuildContext context) {
    return BraidTheme(child: Panel(color: Color.white, child: const Center(child: Clock())));
  }
}

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    baseLogger: Logger('yep'),
    windowWidth: 300,
    windowHeight: 200,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const App(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

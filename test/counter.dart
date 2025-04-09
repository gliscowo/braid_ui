import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'counter',
    baseLogger: Logger('counter_app'),
    windowWidth: 500,
    windowHeight: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const CounterApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class CounterApp extends StatelessWidget {
  const CounterApp();

  @override
  Widget build(BuildContext context) {
    return const DefaultTextStyle(
      style: TextStyle(color: Color.black, fontSize: 32, bold: false, italic: false),
      child: Panel(color: Color.white, child: Center(child: Counter())),
    );
  }
}

class Counter extends StatefulWidget {
  const Counter();

  @override
  WidgetState<StatefulWidget> createState() => _CounterState();
}

class _CounterState extends WidgetState<Counter> {
  int clicks = 0;

  @override
  Widget build(Object context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(text: 'clicks: $clicks'),
        Button(onClick: () => setState(() => clicks++), text: 'count!'),
        Button(onClick: () => setState(() => clicks = 0), text: 'reset'),
      ],
    );
  }
}

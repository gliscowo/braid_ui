import 'package:braid_ui/braid_ui.dart';
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

  runBraidApp(app: app, reloadHook: true);
}

class CounterApp extends StatelessWidget {
  const CounterApp();

  @override
  Widget build(BuildContext context) {
    return const BraidTheme(
      textStyle: TextStyle(fontSize: 32),
      child: Panel(color: BraidTheme.defaultBackgroundColor, child: Center(child: Counter())),
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
        Text('clicks: $clicks'),
        Button(onClick: () => setState(() => clicks++), child: Text('count!')),
        Button(onClick: () => setState(() => clicks = 0), child: Text('reset')),
      ],
    );
  }
}

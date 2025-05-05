import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'inherited state',
    baseLogger: Logger('counter_app'),
    windowWidth: 500,
    windowHeight: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const InheritedStateApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class CounterState extends ShareableState {
  int count = 0;
}

class InheritedStateApp extends StatelessWidget {
  const InheritedStateApp();

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      textStyle: TextStyle(fontSize: 24.0),
      child: Column(children: [Flexible(child: TheApp()), Flexible(child: TheApp(nest: true))]),
    );
  }
}

class TheApp extends StatelessWidget {
  final bool nest;
  const TheApp({super.key, this.nest = false});

  @override
  Widget build(BuildContext context) {
    return SharedState(
      initState: CounterState.new,
      child: Row(
        children: [
          Flexible(child: LeftBody()),
          Flexible(child: Center(child: RightBody())),
          if (nest) Flexible(child: TheApp(), flexFactor: 2),
        ],
      ),
    );
  }
}

class LeftBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(color: Color.green, child: Text('current state: ${SharedState.get<CounterState>(context).count}'));
  }
}

class RightBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('button build');
    return Button(
      onClick: () => SharedState.set<CounterState>(context, (state) => state.count += 1),
      child: Text('increment'),
    );
  }
}

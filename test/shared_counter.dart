import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final (app, _) = await createBraidAppWithWindow(
    name: 'inherited state',
    baseLogger: Logger('counter_app'),
    width: 500,
    height: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const InheritedStateApp(),
  );

  runBraidApp(app: app, reloadHook: true);
}

class CounterState extends ShareableState {
  int count = 0;
  bool black = false;
}

class InheritedStateApp extends StatelessWidget {
  const InheritedStateApp();

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      textStyle: TextStyle(fontSize: 24.0),
      child: Column(
        children: [
          Flexible(child: TheApp()),
          Flexible(child: TheApp(nest: true)),
        ],
      ),
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
          if (nest) Flexible(flexFactor: 2, child: TheApp()),
        ],
      ),
    );
  }
}

class LeftBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('panel rebuild');
    return Panel(
      color: SharedState.select<CounterState, bool>(context, (state) => state.black) ? Color.black : Color.green,
      child: const CounterText(),
    );
  }
}

class CounterText extends StatelessWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context) {
    print('text rebuild');
    return Text('current state: ${SharedState.select<CounterState, int>(context, (state) => state.count)}');
  }
}

class RightBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('buttons build');
    return IntrinsicWidth(
      child: Column(
        children: [
          Button(
            onClick: () => SharedState.set<CounterState>(context, (state) => state.count += 1),
            child: Text('increment'),
          ),
          Button(
            onClick: () => SharedState.set<CounterState>(context, (state) => state.black = !state.black),
            child: Text('toggle color'),
          ),
        ],
      ),
    );
  }
}

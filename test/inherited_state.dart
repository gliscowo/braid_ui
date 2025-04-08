import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/shared_state.dart';
import 'package:diamond_gl/diamond_gl.dart';
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
    return DefaultTextStyle(
      style: TextStyle(fontSize: 24.0, color: Color.white, bold: false, italic: false),
      child: SharedState(
        initState: CounterState.new,
        child: Row(children: [Flexible(child: Center(child: LeftBody())), Flexible(child: Center(child: RightBody()))]),
      ),
    );
  }
}

class LeftBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(text: 'current state: ${SharedState.get<CounterState>(context).count}');
  }
}

class RightBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Button(
      onClick: () => SharedState.set<CounterState>(context, (state) => state.count += 1),
      text: 'increment',
    );
  }
}

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/split_pane.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'drag test moment',
    baseLogger: Logger('drag_test'),
    windowWidth: 600,
    windowHeight: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const DragApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class DragApp extends StatelessWidget {
  const DragApp();

  @override
  Widget build(BuildContext context) {
    return const HorizontalSplitPane(
      leftChild: Panel(key: Key('a'), color: Color.blue),
      rightChild: VerticalSplitPane(
        key: Key('b'),
        topChild: Flexible(child: Panel(color: Color.white)),
        bottomChild: Flexible(child: Panel(color: Color.red)),
      ),
    );
  }
}

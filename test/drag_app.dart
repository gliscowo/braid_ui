import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/layout_builder.dart';
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
    resources: BraidResources.filesystem(
      fontDirectory: 'resources/font',
      shaderDirectory: 'resources/shader',
    ),
    widget: const DragApp(),
  );

  runBraidApp(
    app: app,
    experimentalReloadHook: true,
  );
}

class DragApp extends StatelessWidget {
  const DragApp();

  @override
  Widget build(BuildContext context) {
    return const SplitPane(
      firstChild: Panel(
        key: Key('a'),
        color: Color.blue,
      ),
      secondChild: SplitPane(
        key: Key('b'),
        axis: LayoutAxis.vertical,
        firstChild: Flexible(child: Panel(color: Color.white)),
        secondChild: Flexible(child: Panel(color: Color.red)),
      ),
    );
  }
}

class SplitPane extends StatefulWidget {
  final Widget firstChild;
  final Widget secondChild;
  final LayoutAxis axis;

  const SplitPane({
    super.key,
    this.axis = LayoutAxis.horizontal,
    required this.firstChild,
    required this.secondChild,
  });

  @override
  WidgetState<StatefulWidget> createState() => _SplitPaneState();
}

class _SplitPaneState extends WidgetState<SplitPane> {
  double _splitLocation = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = widget.axis;
        final maxSize = constraints.maxOnAxis(axis) - 6;

        final firstConstraints =
            Constraints.tight(axis.createSize(maxSize * _splitLocation, constraints.maxOnAxis(axis.opposite)));
        final secondConstraints =
            Constraints.tight(axis.createSize(maxSize * (1 - _splitLocation), constraints.maxOnAxis(axis.opposite)));

        return Flex(
          mainAxis: axis,
          children: [
            Constrained(
              key: widget.firstChild.key,
              constraints: firstConstraints,
              child: widget.firstChild,
            ),
            Flexible(
              key: const Key('splitter'),
              child: MouseArea(
                cursorStyle: axis.choose(CursorStyle.horizontalResize, CursorStyle.verticalResize),
                dragCallback: (dx, dy) => setState(() {
                  _splitLocation = (_splitLocation + axis.choose(dx, dy) / constraints.maxOnAxis(axis)).clamp(0.1, 0.9);
                }),
                child: Panel(color: Color.green),
              ),
            ),
            Constrained(
              key: widget.secondChild.key,
              constraints: secondConstraints,
              child: widget.secondChild,
            )
          ],
        );
      },
    );
  }
}

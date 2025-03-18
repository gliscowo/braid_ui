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
    return const HorizontalSplitPane(
      leftChild: Panel(
        key: Key('a'),
        color: Color.blue,
      ),
      rightChild: VerticalSplitPane(
        key: Key('b'),
        topChild: Flexible(child: Panel(color: Color.white)),
        bottomChild: Flexible(child: Panel(color: Color.red)),
      ),
    );
  }
}

class VerticalSplitPane extends SplitPane {
  const VerticalSplitPane({
    super.key,
    required Widget topChild,
    required Widget bottomChild,
  }) : super(
          axis: LayoutAxis.vertical,
          firstChild: topChild,
          secondChild: bottomChild,
        );
}

class HorizontalSplitPane extends SplitPane {
  const HorizontalSplitPane({
    super.key,
    required Widget leftChild,
    required Widget rightChild,
  }) : super(
          axis: LayoutAxis.horizontal,
          firstChild: leftChild,
          secondChild: rightChild,
        );
}

class SplitPane extends StatefulWidget {
  final Widget firstChild;
  final Widget secondChild;
  final LayoutAxis axis;

  const SplitPane({
    super.key,
    required this.axis,
    required this.firstChild,
    required this.secondChild,
  });

  @override
  WidgetState<StatefulWidget> createState() => _SplitPaneState();
}

class _SplitPaneState extends WidgetState<SplitPane> {
  double? _splitCoordinate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = widget.axis;
        final maxSize = constraints.maxOnAxis(axis) - 4;

        final split = (_splitCoordinate ??= .5 * maxSize).clamp(.1 * maxSize, .9 * maxSize).toDouble();

        final firstConstraints = Constraints.tight(axis.createSize(split, constraints.maxOnAxis(axis.opposite)));
        final secondConstraints =
            Constraints.tight(axis.createSize(maxSize - split, constraints.maxOnAxis(axis.opposite)));

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
                  _splitCoordinate = (_splitCoordinate! + axis.choose(dx, dy));
                }),
                dragEndCallback: () => _splitCoordinate = _splitCoordinate!.clamp(.1 * maxSize, .9 * maxSize),
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

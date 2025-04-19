import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/framework/proxy.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/drag_arena.dart';
import 'package:braid_ui/src/widgets/stack.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'colors !!',
    baseLogger: Logger('colors_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const DragArenaApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class DragArenaApp extends StatelessWidget {
  const DragArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PanArena(
      children: [
        const FunnyDraggable(
          child: Sized(width: 50, height: 50, child: Panel(color: Color.red, cornerRadius: CornerRadius.all(5))),
        ),
        FunnyDraggable(
          child: Panel(
            color: Color.green,
            cornerRadius: const CornerRadius.all(5),
            child: Padding(insets: const Insets.all(10), child: Button(onClick: () {}, text: 'a funny button')),
          ),
        ),
        const FunnyDraggable(
          child: Panel(
            color: Color.white,
            cornerRadius: CornerRadius.all(10),
            child: Padding(
              insets: Insets.all(25),
              child: Resizable(
                initialSize: Size(200, 200),
                child: Panel(
                  color: Color.black,
                  child: PanArena(
                    children: [
                      FunnyDraggable(
                        child: Sized(
                          width: 50,
                          height: 50,
                          child: Panel(color: Color.red, cornerRadius: CornerRadius.all(5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const FunnyDraggable(
          child: Sized(width: 50, height: 50, child: Panel(color: Color.blue, cornerRadius: CornerRadius.all(5))),
        ),
      ],
    );
  }
}

class FunnyDraggable extends StatefulWidget {
  final Widget child;
  const FunnyDraggable({super.key, required this.child});

  @override
  WidgetState<FunnyDraggable> createState() => _FunnyDraggableState();
}

class _FunnyDraggableState extends WidgetState<FunnyDraggable> {
  double x = 0;
  double y = 0;

  @override
  Widget build(BuildContext context) {
    return DragArenaElement(
      x: x,
      y: y,
      child: MouseArea(
        cursorStyle: CursorStyle.hand,
        dragCallback: (_, _, dx, dy) {
          setState(() {
            x += dx;
            y += dy;
          });
        },
        child: widget.child,
      ),
    );
  }
}

class PanArena extends StatefulWidget {
  final List<Widget> children;
  const PanArena({super.key, required this.children});

  @override
  WidgetState<PanArena> createState() => _PanArenaState();
}

class _PanArenaState extends WidgetState<PanArena> {
  final Matrix4 _matrix = Matrix4.identity();

  double xOffset = 0;
  double yOffset = 0;
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Clip(
      child: MouseArea(
        cursorStyle: CursorStyle.move,
        dragCallback: (_, _, dx, dy) {
          setState(() {
            xOffset += dx;
            yOffset += dy;

            _recompute();
          });
        },
        scrollCallback: (_, vertical) {
          setState(() {
            scale += scale * .1 * vertical;
            _recompute();
          });
        },
        child: Stack(
          children: [
            CustomDraw(
              drawFunction: (ctx, transform) {
                ctx.transform.scope((mat4) {
                  mat4.translate(xOffset, yOffset);

                  mat4.translate(transform.width / 2 - 5000, transform.height / 2);
                  ctx.primitives.rect(10000, 1, const Color.rgb(0xb1aebb), ctx.transform, ctx.projection);

                  mat4.translate(5000.0, -5000.0);
                  ctx.primitives.rect(1, 10000, const Color.rgb(0xb1aebb), ctx.transform, ctx.projection);
                });
              },
            ),
            Transform(matrix: _matrix, child: DragArena(children: widget.children)),
          ],
        ),
      ),
    );
  }

  void _recompute() {
    _matrix
      ..setIdentity()
      ..setTranslationRaw(xOffset, yOffset, 0)
      ..scale(scale);
  }
}

class Resizable extends StatefulWidget {
  final Widget child;
  final Size initialSize;

  const Resizable({super.key, required this.initialSize, required this.child});

  @override
  WidgetState<Resizable> createState() => _ResizableState();
}

class _ResizableState extends WidgetState<Resizable> {
  late Size size;

  @override
  void init() {
    super.init();
    size = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    return Sized(
      width: size.width + 1,
      height: size.height + 1,
      child: Row(
        children: [
          Flexible(
            child: Column(
              children: [
                Flexible(child: widget.child),
                MouseArea(
                  cursorStyle: CursorStyle.verticalResize,
                  dragCallback:
                      (_, _, _, dy) => setState(() {
                        size = size.copy(height: size.height + dy);
                      }),
                  child: Padding(insets: const Insets(top: 1)),
                ),
              ],
            ),
          ),
          MouseArea(
            cursorStyle: CursorStyle.horizontalResize,
            dragCallback:
                (_, _, dx, _) => setState(() {
                  size = size.copy(width: size.width + dx);
                }),
            child: Padding(insets: const Insets(left: 1)),
          ),
        ],
      ),
    );
  }
}

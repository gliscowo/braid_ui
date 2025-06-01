import 'package:diamond_gl/diamond_gl.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'drag_arena.dart';
import 'flex.dart';
import 'icon.dart';
import 'text.dart';

class Window extends StatefulWidget {
  final bool collapsible;
  final String title;
  final void Function()? onClose;
  final Widget content;
  final WindowController? controller;

  const Window({
    super.key,
    this.collapsible = true,
    this.onClose,
    this.controller,
    required this.title,
    required this.content,
  });

  @override
  WidgetState<Window> createState() => _WindowState();
}

class WindowController {
  double x;
  double y;
  bool expanded;
  Size size;

  WindowController({this.x = 0, this.y = 0, this.expanded = true, required this.size});
}

class _WindowState extends WidgetState<Window> {
  late WindowController controller;
  Set<_WindowEdge>? draggingEdges;

  @override
  void init() {
    super.init();
    controller = widget.controller ?? WindowController(size: const Size(300, 200));
  }

  @override
  void didUpdateWidget(Window oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null) {
      controller = widget.controller!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragArenaElement(
      x: controller.x,
      y: controller.y,
      child: MouseArea(
        cursorStyleSupplier: (x, y) => switch (_edgesAt(x, y).toList()) {
          [_WindowEdge.top] || [_WindowEdge.bottom] => CursorStyle.verticalResize,
          [_WindowEdge.left] || [_WindowEdge.right] => CursorStyle.horizontalResize,
          [_WindowEdge.top, _WindowEdge.left] || [_WindowEdge.bottom, _WindowEdge.right] => CursorStyle.nwseResize,
          [_WindowEdge.bottom, _WindowEdge.left] || [_WindowEdge.top, _WindowEdge.right] => CursorStyle.neswResize,
          _ => null,
        },
        clickCallback: (x, y, _) {
          draggingEdges = _edgesAt(x, y);
          return true;
        },
        dragCallback: (x, y, dx, dy) => setState(() => _resize(dx, dy)),
        dragEndCallback: () => draggingEdges = null,
        child: Padding(
          insets: const Insets.all(10),
          child: HitTestTrap(
            child: MouseArea(
              dragCallback: (_, _, dx, dy) => setState(() {
                controller.x += dx;
                controller.y += dy;
              }),
              child: Column(
                children: [
                  Sized(
                    width: controller.size.width,
                    height: 25,
                    child: Panel(
                      color: const Color.rgb(0x5f43b2),
                      cornerRadius: controller.expanded ? const CornerRadius.top(10.0) : const CornerRadius.all(10.0),
                      child: Padding(
                        insets: const Insets.axis(horizontal: 5),
                        child: Row(
                          children: [
                            if (widget.collapsible)
                              Actions.click(
                                cursorStyle: CursorStyle.hand,
                                onClick: () => setState(() => controller.expanded = !controller.expanded),
                                child: Icon(icon: controller.expanded ? Icons.arrow_drop_down : Icons.arrow_drop_up),
                              ),
                            Text(widget.title, style: const TextStyle(fontSize: 14.0, bold: true)),
                            Flexible(child: Padding(insets: const Insets())),
                            if (widget.onClose != null)
                              Actions.click(
                                cursorStyle: CursorStyle.hand,
                                onClick: () => widget.onClose?.call(),
                                child: Icon(icon: Icons.close, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: controller.expanded,
                    child: Panel(
                      color: const Color(0xbb161616),
                      cornerRadius: const CornerRadius.bottom(10.0),
                      child: Sized(
                        width: controller.size.width,
                        height: controller.size.height,
                        child: Clip(
                          child: Padding(insets: const Insets.all(10), child: widget.content),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Set<_WindowEdge> _edgesAt(double x, double y) {
    final result = <_WindowEdge>{};

    if (y < 10) result.add(_WindowEdge.top);
    if (y > controller.size.height + 10 + 25) result.add(_WindowEdge.bottom);

    if (x < 10) result.add(_WindowEdge.left);
    if (x > controller.size.width + 10) result.add(_WindowEdge.right);

    return result;
  }

  void _resize(double dx, double dy) {
    if (draggingEdges!.contains(_WindowEdge.top)) {
      controller.size = controller.size.copy(height: controller.size.height - dy);
      controller.y += dy;
    } else if (draggingEdges!.contains(_WindowEdge.bottom)) {
      controller.size = controller.size.copy(height: controller.size.height + dy);
    }

    if (draggingEdges!.contains(_WindowEdge.left)) {
      controller.size = controller.size.copy(width: controller.size.width - dx);
      controller.x += dx;
    } else if (draggingEdges!.contains(_WindowEdge.right)) {
      controller.size = controller.size.copy(width: controller.size.width + dx);
    }
  }
}

enum _WindowEdge { top, left, right, bottom }

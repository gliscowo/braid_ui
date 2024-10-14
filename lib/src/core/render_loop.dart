import 'package:braid_ui/src/context.dart';
import 'package:braid_ui/src/core/constraints.dart';
import 'package:braid_ui/src/core/cursors.dart';
import 'package:braid_ui/src/core/math.dart';
import 'package:braid_ui/src/core/widget.dart';
import 'package:braid_ui/src/core/widget_base.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';

var _hovered = <Widget>{};

void drawFrame(DrawContext ctx, CursorController cursorController, Widget widget) {
  final window = ctx.renderContext.window;

  gl.clearColor(0, 0, 0, 1);
  gl.clear(glColorBufferBit);

  ctx.primitives.gradientRect(
    window.width.toDouble(),
    window.height.toDouble(),
    Color.ofRgb(0xD2E0FB),
    Color.ofRgb(0x8EACCD),
    0,
    1,
    DateTime.now().millisecondsSinceEpoch / 100 % 360,
    ctx.transform,
    ctx.projection,
  );

  ctx.transform.scopeWith(widget.transform.toParent, (_) {
    widget.update();
    widget.draw(ctx);
  });

  final state = HitTestState();
  widget.hitTest(window.cursorX, window.cursorY, state);

  // TODO proper hit test occlusion
  final nowHovered = <Widget>{};
  for (final (widget, _) in state.trace) {
    nowHovered.add(widget);

    if (_hovered.contains(widget)) {
      _hovered.remove(widget);
    } else {
      if (widget is MouseListener) {
        (widget as MouseListener).onMouseEnter();
      }
    }
  }

  cursorController.style =
      (state.firstWhere((widget) => widget is MouseArea && widget.cursorStyle != null)?.$1 as MouseArea?)
              ?.cursorStyle ??
          CursorStyle.none;

  for (final noLongerHovered in _hovered) {
    if (noLongerHovered is MouseListener) {
      (noLongerHovered as MouseListener).onMouseExit();
    }
  }

  _hovered = nowHovered;

  Column(children: [
    Padding(
      insets: Insets.all(10),
      child: Label.string(text: state.toString(), fontSize: 18),
    ),
    Padding(
      insets: Insets.all(10),
      child: Label.string(text: 'hit ${state.lastHit.$1.runtimeType} at ${state.lastHit.$2}', fontSize: 18),
    ),
  ])
    ..layout(
      LayoutContext(ctx.textRenderer),
      Constraints.loose(Size(window.width.toDouble(), window.height.toDouble())),
    )
    ..draw(ctx);

  if (ctx.drawBoundingBoxes) {
    final aabb = widget.transform.aabb;
    ctx.transform.scope((mat4) {
      mat4.translate(aabb.min.x, aabb.min.y, 0);
      ctx.primitives.roundedRect(aabb.width, aabb.height, 5, Color.black, mat4, ctx.projection, outlineThickness: 1);
    });
  }

  window.nextFrame();
}

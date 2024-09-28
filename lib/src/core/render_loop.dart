import 'package:braid_ui/src/context.dart';
import 'package:braid_ui/src/core/widget.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';

import '../text/text.dart';

void drawFrame(DrawContext ctx) {
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

  final widget = Widget(
    500,
    200,
    100,
    40,
    // scale: 3 + sin(DateTime.now().millisecondsSinceEpoch / 1000),
    // rotation: degrees2Radians * DateTime.now().millisecondsSinceEpoch / 10 % 360,
  );
  ctx.transform.scopeWith(widget.transform, (_) {
    widget.draw(ctx, widget.hitTest(window.cursorX, window.cursorY));
  });

  final text = Text.string('hi chyz! nya~ :3');
  final size = ctx.textRenderer.sizeOf(text, 30);

  ctx.transform.scope((mat4) {
    final centerX = ((window.width - size.width) / 2), centerY = ((window.height - size.height) / 2);
    mat4.translate(centerX, centerY);

    ctx.textRenderer.drawText(text, 30, mat4, ctx.projection);
  });

  window.nextFrame();
}

import 'package:braid_ui/src/context.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';

import '../text/text.dart';

void drawFrame(DrawContext ctx) {
  final window = ctx.renderContext.window;

  gl.clearColor(0, 0, 0, 1);
  gl.clear(glColorBufferBit);

  ctx.primitives.gradientRect(
    0,
    0,
    window.width.toDouble(),
    window.height.toDouble(),
    Color.ofRgb(0xD2E0FB),
    Color.ofRgb(0x8EACCD),
    0,
    1,
    DateTime.now().millisecondsSinceEpoch / 100 % 360,
    ctx.projection,
  );

  final text = Text.string('hi chyz! nya~ :3');
  final size = ctx.textRenderer.sizeOf(text, 30);

  final centerX = ((window.width - size.width) / 2), centerY = ((window.height - size.height) / 2);

  ctx.primitives.circle(centerX - 100, centerY - 100, 25, Color.green, ctx.projection);
  ctx.primitives.rect(centerX + 100, centerY + 100, 100, 50, Color.blue, ctx.projection);

  ctx.textRenderer.drawText(centerX.round(), centerY.round(), text, 30, ctx.projection);

  window.nextFrame();
}

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/clawclip.dart' as cc;
import 'package:braid_ui/opengl.dart';
import 'package:braid_ui/sdl.dart';
import 'package:ffi/ffi.dart';

Future<void> main() async {
  sdlInit(sdlInitVideo);

  final window = cc.Window(400, 400, 'input debugging');
  window.activateContext();

  window.onKey.listen((event) {
    print(
      '[key] action: ${event.action}, key: ${sdlGetKeyName(event.key).cast<Utf8>().toDartString()}, scancode: ${event.scancode}, mods: ${event.mods}',
    );
  });

  cc.Window.disableVsyncInContext();

  while (!window.shouldClose) {
    final color = Color.ofHsv((DateTime.now().millisecondsSinceEpoch / 5000) % 1, .65, 1);

    gl.clearColor(color.r, color.g, color.b, 1);
    gl.clear(glColorBufferBit);

    window.swapBuffers();
    cc.Window.pollEvents();
    await Future.delayed(const Duration(milliseconds: 16));
  }

  sdlQuit();
}

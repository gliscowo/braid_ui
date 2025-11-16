import 'dart:async';

import 'package:braid_ui/diamond_gl.dart' as dgl;
import 'package:braid_ui/glfw.dart';

Future<void> main() async {
  dgl.initDiamondGL();

  glfwInit();

  final window = dgl.Window(200, 200, 'a');

  final completed = Completer<()>();
  final timer = Timer.periodic(Duration(microseconds: Duration.microsecondsPerSecond ~/ 60), (timer) {
    window.activateContext();
    glfwSwapBuffers(window.handle);
    glfwPollEvents();
    dgl.Window.dropContext();
  });

  final closeListener = window.onClose.listen((event) {
    timer.cancel();
    completed.complete(const ());
  });

  await completed.future;
  closeListener.cancel();

  window.dispose();
}

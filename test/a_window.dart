import 'dart:async';

import 'package:braid_ui/clawclip.dart' as cc;
import 'package:braid_ui/sdl.dart';

Future<void> main() async {
  sdlInit(sdlInitVideo);

  final window = cc.Window(200, 200, 'a');

  final completed = Completer<()>();
  final timer = Timer.periodic(Duration(microseconds: Duration.microsecondsPerSecond ~/ 60), (timer) {
    window.activateContext();
    window.swapBuffers();
    cc.Window.pollEvents();
    window.dropContext();
  });

  final closeListener = window.onClose.listen((event) {
    timer.cancel();
    completed.complete(const ());
  });

  await completed.future;
  closeListener.cancel();

  window.dispose();
}

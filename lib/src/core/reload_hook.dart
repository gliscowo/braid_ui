import 'dart:async';
import 'dart:developer';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Stream<()>? _reloadEvents;

Future<Stream<()>> getReloadHook() async {
  if (_reloadEvents == null) {
    final controller = await _setupReloadHook();

    if (controller != null) {
      _reloadEvents = controller.stream;
    } else {
      _reloadEvents = Stream.empty();
    }
  }

  return _reloadEvents!;
}

Future<StreamController<()>?> _setupReloadHook() async {
  final serviceUri = (await Service.getInfo()).serverWebSocketUri;
  if (serviceUri == null) return null;

  final service = await vmServiceConnectUri(serviceUri.toString());
  await service.streamListen(EventStreams.kIsolate);

  var refCount = 0;
  final controller = StreamController<()>(
    onListen: () => refCount++,
    onCancel: () {
      if (--refCount <= 0) {
        service.dispose();
        _reloadEvents = null;
      }
    },
  );

  service.onIsolateEvent.listen((event) {
    if (event.kind != 'IsolateReload') return;
    controller.add(const ());
  });

  return controller;
}

import 'dart:developer';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void Function()?> setupReloadHook(void Function() callback) async {
  final serviceUri = (await Service.getInfo()).serverWebSocketUri;
  if (serviceUri == null) return null;

  final service = await vmServiceConnectUri(serviceUri.toString());
  await service.streamListen(EventStreams.kIsolate);

  service.onIsolateEvent.listen((event) {
    if (event.kind != 'IsolateReload') return;
    callback();
  });

  return () => service.dispose();
}

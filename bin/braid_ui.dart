import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

final _logger = Logger('braid');

void main(List<String> arguments) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  runBraidApp(
    name: 'the chyz greeter :3',
    baseLogger: _logger,
  );
}

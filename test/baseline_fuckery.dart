import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: 'baselines',
    baseLogger: Logger('baseline_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const BaselineApp(),
  );

  runBraidApp(app: app, reloadHook: true);
}

class BaselineApp extends StatelessWidget {
  const BaselineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: Color.white,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          insets: const Insets(top: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Sized(width: 100, height: 32, child: Panel(color: Color.blue)),
              // Label(text: 'Warning', style: LabelStyle(lineHeight: 1.0, fontSize: 32, textColor: Color.black)),
              Icon(icon: Icons.warning, size: 32, color: Color.black),
            ],
          ),
        ),
      ),
    );
  }
}

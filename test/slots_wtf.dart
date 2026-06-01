import 'package:braid_ui/braid_ui.dart';

Future<void> main() async {
  final (app, _) = await createBraidAppWithWindow(
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const TestApp(),
  );

  await runBraidApp(app: app, reloadHook: true);
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  WidgetState<StatefulWidget> createState() => _TestAppState();
}

class _TestAppState extends WidgetState<TestApp> {
  bool toggled = false;

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Column(
        children: [
          Button(onClick: () => setState(() => toggled = !toggled), child: Text('flip')),
          toggled ? NotText(keyText: 'a') : NotText(keyText: 'b'),
          !toggled ? NotText(keyText: 'a') : NotText(keyText: 'b'),
        ],
      ),
    );
  }
}

class NotText extends StatelessWidget {
  final String keyText;
  NotText({required this.keyText}) : super(key: Key(keyText));

  @override
  Widget build(BuildContext context) {
    return Text('text $keyText');
  }
}

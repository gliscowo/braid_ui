import 'package:braid_ui/braid_ui.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final (app, _) = await createBraidAppWithWindow(
    name: "Regulating Device",
    width: 600,
    height: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const RegulatingDeviceApp(),
  );

  runBraidApp(app: app, reloadHook: true);
}

class RegulatingDeviceApp extends StatelessWidget {
  const RegulatingDeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      buttonStyle: const ButtonStyle(
        color: Color.rgb(0xbac3ff),
        highlightColor: Color.rgb(0xaeb7f3),
        // textColor: Color.rgb(0x222c61),
        padding: Insets.axis(horizontal: 25.0, vertical: 15.0),
        cornerRadius: CornerRadius.all(27.5),
      ),
      child: Panel(
        color: Color.rgb(0x121318),
        cornerRadius: const CornerRadius.all(10),
        child: Flex(
          mainAxis: LayoutAxis.vertical,
          children: [
            Padding(
              insets: const Insets.all(15.0).copy(bottom: 25.0),
              child: Text(
                "Regulating Device",
                style: TextStyle(bold: true, fontFamily: "Nunito", color: Color.white),
              ),
            ),
            Padding(
              insets: const Insets.axis(horizontal: 10.0),
              child: Flex(
                mainAxis: LayoutAxis.vertical,
                children: [
                  buttonPanel(Icon(icon: Icons.settings), "Settings", [
                    Button(child: Text("On"), onClick: () => ()),
                    Button(child: Text("Off"), onClick: () => ()),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget buttonPanel(Icon icon, String name, List<Widget> buttons) {
  return Padding(
    insets: const Insets(bottom: 10.0),
    child: Flex(
      mainAxis: LayoutAxis.horizontal,
      children: [
        Flexible(
          child: Panel(
            color: Color.rgb(0x1b1b21),
            child: Padding(
              insets: const Insets.all(20.0),
              child: Flex(
                mainAxis: LayoutAxis.vertical,
                children: [
                  Flex(
                    mainAxis: LayoutAxis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      icon,
                      Padding(insets: const Insets.all(10.0)),
                      Text(name, style: TextStyle(fontSize: 18.0)),
                    ],
                  ),
                  Padding(
                    insets: const Insets(top: 20.0),
                    child: Flex(
                      mainAxis: LayoutAxis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: buttons,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/baked_assets.g.dart';
import 'package:braid_ui/src/framework/widget.dart';
import 'package:braid_ui/src/widgets/basic.dart';
import 'package:braid_ui/src/widgets/icon.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final app = await createBraidApp(
    name: "Regulating Device",
    windowWidth: 600,
    windowHeight: 400,
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    widget: const RegulatingDeviceApp(),
  );

  runBraidApp(app: app, experimentalReloadHook: true);
}

class RegulatingDeviceApp extends StatelessWidget {
  const RegulatingDeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultButtonStyle(
      style: const ButtonStyle(
        color: Color.rgb(0xbac3ff),
        hoveredColor: Color.rgb(0xaeb7f3),
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
                text: "Regulating Device",
                style: TextStyle(bold: true, fontFamily: "Nunito", color: Color.white),
              ),
            ),
            Padding(
              insets: const Insets.axis(horizontal: 10.0),
              child: Flex(
                mainAxis: LayoutAxis.vertical,
                children: [
                  buttonPanel(Icon(icon: Icons.settings), "Settings", [
                    Button(text: "On", onClick: () => ()),
                    Button(text: "Off", onClick: () => ()),
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
                      Text(text: name, style: TextStyle(fontSize: 18.0)),
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

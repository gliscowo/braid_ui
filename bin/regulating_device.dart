import 'package:braid_ui/braid_ui.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';

void main(List<String> args) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  runBraidApp(
    name: "Regulating Device",
    windowWidth: 400,
    windowHeight: 750,
    widget: () {
      return ButtonTheme(
        color: Color.ofRgb(0xbac3ff),
        hoveredColor: Color.ofRgb(0xaeb7f3),
        textColor: Color.ofRgb(0x222c61),
        padding: Insets.axis(horizontal: 25.0, vertical: 15.0),
        cornerRadius: 25.0,
        child: Panel(
          cornerRadius: 0.0,
          color: Color.ofRgb(0x121318),
          child: Flex(
            mainAxis: LayoutAxis.vertical,
            children: [
              Padding(
                insets: Insets.all(15.0).copy(bottom: 25.0),
                child: Label(
                  textColor: Color.white,
                  text: Text.string(
                    "Regulating Device",
                    style: TextStyle(bold: true, fontFamily: "Nunito"),
                  ),
                ),
              ),
              Padding(
                insets: Insets.axis(horizontal: 10.0),
                child: Flex(
                  mainAxis: LayoutAxis.vertical,
                  children: [
                    buttonPanel(
                      Icon("settings"),
                      "Settings",
                      [
                        Button(text: Text.string("On"), onClick: (button) => ()),
                        Button(text: Text.string("Off"), onClick: (button) => ())
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}

Widget buttonPanel(Icon icon, String name, List<Widget> buttons) {
  return Padding(
    insets: Insets(bottom: 10.0),
    child: Flex(
      mainAxis: LayoutAxis.horizontal,
      children: [
        FlexChild(
          child: Panel(
            color: Color.ofRgb(0x1b1b21),
            child: Padding(
              insets: Insets.all(20.0),
              child: Flex(
                mainAxis: LayoutAxis.vertical,
                children: [
                  Flex(
                    mainAxis: LayoutAxis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Label(text: Text([icon])),
                      Padding(insets: Insets.all(10.0)),
                      Label(
                        text: Text.string(name),
                        fontSize: 18.0,
                      ),
                    ],
                  ),
                  Padding(
                    insets: Insets(top: 20.0),
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
        )
      ],
    ),
  );
}

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/core/constraints.dart';
import 'package:braid_ui/src/core/icons.dart';
import 'package:braid_ui/src/core/math.dart';
import 'package:braid_ui/src/core/widget.dart';
import 'package:braid_ui/src/core/widget_base.dart';
import 'package:braid_ui/src/text/text.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

final _logger = Logger('braid');

void main(List<String> arguments) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  // TODO tabbled layout or smth
  runBraidApp(
    baseLogger: _logger,
    widget: () => Center(
      child: Panel(
        color: Color.ofRgb(0x0e1420),
        child: Padding(
          insets: Insets.axis(vertical: 25, horizontal: 100),
          child: ConstrainedBox(
            constraints: Constraints.loose(Size(150, double.infinity)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutAfterTransform(
                  child: Transform(
                    matrix: Matrix4.rotationZ(45 * degrees2Radians),
                    child: StencilClip(
                      child: ItGoSpin(),
                    ),
                  ),
                ),
                for (final icon in ['home', 'apps', 'settings'])
                  Button(
                    text: Text([
                      Icon(icon),
                      TextSpan(' ${icon[0].toUpperCase()}${icon.substring(1)}'),
                    ]),
                    onClick: (button) => button.text = Text.string('Clicked!'),
                    color: Color.ofRgb(0x2f2f35),
                    hoveredColor: Color.ofRgb(0x35353b),
                  )
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ItGoSpin extends SingleChildWidget with ShrinkWrapLayout {
  late final Transform _transform;
  ItGoSpin() : super.lateChild() {
    initChild(
      _transform = Transform(
        matrix: Matrix4.identity(),
        child: HappyWidget(Size(200, 75)),
      ),
    );
  }

  @override
  void update() {
    _transform.matrix = Matrix4.rotationZ(DateTime.now().millisecondsSinceEpoch / 1000);
    // ..scale(sin(DateTime.now().millisecondsSinceEpoch / 250) + 1.5);
  }
}

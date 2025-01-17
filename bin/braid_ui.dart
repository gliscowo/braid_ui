import 'package:braid_ui/braid_ui.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

final _logger = Logger('braid');

void main(List<String> arguments) {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  Widget columnTestPage() {
    late Flex flex;
    return ConstrainedBox(
      constraints: const Constraints.only(minHeight: 250, maxHeight: 400),
      child: Panel(
        color: Color.white,
        child: flex = Flex(
          mainAxis: LayoutAxis.vertical,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const Constraints.only(minWidth: 100),
              child: Button(
                text: Text.string("flip!"),
                onClick: (button) => flex.mainAxis = flex.mainAxis.opposite,
                color: Color.black,
                hoveredColor: Color.red,
              ),
            ),
            HappyWidget(const Size(100, 50)),
            HappyWidget(const Size(100, 50)),
            FlexChild(
              child: HappyWidget(const Size(100, 50)),
            ),
            FlexChild(
              flexFactor: 2,
              child: HappyWidget(const Size(100, 50)),
            ),
          ],
        ),
      ),
    );
  }

  // TODO tabbled layout or smth
  runBraidApp(
    baseLogger: _logger,
    widget: () => Center(
      child: Panel(
        color: Color.ofRgb(0x0e1420),
        child: Padding(
          insets: const Insets.axis(vertical: 25, horizontal: 100),
          child: Flex(
            mainAxis: LayoutAxis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LayoutAfterTransform(
                child: Transform(
                  matrix: Matrix4.rotationZ(45 * degrees2Radians),
                  child: StencilClip(
                    child: ItGoSpin(),
                  ),
                ),
              ),
              () {
                late final Pages pages;
                return Flex(
                  mainAxis: LayoutAxis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flex(
                      mainAxis: LayoutAxis.horizontal,
                      children: [
                        for (final (idx, icon) in ['home', 'apps', 'settings'].indexed)
                          ConstrainedBox(
                            constraints: const Constraints.only(minWidth: 125),
                            child: Button(
                              text: Text([
                                Icon(icon),
                                TextSpan(' ${icon[0].toUpperCase()}${icon.substring(1)}'),
                              ]),
                              onClick: (button) => pages.page = idx,
                              color: Color.ofRgb(0x2f2f35),
                              hoveredColor: Color.ofRgb(0x35353b),
                            ),
                          ),
                      ],
                    ),
                    Panel(
                      color: Color.green,
                      cornerRadius: 0,
                      child: pages = Pages(
                        cache: false,
                        pageBuilders: [
                          () => Label(text: Text.string("page 1")),
                          columnTestPage,
                          () => Label(text: Text.string("page 3")),
                        ],
                      ),
                    )
                  ],
                );
              }()
            ],
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
  void update(double delta) {
    _transform.matrix = Matrix4.rotationZ(DateTime.now().millisecondsSinceEpoch / 1000);
    // ..scale(sin(DateTime.now().millisecondsSinceEpoch / 250) + 1.5);
  }
}

import 'package:braid_ui/braid_ui.dart';
import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

final _logger = Logger('braid');

Future<void> main(List<String> arguments) async {
  loadNatives('resources/lib');
  loadOpenGL();
  loadGLFW(BraidNatives.activeLibraries.spec.glfw);
  initDiamondGL(logger: _logger);

  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  WidgetInstance columnTestPage() {
    late FlexInstance flex;
    return ConstrainedInstance(
      constraints: const Constraints.only(minHeight: 250, maxHeight: 400),
      child: PanelInstance(
        color: Color.white,
        child: flex = FlexInstance(
          mainAxis: LayoutAxis.vertical,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ConstrainedInstance(
              constraints: const Constraints.only(minWidth: 100),
              child: Button.text(
                text: "flip!",
                onClick: (button) => flex.mainAxis = flex.mainAxis.opposite,
                style: ButtonStyle(
                  color: Color.black,
                  hoveredColor: Color.red,
                ),
              ),
            ),
            HappyWidget(const Size(100, 50)),
            HappyWidget(const Size(100, 50)),
            FlexChildInstance(
              child: HappyWidget(const Size(100, 50)),
            ),
            FlexChildInstance(
              flexFactor: 2,
              child: HappyWidget(const Size(100, 50)),
            ),
          ],
        ),
      ),
    );
  }

  glfw.init();
  final window = Window(500, 500, "ayo, that's a non-braid window??");

  final app = await createBraidApp(
    resources: BraidResources.filesystem(
      fontDirectory: 'resources/font',
      shaderDirectory: 'resources/shader',
    ),
    baseLogger: _logger,
    window: window,
    widget: () => CenterInstance(
      child: PanelInstance(
        color: Color.ofRgb(0x0e1420),
        child: PaddingInstance(
          insets: const Insets.axis(vertical: 25, horizontal: 100),
          child: FlexInstance(
            mainAxis: LayoutAxis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LayoutAfterTransformInstance(
                child: TransformInstance(
                  matrix: Matrix4.rotationZ(45 * degrees2Radians),
                  child: StencilClipInstance(
                    child: ItGoSpin(),
                  ),
                ),
              ),
              () {
                late final Pages pages;
                return FlexInstance(
                  mainAxis: LayoutAxis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FlexInstance(
                      mainAxis: LayoutAxis.horizontal,
                      children: [
                        for (final (idx, icon) in ['home', 'apps', 'settings'].indexed)
                          ConstrainedInstance(
                            constraints: const Constraints.only(minWidth: 125),
                            child: Button(
                              child: LabelInstance.text(
                                text: Text([
                                  Icon(icon),
                                  Span(' ${icon[0].toUpperCase()}${icon.substring(1)}'),
                                ]),
                              ),
                              onClick: (button) => pages.page = idx,
                              style: ButtonStyle(
                                color: Color.ofRgb(0x2f2f35),
                                hoveredColor: Color.ofRgb(0x35353b),
                              ),
                            ),
                          ),
                      ],
                    ),
                    PanelInstance(
                      color: Color.green,
                      cornerRadius: 0,
                      child: pages = Pages(
                        cache: false,
                        pageBuilders: [
                          () => LabelInstance(text: "page 1"),
                          columnTestPage,
                          () => LabelInstance(text: "page 3"),
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

  runBraidApp(app: app);
}

class ItGoSpin extends SingleChildWidgetInstance with ShrinkWrapLayout {
  late final TransformInstance _transform;
  ItGoSpin() : super.lateChild() {
    initChild(
      _transform = TransformInstance(
        matrix: Matrix4.identity(),
        child: HappyWidget(const Size(200, 75)),
      ),
    );
  }

  @override
  void update(double delta) {
    _transform.matrix = Matrix4.rotationZ(DateTime.now().millisecondsSinceEpoch / 1000);
    // ..scale(sin(DateTime.now().millisecondsSinceEpoch / 250) + 1.5);
  }
}

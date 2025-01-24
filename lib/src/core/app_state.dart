import 'dart:async';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/text/text_renderer.dart';
import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

class AppState {
  final BraidResources resources;

  final Window window;
  final CursorController cursorController;
  final Matrix4 projection;

  final RenderContext context;
  final TextRenderer textRenderer;
  final PrimitiveRenderer primitives;

  final AppScaffold scaffold;
  final WidgetBuilder _widgetBuilder;
  KeyboardListener? _focused;

  final List<StreamSubscription> _subscriptions = [];

  AppState(
    this.resources,
    this.window,
    this.projection,
    this.context,
    this.textRenderer,
    this.primitives,
    this._widgetBuilder,
  )   : cursorController = CursorController.ofWindow(window),
        scaffold = AppScaffold(root: _widgetBuilder()) {
    _doScaffoldLayout();
    _subscriptions.add(window.onResize.listen((event) => _doScaffoldLayout()));

    // ---

    _subscriptions.addAll([
      window.onMouseButton
          .where((event) => event.action == glfwPress && event.button == glfwMouseButtonLeft)
          .listen((event) {
        final state = _hitTest();

        state.firstWhere(
          (widget) => widget is MouseListener && (widget as MouseListener).onMouseDown(),
        );

        _focused = state.firstWhere((widget) => widget is KeyboardListener)?.widget as KeyboardListener?;
      }),
      // ---
      window.onMouseScroll.listen((event) {
        _hitTest().firstWhere(
          (widget) => widget is MouseListener && (widget as MouseListener).onMouseScroll(event.xOffset, event.yOffset),
        );
      }),
      // ---
      window.onKey.where((event) => event.action == glfwPress || event.action == glfwRepeat).listen((event) {
        _focused?.onKeyDown(event.key, event.mods);
      }),
      // ---
      window.onChar.listen((event) {
        _focused?.onChar(event, 0);
      }),
    ]);
  }

  // TODO: there should be a separate function that doesn't go
  // through the [BraidResources] abstraction
  Future<void> loadFontFamily(String familyName, [String? identifier]) async {
    final family = await FontFamily.load(resources, familyName);
    textRenderer.addFamily(identifier ?? familyName, family);

    _doScaffoldLayout(force: true);
  }

  void dispose() {
    cursorController.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }

  HitTestState _hitTest([(double x, double y)? coordinates]) {
    final (x, y) = coordinates ?? (window.cursorX, window.cursorY);

    final state = HitTestState();
    scaffold.hitTest(x, y, state);

    return state;
  }

  void _doScaffoldLayout({bool force = false}) {
    if (force) {
      scaffold.clearLayoutCache();
    }

    scaffold.layout(
      LayoutContext(textRenderer, window),
      Constraints.tight(Size(window.width.toDouble(), window.height.toDouble())),
    );
  }
}

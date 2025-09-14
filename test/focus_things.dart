import 'dart:io';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/widgets/app_stack.dart';
import 'package:braid_ui/src/widgets/focus.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

Future<void> main() async {
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((event) {
    print('[${event.loggerName}] (${event.level.toString().toLowerCase()}) ${event.message}');
  });

  loadNatives('resources/lib');

  final (app, _) = await createBraidAppWithWindow(
    name: 'focus',
    baseLogger: Logger('focus_app'),
    resources: BraidResources.filesystem(fontDirectory: 'resources/font', shaderDirectory: 'resources/shader'),
    defaultFontFamily: 'NotoSans',
    widget: const FocusApp(),
  );

  runBraidApp(app: app, reloadHook: true);
}

class Blod extends StatelessWidget {
  final bool show;
  final Widget child;

  const Blod({super.key, required this.show, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (show)
          RawImage(
            key: Key('blod'),
            wrap: ImageWrap.mirroredRepeat,
            provider: FileImageProvider(File('test/blud.jpg')),
          ),
        StackBase(key: Key('child'), child: child),
      ],
    );
  }
}

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Blod(
        show: true,
        child: Navigator(
          initialRoute: BaseRoute(),
          routeBuilder: (route) {
            return FocusScope(autoFocus: true, child: Navigator.buildRouteDefault(route));
          },
        ),
      ),
    );
  }
}

class BaseRoute extends StatelessWidget {
  const BaseRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Resettable(
          child: Center(child: Blur(radius: 12.5, child: TheMess())),
        ),
        Align(
          alignment: Alignment.bottom,
          child: Padding(
            insets: const Insets(bottom: 60),
            child: Blur(
              radius: 20,
              child: Padding(
                insets: const Insets.all(10),
                child: SizeToAABB(
                  child: Transform(
                    matrix: Matrix4.identity()..scaleByDouble(4, 1, 1, 1),
                    child: const Text(
                      softWrap: false,
                      'me when left behind on\nplatform without chys',
                      style: TextStyle(color: Color.black, bold: true, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: FocusPolicy(
            clickFocus: false,
            child: Button(
              onClick: () {
                Navigator.pushOverlay(context, OverlayRoute());
              },
              child: Text('open overlay'),
            ),
          ),
        ),
      ],
    );
  }
}

class OverlayRoute extends StatelessWidget {
  const OverlayRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      clickCallback: (x, y, button) {
        Future.delayed(const Duration(seconds: 1)).then((value) {
          Navigator.pop(context);
        });
        return true;
      },
      child: const Blur(
        child: Align(alignment: Alignment.top, child: TheMess()),
      ),
    );
  }
}

class TheMess extends StatelessWidget {
  const TheMess({super.key});

  @override
  Widget build(BuildContext context) {
    return const VisuallyFocusable(
      child: VisuallyFocusable(
        child: VisuallyFocusable(
          child: Row(
            children: [
              VisuallyFocusable(
                child: VisuallyFocusable(
                  child: VisuallyFocusable(child: Sized(width: 100, height: 100, child: EmptyWidget())),
                ),
              ),
              VisuallyFocusable(
                // autoFocus: true,
                child: VisuallyFocusable(
                  child: VisuallyFocusable(child: Sized(width: 100, height: 100, child: EmptyWidget())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Resettable extends StatefulWidget {
  final Widget child;
  const Resettable({super.key, required this.child});

  @override
  WidgetState<Resettable> createState() => _ResettableState();
}

class _ResettableState extends WidgetState<Resettable> {
  int generation = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(key: Key('$generation'), insets: const Insets(), child: widget.child),
        Align(
          key: Key('button'),
          alignment: Alignment.bottomLeft,
          child: Padding(
            insets: const Insets.all(25),
            child: Button(
              onClick: () {
                print('reset');
                setState(() {
                  generation++;
                });
              },
              child: Text('reset state'),
            ),
          ),
        ),
      ],
    );
  }
}

class VisuallyFocusable extends StatefulWidget {
  final bool autoFocus;
  final Widget child;
  const VisuallyFocusable({super.key, this.autoFocus = false, required this.child});

  @override
  WidgetState<VisuallyFocusable> createState() => VisuallyFocusableState();
}

class VisuallyFocusableState extends WidgetState<VisuallyFocusable> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final depth = FocusNode.maybeOf(context)!.depth + 1;
    return Focusable(
      autoFocus: widget.autoFocus,
      focusGainedCallback: () => setState(() {
        focused = true;
      }),
      focusLostCallback: () => setState(() {
        focused = false;
      }),
      keyDownCallback: depth % 2 == 0
          ? (keyCode, modifiers) {
              if (keyCode != glfwKeySpace) return false;

              print('[$depth] space pressed');
              return true;
            }
          : null,
      child: Panel(
        color: Color.white,
        outlineThickness: 1,
        cornerRadius: const CornerRadius.all(2.5),
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Padding(insets: const Insets(top: 30, left: 30), child: widget.child),
            Padding(
              insets: const Insets.all(5),
              child: Text('$depth', style: TextStyle(color: focused ? Color.red : Color.black)),
            ),
          ],
        ),
      ),
    );
  }
}

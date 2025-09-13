import 'dart:async';

import 'package:braid_ui/braid_ui.dart';

Future<void> main() async {
  loadNatives('resources/lib');

  final apps = await Future.wait(
    List.generate(50, (index) => index + 1).map((idx) {
      return createBraidAppWithWindow(
        name: 'window $idx',
        width: 200,
        height: 200,
        resources: BakedAssetResources(fontDelegate: BraidResources.fonts('resources/font')),
        defaultFontFamily: 'NotoSans',
        widget: const TheApp(),
      ).then((value) => value.$1);
    }),
  );

  for (final app in apps) {
    runBraidApp(app: app, reloadHook: true, targetFps: 60);
  }
}

class TheApp extends StatelessWidget {
  const TheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BraidTheme(
      child: Stack(
        children: [
          Center(child: Counter()),
          Align(alignment: Alignment.topRight, child: FPS()),
          Align(alignment: Alignment.bottomRight, child: ProgressIndicator.indeterminate()),
        ],
      ),
    );
  }
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  WidgetState<Counter> createState() => _CounterState();
}

class _CounterState extends WidgetState<Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('count: $count'),
        Button(
          onClick: () => setState(() {
            count++;
          }),
          child: Text('add'),
        ),
      ],
    );
  }
}

class FPS extends StatefulWidget {
  const FPS({super.key});

  @override
  WidgetState<FPS> createState() => _FPSState();
}

class _FPSState extends WidgetState<FPS> {
  int countedFrames = 0;
  int displayedFps = 0;
  Duration elapsed = Duration.zero;

  void _update(Duration delta) {
    scheduleAnimationCallback(_update);

    countedFrames++;
    elapsed += delta;

    if (elapsed.inSeconds >= 1) {
      elapsed -= const Duration(seconds: 1);

      setState(() {
        displayedFps = countedFrames;
      });

      countedFrames = 0;
    }
  }

  @override
  void init() {
    scheduleAnimationCallback(_update);
  }

  @override
  Widget build(BuildContext context) {
    return Text('$displayedFps FPS');
  }
}

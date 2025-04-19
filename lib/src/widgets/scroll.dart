import 'dart:math';

import '../core/constraints.dart';
import '../core/listenable.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'flex.dart';
import 'slider.dart';

class ScrollWithSlider extends StatefulWidget {
  final Widget content;
  const ScrollWithSlider({super.key, required this.content});

  @override
  WidgetState<ScrollWithSlider> createState() => _ScrollWithSliderState();
}

class ListenableBuilder extends StatefulWidget {
  final Listenable listenable;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  ListenableBuilder({super.key, required this.listenable, required this.builder, this.child});

  @override
  WidgetState<ListenableBuilder> createState() => _ListenableBuilderState();
}

class _ListenableBuilderState extends WidgetState<ListenableBuilder> {
  @override
  void init() {
    widget.listenable.addListener(_listener);
  }

  @override
  void didUpdateWidget(ListenableBuilder oldWidget) {
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_listener);
      widget.listenable.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.child);
  }

  void _listener() => setState(() => {});
}

class _ScrollWithSliderState extends WidgetState<ScrollWithSlider> {
  final ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Row(
          children: [
            child!,
            if (controller.maxOffset != 0)
              Slider(
                axis: LayoutAxis.vertical,
                max: controller.maxOffset,
                step: 1,
                value: controller.offset,
                onUpdate: (value) => setState(() => controller.offset = value),
              ),
          ],
        );
      },
      child: Flexible(child: ScrollView.vertical(controller: controller, child: widget.content)),
    );
  }
}

class ScrollController with Listenable {
  ScrollController({double? initialOffset}) : offset = initialOffset ?? 0;

  double offset;

  double _maxOffset = 0;
  double get maxOffset => _maxOffset;

  void _setState(double offset, double maxOffset) {
    this.offset = offset;
    _maxOffset = maxOffset;

    notifyListeners();
  }
}

class ScrollView extends StatelessWidget {
  final Widget child;
  final bool vertical;
  final bool horizontal;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  const ScrollView({
    super.key,
    required this.horizontal,
    required this.vertical,
    this.horizontalController,
    this.verticalController,
    required this.child,
  });

  const ScrollView.horizontal({super.key, ScrollController? controller, required this.child})
    : horizontal = true,
      horizontalController = controller,
      vertical = false,
      verticalController = null;

  const ScrollView.vertical({super.key, ScrollController? controller, required this.child})
    : horizontal = false,
      horizontalController = null,
      vertical = true,
      verticalController = controller;

  const ScrollView.both({super.key, this.horizontalController, this.verticalController, required this.child})
    : horizontal = true,
      vertical = true;

  @override
  Widget build(BuildContext context) {
    return Clip(
      child: RawScrollView(
        horizontal: horizontal,
        vertical: vertical,
        horizontalController: horizontalController,
        verticalController: verticalController,
        child: child,
      ),
    );
  }
}

class RawScrollView extends SingleChildInstanceWidget {
  final bool horizontal;
  final bool vertical;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  RawScrollView({
    required this.horizontal,
    required this.vertical,
    required super.child,
    this.horizontalController,
    this.verticalController,
  });

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => RawScrollViewInstance(widget: this);
}

class RawScrollViewInstance extends SingleChildWidgetInstance<RawScrollView> with MouseListener {
  (double, double) maxScroll = const (0, 0);
  late ScrollController horizontalController;
  late ScrollController verticalController;

  RawScrollViewInstance({required super.widget}) {
    horizontalController = widget.horizontalController ?? ScrollController();
    verticalController = widget.verticalController ?? ScrollController();
  }

  @override
  set widget(RawScrollView value) {
    horizontalController = value.horizontalController ?? horizontalController;
    verticalController = value.verticalController ?? verticalController;

    if (widget.horizontal == value.horizontal && widget.vertical == value.vertical) {
      _updateAndApplyOffsets((currentHorizontal) => currentHorizontal, (currentVertical) => currentVertical);
      return;
    }

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final childSize = child.layout(
      constraints.copy(
        minWidth: widget.horizontal ? 0 : null,
        maxWidth: widget.horizontal ? double.infinity : null,
        minHeight: widget.vertical ? 0 : null,
        maxHeight: widget.vertical ? double.infinity : null,
      ),
    );

    maxScroll = (
      widget.horizontal ? max(0, childSize.width - constraints.maxWidth) : 0,
      widget.vertical ? max(0, childSize.height - constraints.maxHeight) : 0,
    );

    _updateAndApplyOffsets((currentHorizontal) => currentHorizontal, (currentVertical) => currentVertical);

    final selfSize = Size(
      widget.horizontal && constraints.hasBoundedWidth ? constraints.maxWidth : childSize.width,
      widget.vertical && constraints.hasBoundedHeight ? constraints.maxHeight : childSize.height,
    ).constrained(constraints);

    transform.setSize(selfSize);
  }

  @override
  bool onMouseScroll(double x, double y, double horizontal, double vertical) {
    _updateAndApplyOffsets(
      (currentHorizontal) => currentHorizontal - horizontal * 25,
      (currentVertical) => currentVertical - vertical * 25,
    );

    return true;
  }

  void _updateAndApplyOffsets(
    double Function(double currentHorizontal) horizontalUpdate,
    double Function(double currentVertical) verticalUpdate,
  ) {
    horizontalController._setState(horizontalUpdate(horizontalController.offset).clamp(0, maxScroll.$1), maxScroll.$1);
    verticalController._setState(verticalUpdate(verticalController.offset).clamp(0, maxScroll.$2), maxScroll.$2);

    child.transform.x = -horizontalController.offset;
    child.transform.y = -verticalController.offset;
  }
}

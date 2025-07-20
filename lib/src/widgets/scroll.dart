import 'dart:math';

import 'package:vector_math/vector_math.dart';

import '../core/constraints.dart';
import '../core/listenable.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';

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

class ScrollController with Listenable {
  double _offset;
  double _maxOffset;

  ScrollController({double offset = 0}) : _offset = offset, _maxOffset = 0;

  double get offset => _offset;
  set offset(double value) {
    if (_offset == value) return;

    _offset = value.clamp(0, _maxOffset);
    notifyListeners();
  }

  double get maxOffset => _maxOffset;
  bool _setMaxOffset(double value) {
    if (_maxOffset == value) return false;

    _maxOffset = value;
    _offset = offset.clamp(0, _maxOffset);

    return true;
  }

  bool _maxOffsetNotificationScheduled = false;
  void _sendMaxOffsetNotification() {
    notifyListeners();
    _maxOffsetNotificationScheduled = false;
  }
}

class Scrollable extends StatefulWidget {
  final bool horizontal;
  final bool vertical;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final Widget child;

  const Scrollable({
    super.key,
    required this.horizontal,
    required this.vertical,
    this.horizontalController,
    this.verticalController,
    required this.child,
  });

  const Scrollable.vertical({super.key, ScrollController? controller, required this.child})
    : horizontal = false,
      vertical = true,
      horizontalController = null,
      verticalController = controller;

  const Scrollable.horizontal({super.key, ScrollController? controller, required this.child})
    : horizontal = true,
      vertical = false,
      horizontalController = controller,
      verticalController = null;

  const Scrollable.both({super.key, this.horizontalController, this.verticalController, required this.child})
    : horizontal = true,
      vertical = true;

  @override
  WidgetState<Scrollable> createState() => ScrollableState();

  // ---

  static void reveal(BuildContext context) => of(context)._reveal(context);
  static void revealAabb(BuildContext context, Aabb3 box) => of(context)._revealAabb(context, box);

  static ScrollableState? maybeOf(BuildContext context) => context.dependOnAncestor<_ScrollableProvider>()?.state;
  static ScrollableState of(BuildContext context) => maybeOf(context)!;
}

class ScrollableState extends WidgetState<Scrollable> {
  final CompoundListenable _listenable = CompoundListenable();

  ScrollController? horizontalController;
  ScrollController? verticalController;

  void _reveal(BuildContext context) {
    _revealAabb(context, context.instance!.transform.aabb);
  }

  void _revealAabb(BuildContext context, Aabb3 box) {
    final scrollInstance = this.context.instance!;
    final revealInstance = context.instance!;

    final transform = revealInstance.computeTransformFrom(ancestor: scrollInstance)
      ..invert()
      ..translate(horizontalController?.offset ?? 0, verticalController?.offset ?? 0);
    final revealBox = Aabb3.copy(box)..transform(transform);

    if (horizontalController case var controller?) {
      if (revealBox.min.x < controller.offset) {
        controller.offset = revealBox.min.x;
      }

      if (revealBox.max.x > scrollInstance.transform.width + controller.offset) {
        controller.offset = revealBox.max.x - scrollInstance.transform.width;
      }
    }

    if (verticalController case var controller?) {
      if (revealBox.min.y < controller.offset) {
        controller.offset = revealBox.min.y;
      }

      if (revealBox.max.y > scrollInstance.transform.height + controller.offset) {
        controller.offset = revealBox.max.y - scrollInstance.transform.height;
      }
    }
  }

  @override
  void init() {
    horizontalController = widget.horizontal ? widget.horizontalController ?? ScrollController() : null;
    verticalController = widget.vertical ? widget.verticalController ?? ScrollController() : null;

    if (horizontalController != null) _listenable.addChild(horizontalController!);
    if (verticalController != null) _listenable.addChild(verticalController!);
  }

  @override
  void didUpdateWidget(Scrollable oldWidget) {
    _listenable.clear();

    if (widget.horizontal) {
      if (widget.horizontalController != null) {
        horizontalController = widget.horizontalController;
      } else if (horizontalController == null || horizontalController == oldWidget.horizontalController) {
        horizontalController = ScrollController();
      }

      _listenable.addChild(horizontalController!);
    } else {
      horizontalController = null;
    }

    if (widget.vertical) {
      if (widget.verticalController != null) {
        verticalController = widget.verticalController;
      } else if (verticalController == null || verticalController == oldWidget.verticalController) {
        verticalController = ScrollController();
      }

      _listenable.addChild(verticalController!);
    } else {
      verticalController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Clip(
      child: MouseArea(
        scrollCallback: (horizontal, vertical) {
          if (horizontalController != null && verticalController == null && horizontal == 0) {
            horizontal = vertical;
          }

          horizontalController?.offset += -horizontal * 25;
          verticalController?.offset += -vertical * 25;
          return horizontalController != null && verticalController != null;
        },
        child: ListenableBuilder(
          listenable: _listenable,
          builder: (context, child) {
            return RawScrollView(
              horizontalController: horizontalController,
              verticalController: verticalController,
              child: _ScrollableProvider(state: this, child: child!),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _ScrollableProvider extends InheritedWidget {
  final ScrollableState state;
  _ScrollableProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

class RawScrollView extends SingleChildInstanceWidget {
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  RawScrollView({required this.horizontalController, required this.verticalController, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => RawScrollViewInstance(widget: this);
}

class RawScrollViewInstance extends SingleChildWidgetInstance<RawScrollView> {
  double horizontalOffset = 0, maxHorizontalOffset = 0;
  double verticalOffset = 0, maxVerticalOffset = 0;

  RawScrollViewInstance({required super.widget}) {
    horizontalOffset = widget.horizontalController?.offset ?? 0;
    maxHorizontalOffset = widget.horizontalController?.maxOffset ?? 0;
    verticalOffset = widget.verticalController?.offset ?? 0;
    maxVerticalOffset = widget.verticalController?.maxOffset ?? 0;
  }

  @override
  set widget(RawScrollView value) {
    var horizontalOffset = widget.horizontalController?.offset ?? 0;
    var maxHorizontalOffset = widget.horizontalController?.maxOffset ?? 0;
    var verticalOffset = widget.verticalController?.offset ?? 0;
    var maxVerticalOffset = widget.verticalController?.maxOffset ?? 0;

    if (!(this.horizontalOffset == horizontalOffset &&
        this.maxHorizontalOffset == maxHorizontalOffset &&
        this.verticalOffset == verticalOffset &&
        this.maxVerticalOffset == maxVerticalOffset)) {
      this.horizontalOffset = horizontalOffset;
      this.maxHorizontalOffset = maxHorizontalOffset;
      this.verticalOffset = verticalOffset;
      this.maxVerticalOffset = maxVerticalOffset;

      markNeedsLayout();
    }

    super.widget = value;
  }

  @override
  void doLayout(Constraints constraints) {
    var childSize = child.layout(
      Constraints(
        widget.horizontalController != null ? 0 : constraints.minWidth,
        widget.verticalController != null ? 0 : constraints.minHeight,
        widget.horizontalController != null ? double.infinity : constraints.maxWidth,
        widget.verticalController != null ? double.infinity : constraints.maxHeight,
      ),
    );

    _updateMaxOffset(widget.horizontalController, max(0, childSize.width - constraints.maxWidth));
    _updateMaxOffset(widget.verticalController, max(0, childSize.height - constraints.maxHeight));

    child.transform.x = -horizontalOffset.roundToDouble();
    child.transform.y = -verticalOffset.roundToDouble();

    var selfSize = Size(
      widget.horizontalController != null
          ? constraints.hasBoundedWidth
                ? constraints.maxWidth
                : constraints.minWidth
          : childSize.width,
      widget.verticalController != null
          ? constraints.hasBoundedHeight
                ? constraints.maxHeight
                : constraints.minHeight
          : childSize.height,
    ).constrained(constraints);

    transform.setSize(selfSize);
  }

  /// Delay the actual invocation of scroll controller listeners until
  /// after the current layout cycle.
  ///
  /// This is important, because for one nobody could react to it anyways
  /// (since we are in the layout phase, the build phase for this frame
  /// is over) but *also* it actually breaks instances which descend from
  /// a layout builder. This happens because such a descendant would now
  /// mark itself dirty during the layout phase, but before the layout builder
  /// instance is marked clean. Thus, the `markNeedsLayout()` invocation on
  /// that layout builder instance gets swallowed and the widget is now stuck
  /// in improperly-rebuilt limbo until the layout builder happens to re-layout
  /// for other reasons. That is especially problematic because there is
  /// potential for this effect to mask legitimate rebuilds said descendant
  /// requires - it won't mark itself as needing a rebuild again because it
  /// is still dutifully waiting for such a rebuild to occur.
  void _updateMaxOffset(ScrollController? controller, double offset) {
    if (controller == null) return;

    if (controller._setMaxOffset(offset) && !controller._maxOffsetNotificationScheduled) {
      controller._maxOffsetNotificationScheduled = true;
      host!.schedulePostLayoutCallback(() => controller._sendMaxOffsetNotification());
    }
  }

  // we might actually want to put false assertions here and in [DragArena]
  // to point out to the user that measuring 'viewport-like' widgets in this
  // manner does not really make sense

  @override
  double measureIntrinsicWidth(double height) =>
      widget.horizontalController == null ? child.getIntrinsicWidth(height) : 0;

  @override
  double measureIntrinsicHeight(double width) =>
      widget.verticalController == null ? child.getIntrinsicHeight(width) : 0;

  @override
  double? measureBaselineOffset() {
    final childBaseline = child.getBaselineOffset();
    if (childBaseline == null) return null;

    return childBaseline + child.transform.y;
  }
}

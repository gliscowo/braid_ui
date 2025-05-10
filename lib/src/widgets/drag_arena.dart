import '../core/constraints.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import 'basic.dart';

class DragArenaElement extends VisitorWidget {
  final double x, y;
  const DragArenaElement({super.key, required this.x, required this.y, required super.child});

  static void _visitor(DragArenaElement widget, WidgetInstance instance) {
    if (instance.parentData case DragParentData data) {
      data.x = widget.x;
      data.y = widget.y;
    } else {
      instance.parentData = DragParentData(x: widget.x, y: widget.y);
    }

    instance.markNeedsLayout();
  }

  @override
  VisitorProxy<DragArenaElement> proxy() => VisitorProxy(this, _visitor);
}

class DragArena extends MultiChildInstanceWidget {
  const DragArena({super.key, required super.children});

  @override
  MultiChildWidgetInstance<DragArena> instantiate() => _DragArenaInstance(widget: this);
}

class DragParentData {
  double x, y;
  DragParentData({required this.x, required this.y});
}

class _DragArenaInstance extends MultiChildWidgetInstance<DragArena> {
  _DragArenaInstance({required super.widget});

  @override
  W adopt<W extends WidgetInstance?>(W child) {
    if (child?.parentData is! DragParentData) {
      child?.parentData = DragParentData(x: 0, y: 0);
    }

    return super.adopt<W>(child);
  }

  @override
  void doLayout(Constraints constraints) {
    for (final child in children) {
      child.layout(const Constraints.only());

      final parentData = child.parentData as DragParentData;
      child.transform.x = parentData.x;
      child.transform.y = parentData.y;
    }

    transform.setSize(constraints.maxSize);
  }

  @override
  double measureIntrinsicWidth(double height) => 0;

  @override
  double measureIntrinsicHeight(double width) => 0;
}

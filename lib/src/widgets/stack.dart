import 'dart:math';

import 'package:collection/collection.dart';

import '../../braid_ui.dart';

class StackBase extends VisitorWidget {
  const StackBase({super.key, required super.child});

  static void _visitor(StackBase widget, WidgetInstance instance) {
    if (instance.parentData is! _StackParentData) {
      instance.parentData = const _StackParentData();
      instance.markNeedsLayout();
    }
  }

  @override
  VisitorProxy proxy() => VisitorProxy<StackBase>(this, _visitor);
}

class Stack extends MultiChildInstanceWidget {
  final Alignment alignment;

  const Stack({super.key, this.alignment = Alignment.topLeft, required super.children});

  @override
  MultiChildWidgetInstance<Stack> instantiate() => _StackInstance(widget: this);
}

class _StackParentData {
  const _StackParentData();
}

class _StackInstance extends MultiChildWidgetInstance<Stack> {
  _StackInstance({required super.widget});

  @override
  set widget(Stack value) {
    if (widget.alignment == value.alignment) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final sizingBase = children.firstWhereOrNull((child) => child.parentData is _StackParentData);

    Size selfSize;
    if (sizingBase != null) {
      selfSize = sizingBase.layout(constraints);

      final childConstraints = Constraints.tight(selfSize).respecting(constraints);
      for (final child in children.where((child) => child != sizingBase)) {
        child.layout(childConstraints);
      }
    } else {
      selfSize = children.fold(Size.zero, (size, child) => size = Size.max(size, child.layout(constraints)));
    }

    for (final child in children) {
      final (childX, childY) = widget.alignment.align(selfSize, child.transform.toSize());
      child.transform.x = childX;
      child.transform.y = childY;
    }

    transform.setSize(selfSize);
  }

  @override
  double measureIntrinsicWidth(double height) => children.fold(
    0.0,
    (width, child) => max(child.measureIntrinsicWidth(height), child.measureIntrinsicWidth(height)),
  );

  @override
  double measureIntrinsicHeight(double width) => children.fold(
    0.0,
    (height, child) => max(child.measureIntrinsicHeight(width), child.measureIntrinsicHeight(width)),
  );

  @override
  double? measureBaselineOffset() => computeHighestBaselineOffset();
}

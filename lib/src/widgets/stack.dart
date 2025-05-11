import 'dart:math';

import '../../braid_ui.dart';

class Stack extends MultiChildInstanceWidget {
  final Alignment alignment;

  const Stack({super.key, this.alignment = Alignment.topLeft, required super.children});

  @override
  MultiChildWidgetInstance<Stack> instantiate() => _StackInstance(widget: this);
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
    final maxSize = children.fold(Size.zero, (size, child) => size = Size.max(size, child.layout(constraints)));

    for (final child in children) {
      final (childX, childY) = widget.alignment.align(maxSize, child.transform.toSize());
      child.transform.x = childX;
      child.transform.y = childY;
    }

    transform.setSize(maxSize);
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

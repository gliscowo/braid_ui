import 'dart:math';

import '../context.dart';
import 'constraints.dart';
import 'math.dart';
import 'widget.dart';
import 'widget_base.dart';

/// A vertical array of widgets
class Column extends Flex {
  Column({
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    required super.children,
  }) : super(mainAxis: LayoutAxis.vertical);
}

/// A horizontal array of widgets
class Row extends Flex {
  Row({
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    required super.children,
  }) : super(mainAxis: LayoutAxis.horizontal);
}

// ---

enum LayoutAxis {
  horizontal,
  vertical;

  Size createSize(double extent, double crossExtent) => switch (this) {
        LayoutAxis.horizontal => Size(extent, crossExtent),
        LayoutAxis.vertical => Size(crossExtent, extent),
      };

  LayoutAxis get opposite =>
      switch (this) { LayoutAxis.horizontal => LayoutAxis.vertical, LayoutAxis.vertical => LayoutAxis.horizontal };
}

extension ConstraintsAxisOperations on Constraints {
  double minOnAxis(LayoutAxis axis) =>
      switch (axis) { LayoutAxis.horizontal => minWidth, LayoutAxis.vertical => minHeight };

  double maxOnAxis(LayoutAxis axis) =>
      switch (axis) { LayoutAxis.horizontal => maxWidth, LayoutAxis.vertical => maxHeight };
}

extension SizeAxisOperations on Size {
  double getAxisExtent(LayoutAxis axis) =>
      switch (axis) { LayoutAxis.horizontal => width, LayoutAxis.vertical => height };
}

extension TransformAxisOperations on WidgetTransform {
  double getAxisExtent(LayoutAxis axis) =>
      switch (axis) { LayoutAxis.horizontal => width, LayoutAxis.vertical => height };
  double getAxisCoordinate(LayoutAxis axis) => switch (axis) { LayoutAxis.horizontal => x, LayoutAxis.vertical => y };

  void setAxisExtent(LayoutAxis axis, double value) =>
      switch (axis) { LayoutAxis.horizontal => width = value, LayoutAxis.vertical => height = value };
  void setAxisCoordinate(LayoutAxis axis, double value) =>
      switch (axis) { LayoutAxis.horizontal => x = value, LayoutAxis.vertical => y = value };
}

extension on (double, double) {
  (double, double) floorToDouble() => ($1.floorToDouble(), $2.floorToDouble());
}

enum CrossAxisAlignment {
  start,
  end,
  center,
  stretch;

  double _computeChildOffset(double freeSpace) => switch (this) {
        CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.start => 0,
        CrossAxisAlignment.center => (freeSpace / 2).floorToDouble(),
        CrossAxisAlignment.end => freeSpace,
      };
}

enum MainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly;

  (double leading, double between) _distributeSpace(double freeSpace, int childCount) => (switch (this) {
        MainAxisAlignment.start => (0.0, 0.0),
        MainAxisAlignment.end => (freeSpace, 0.0),
        MainAxisAlignment.center => (freeSpace / 2, 0.0),
        MainAxisAlignment.spaceBetween => (0.0, freeSpace / (childCount - 1)),
        MainAxisAlignment.spaceAround => (freeSpace / childCount / 2, freeSpace / childCount),
        MainAxisAlignment.spaceEvenly => (freeSpace / (childCount + 1), freeSpace / (childCount + 1))
      })
          .floorToDouble();
}

class FlexChild extends SingleChildWidgetInstance with ShrinkWrapLayout {
  final double flexFactor;
  FlexChild({
    this.flexFactor = 1.0,
    required super.child,
  });
}

class Flex extends WidgetInstance with ChildRenderer, ChildListRenderer {
  @override
  final List<WidgetInstance> children;

  LayoutAxis _mainAxis;
  MainAxisAlignment _mainAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;

  Flex({
    required LayoutAxis mainAxis,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    required this.children,
  })  : _mainAxis = mainAxis,
        _crossAxisAlignment = crossAxisAlignment,
        _mainAxisAlignment = mainAxisAlignment {
    for (final child in children) {
      child.parent = this;
    }
  }

  // TODO: revisit whether available main axis space should always
  // saturate constraints for non-flex children

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final crossAxis = mainAxis.opposite;
    final crossAxisMinimum = _crossAxisAlignment == CrossAxisAlignment.stretch
        ? constraints.maxOnAxis(crossAxis)
        : constraints.minOnAxis(crossAxis);

    final childConstraints = Constraints(
      mainAxis == LayoutAxis.vertical ? crossAxisMinimum : 0,
      mainAxis == LayoutAxis.horizontal ? crossAxisMinimum : 0,
      mainAxis == LayoutAxis.vertical ? constraints.maxOnAxis(crossAxis) : double.infinity,
      mainAxis == LayoutAxis.horizontal ? constraints.maxOnAxis(crossAxis) : double.infinity,
    );

    // first, lay out all non-flex children and store their sizes
    final childSizes =
        children.where((element) => element is! FlexChild).map((e) => e.layout(ctx, childConstraints)).toList();

    // now, compute the remaining space on the main axis
    final remainingSpace =
        constraints.maxOnAxis(mainAxis) - childSizes.fold(0.0, (acc, size) => acc + size.getAxisExtent(mainAxis));

    // get the flex children and compute the total flex factor in order
    // to divvy up the remaining space properly later
    final flexChildren = children.whereType<FlexChild>();
    final totalFlexFactor = flexChildren.fold(0.0, (previousValue, element) => previousValue + element.flexFactor);

    // lay out all flex children with (for now) tight constraints
    // on the main axis according to their allotted space
    for (final child in flexChildren) {
      final space = remainingSpace * (child.flexFactor / totalFlexFactor);
      childSizes.add(child.layout(
        ctx,
        childConstraints.respecting(
          Constraints.tightOnAxis(
            horizontal: mainAxis == LayoutAxis.horizontal ? space : null,
            vertical: mainAxis == LayoutAxis.vertical ? space : null,
          ),
        ),
      ));
    }

    // compute and apply the final size of ourselves
    final size = childSizes
        .fold(
          Size.zero,
          (acc, size) => mainAxis.createSize(
            acc.getAxisExtent(mainAxis) + size.getAxisExtent(mainAxis),
            max(acc.getAxisExtent(crossAxis), size.getAxisExtent(crossAxis)),
          ),
        )
        .constrained(constraints);

    transform.setSize(size);

    // distribute remaining space on the main axis
    final (leadingSpace, betweenSpace) = _mainAxisAlignment._distributeSpace(
      size.getAxisExtent(mainAxis) - childSizes.fold(0, (acc, size) => acc + size.getAxisExtent(mainAxis)),
      childSizes.length,
    );

    // move children into position and apply cross-axis alignment
    var mainAxisOffset = leadingSpace;
    for (final child in children) {
      child.transform.setAxisCoordinate(
        mainAxis,
        mainAxisOffset,
      );

      child.transform.setAxisCoordinate(
        crossAxis,
        _crossAxisAlignment._computeChildOffset(
          size.getAxisExtent(crossAxis) - child.transform.getAxisExtent(crossAxis),
        ),
      );

      mainAxisOffset += child.transform.getAxisExtent(mainAxis) + betweenSpace;
    }
  }

  LayoutAxis get mainAxis => _mainAxis;
  set mainAxis(LayoutAxis value) {
    if (_mainAxis == value) return;

    _mainAxis = value;
    markNeedsLayout();
  }

  MainAxisAlignment get mainAxisAlignment => _mainAxisAlignment;
  set mainAxisAlignment(MainAxisAlignment value) {
    if (_mainAxisAlignment == value) return;

    _mainAxisAlignment = value;
    markNeedsLayout();
  }

  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment == value) return;

    _crossAxisAlignment = value;
    markNeedsLayout();
  }
}

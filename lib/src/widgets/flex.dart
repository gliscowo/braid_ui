import 'dart:math';

import 'package:collection/collection.dart';

import '../../braid_ui.dart';

/// A vertical array of widgets
class Column extends Flex {
  const Column({super.key, super.mainAxisAlignment, super.crossAxisAlignment, super.separator, required super.children})
    : super(mainAxis: LayoutAxis.vertical);
}

/// A horizontal array of widgets
class Row extends Flex {
  const Row({super.key, super.mainAxisAlignment, super.crossAxisAlignment, super.separator, required super.children})
    : super(mainAxis: LayoutAxis.horizontal);
}

class Flex extends MultiChildInstanceWidget {
  final LayoutAxis mainAxis;
  final Widget? separator;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const Flex({
    super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.separator,
    required this.mainAxis,
    required super.children,
  });

  @override
  FlexInstance instantiate() => FlexInstance(widget: this);

  @override
  List<Widget> get children {
    if (separator == null || super.children.isEmpty) {
      return super.children;
    }

    final children = List<Widget?>.filled(2 * super.children.length - 1, null);
    for (final (idx, child) in super.children.indexed.take(super.children.length - 1)) {
      children[idx * 2] = child;
      children[idx * 2 + 1] = separator;
    }

    children[children.length - 1] = super.children.last;

    return children.cast();
  }
}

// ---

enum LayoutAxis {
  horizontal,
  vertical;

  T choose<T>(T horizontal, T vertical) => switch (this) {
    LayoutAxis.horizontal => horizontal,
    LayoutAxis.vertical => vertical,
  };

  T chooseCompute<T>(T Function() horizontal, T Function() vertical) => switch (this) {
    LayoutAxis.horizontal => horizontal(),
    LayoutAxis.vertical => vertical(),
  };

  Size createSize(double extent, double crossExtent) => switch (this) {
    LayoutAxis.horizontal => Size(extent, crossExtent),
    LayoutAxis.vertical => Size(crossExtent, extent),
  };

  LayoutAxis get opposite => switch (this) {
    LayoutAxis.horizontal => LayoutAxis.vertical,
    LayoutAxis.vertical => LayoutAxis.horizontal,
  };
}

extension ConstraintsAxisOperations on Constraints {
  double minOnAxis(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => minWidth,
    LayoutAxis.vertical => minHeight,
  };

  double maxOnAxis(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => maxWidth,
    LayoutAxis.vertical => maxHeight,
  };
}

extension SizeAxisOperations on Size {
  double getAxisExtent(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => width,
    LayoutAxis.vertical => height,
  };
}

extension TransformAxisOperations on WidgetTransform {
  double getAxisExtent(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => width,
    LayoutAxis.vertical => height,
  };
  double getAxisCoordinate(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => x,
    LayoutAxis.vertical => y,
  };

  void setAxisExtent(LayoutAxis axis, double value) => switch (axis) {
    LayoutAxis.horizontal => width = value,
    LayoutAxis.vertical => height = value,
  };
  void setAxisCoordinate(LayoutAxis axis, double value) => switch (axis) {
    LayoutAxis.horizontal => x = value,
    LayoutAxis.vertical => y = value,
  };
}

extension on (double, double) {
  (double, double) floorToDouble() => ($1.floorToDouble(), $2.floorToDouble());
}

enum CrossAxisAlignment {
  start,
  end,
  center,
  stretch;

  double _computeChildOffset(double freeSpace) =>
      (switch (this) {
        CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.start => 0,
        CrossAxisAlignment.center => freeSpace / 2,
        CrossAxisAlignment.end => freeSpace,
      }).floorToDouble();
}

enum MainAxisAlignment {
  start,
  end,
  center,
  spaceBetween,
  spaceAround,
  spaceEvenly;

  (double leading, double between) _distributeSpace(double freeSpace, int childCount) =>
      (switch (this) {
        MainAxisAlignment.start => (0.0, 0.0),
        MainAxisAlignment.end => (freeSpace, 0.0),
        MainAxisAlignment.center => (freeSpace / 2, 0.0),
        MainAxisAlignment.spaceBetween => (0.0, freeSpace / (childCount - 1)),
        MainAxisAlignment.spaceAround => (freeSpace / childCount / 2, freeSpace / childCount),
        MainAxisAlignment.spaceEvenly => (freeSpace / (childCount + 1), freeSpace / (childCount + 1)),
      }).floorToDouble();
}

class FlexParentData {
  double flexFactor;
  FlexParentData(this.flexFactor);
}

class FlexInstance extends MultiChildWidgetInstance<Flex> {
  FlexInstance({required super.widget});

  @override
  set widget(Flex value) {
    if (widget.mainAxis == value.mainAxis &&
        widget.mainAxisAlignment == value.mainAxisAlignment &&
        widget.crossAxisAlignment == value.crossAxisAlignment) {
      return;
    }

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final mainAxis = widget.mainAxis;
    final crossAxis = mainAxis.opposite;

    final crossAxisMinimum =
        widget.crossAxisAlignment == CrossAxisAlignment.stretch
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
        children
            .where((element) => element.parentData is! FlexParentData)
            .map((e) => e.layout(childConstraints))
            .toList();

    // now, compute the remaining space on the main axis
    final remainingSpace = max(
      constraints.maxOnAxis(mainAxis) - childSizes.map((size) => size.getAxisExtent(mainAxis)).sum,
      0,
    );

    // get the flex children and compute the total flex factor in order
    // to divvy up the remaining space properly later
    final flexChildren = children.where((element) => element.parentData is FlexParentData);
    final totalFlexFactor = flexChildren.map((element) => (element.parentData as FlexParentData).flexFactor).sum;

    // lay out all flex children with (for now) tight constraints
    // on the main axis according to their allotted space
    for (final child in flexChildren) {
      final space = remainingSpace * ((child.parentData as FlexParentData).flexFactor / totalFlexFactor);
      childSizes.add(
        child.layout(
          childConstraints.respecting(
            Constraints.tightOnAxis(
              horizontal: mainAxis == LayoutAxis.horizontal ? space : null,
              vertical: mainAxis == LayoutAxis.vertical ? space : null,
            ),
          ),
        ),
      );
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
    final (leadingSpace, betweenSpace) = widget.mainAxisAlignment._distributeSpace(
      size.getAxisExtent(mainAxis) - childSizes.map((size) => size.getAxisExtent(mainAxis)).sum,
      childSizes.length,
    );

    // move children into position and apply cross-axis alignment
    var mainAxisOffset = leadingSpace;
    for (final child in children) {
      child.transform.setAxisCoordinate(mainAxis, mainAxisOffset);

      child.transform.setAxisCoordinate(
        crossAxis,
        widget.crossAxisAlignment._computeChildOffset(
          size.getAxisExtent(crossAxis) - child.transform.getAxisExtent(crossAxis),
        ),
      );

      mainAxisOffset += child.transform.getAxisExtent(mainAxis) + betweenSpace;
    }
  }

  @override
  double measureIntrinsicWidth(double height) =>
      widget.mainAxis == LayoutAxis.horizontal ? _measureMainAxis(height) : _measureCrossAxis(height);

  @override
  double measureIntrinsicHeight(double width) =>
      widget.mainAxis == LayoutAxis.vertical ? _measureMainAxis(width) : _measureCrossAxis(width);

  double _measureMainAxis(double crossExtent) {
    final horizontal = widget.mainAxis == LayoutAxis.horizontal;
    final nonFlexSize =
        children
            .where((element) => element.parentData is! FlexParentData)
            .map((e) => horizontal ? e.measureIntrinsicWidth(crossExtent) : e.measureIntrinsicHeight(crossExtent))
            .sum;

    var totalFlexFactor = 0.0;
    (WidgetInstance child, double size, double flexFactor)? largestFlexChild;
    for (final flexChild in children.where((element) => element.parentData is FlexParentData)) {
      totalFlexFactor += (flexChild.parentData as FlexParentData).flexFactor;

      final size =
          horizontal ? flexChild.measureIntrinsicWidth(crossExtent) : flexChild.measureIntrinsicHeight(crossExtent);
      if (size > (largestFlexChild?.$2 ?? 0)) {
        largestFlexChild = (flexChild, size, (flexChild.parentData as FlexParentData).flexFactor);
      }
    }

    final flexSize = largestFlexChild != null ? (totalFlexFactor / largestFlexChild.$3) * largestFlexChild.$2 : 0;

    return nonFlexSize + flexSize;
  }

  double _measureCrossAxis(double mainExtent) {
    final horizontal = widget.mainAxis == LayoutAxis.horizontal;

    var crossSize = 0.0;

    var nonFlexSize = 0.0;
    for (final child in children.where((element) => element.parentData is! FlexParentData)) {
      final childSize = horizontal ? child.measureIntrinsicHeight(mainExtent) : child.measureIntrinsicWidth(mainExtent);

      nonFlexSize += childSize;
      crossSize = max(crossSize, childSize);
    }

    final flexChildren = children.where((element) => element.parentData is FlexParentData);
    final totalFlexFactor = flexChildren.map((e) => (e.parentData as FlexParentData).flexFactor).sum;

    for (final child in flexChildren) {
      final childSpace =
          (mainExtent - nonFlexSize) * (totalFlexFactor / (child.parentData as FlexParentData).flexFactor);
      crossSize = max(
        crossSize,
        horizontal ? child.measureIntrinsicHeight(childSpace) : child.measureIntrinsicWidth(childSpace),
      );
    }

    return crossSize;
  }
}

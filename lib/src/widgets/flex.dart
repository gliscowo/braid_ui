import 'dart:math';

import 'package:collection/collection.dart';

import '../core/constraints.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';

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
    if (separator == null || super.children.length < 2) {
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

// TODO: move these somewhere else

extension ConstraintsAxisOperations on Constraints {
  double minOnAxis(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => minWidth,
    LayoutAxis.vertical => minHeight,
  };

  double maxOnAxis(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => maxWidth,
    LayoutAxis.vertical => maxHeight,
  };

  double maxFiniteOrMinOnAxis(LayoutAxis axis) => switch (axis) {
    LayoutAxis.horizontal => maxFiniteOrMinWidth,
    LayoutAxis.vertical => maxFiniteOrMinHeight,
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
  stretch,
  baseline;

  double _computeChildOffset(double freeSpace) => (switch (this) {
    CrossAxisAlignment.stretch => 0,
    CrossAxisAlignment.start => 0,
    CrossAxisAlignment.center => freeSpace / 2,
    CrossAxisAlignment.end => freeSpace,
    CrossAxisAlignment.baseline => 0,
  }).floorToDouble();
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

    final crossAxisMinimum = widget.crossAxisAlignment == CrossAxisAlignment.stretch
        ? constraints.maxOnAxis(crossAxis)
        : constraints.minOnAxis(crossAxis);

    final childConstraints = Constraints(
      mainAxis == LayoutAxis.vertical ? crossAxisMinimum : 0,
      mainAxis == LayoutAxis.horizontal ? crossAxisMinimum : 0,
      mainAxis == LayoutAxis.vertical ? constraints.maxOnAxis(crossAxis) : double.infinity,
      mainAxis == LayoutAxis.horizontal ? constraints.maxOnAxis(crossAxis) : double.infinity,
    );

    var maxAscent = 0.0;
    var maxDescent = 0.0;
    final isBaselineAligned =
        mainAxis == LayoutAxis.horizontal && widget.crossAxisAlignment == CrossAxisAlignment.baseline;

    Size layoutChild(WidgetInstance child, Constraints childConstraints) {
      final size = child.layout(childConstraints);

      if (isBaselineAligned) {
        final baseline = child.getBaselineOffset() ?? size.height;
        maxAscent = max(maxAscent, baseline);
        maxDescent = max(maxDescent, size.height - baseline);
      }

      return size;
    }

    // first, lay out all non-flex children and store their sizes
    final childSizes = children
        .where((element) => element.parentData is! FlexParentData)
        .map((e) => layoutChild(e, childConstraints))
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
    var accumulatedPartialSpace = 0.0;

    // lay out all flex children with tight constraints
    // on the main axis according to their allotted space
    for (final child in flexChildren) {
      var space = remainingSpace * ((child.parentData as FlexParentData).flexFactor / totalFlexFactor);

      accumulatedPartialSpace += space - space.floorToDouble();
      space = space.floorToDouble();

      if (accumulatedPartialSpace >= 1) {
        space += 1;
        accumulatedPartialSpace -= 1;
      }

      childSizes.add(
        layoutChild(
          child,
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
    var size = childSizes.fold(
      Size.zero,
      (acc, size) => mainAxis.createSize(
        acc.getAxisExtent(mainAxis) + size.getAxisExtent(mainAxis),
        max(acc.getAxisExtent(crossAxis), size.getAxisExtent(crossAxis)),
      ),
    );

    if (isBaselineAligned) {
      size = size.copy(height: (maxAscent + maxDescent).floorToDouble());
    }

    size = size.constrained(constraints);
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

      if (!isBaselineAligned) {
        child.transform.setAxisCoordinate(
          crossAxis,
          widget.crossAxisAlignment._computeChildOffset(
            size.getAxisExtent(crossAxis) - child.transform.getAxisExtent(crossAxis),
          ),
        );
      } else {
        child.transform.y = (maxAscent - (child.getBaselineOffset() ?? child.transform.height)).floorToDouble();
      }

      mainAxisOffset += child.transform.getAxisExtent(mainAxis) + betweenSpace;
    }
  }

  @override
  double measureIntrinsicWidth(double height) =>
      widget.mainAxis == LayoutAxis.horizontal ? _measureMainAxis(height) : _measureCrossAxis(height);

  @override
  double measureIntrinsicHeight(double width) =>
      widget.mainAxis == LayoutAxis.vertical ? _measureMainAxis(width) : _measureCrossAxis(width);

  @override
  double? measureBaselineOffset() {
    switch (widget.mainAxis) {
      case LayoutAxis.vertical:
        return computeFirstBaselineOffset();
      case LayoutAxis.horizontal:
        return computeHighestBaselineOffset();
    }
  }

  double _measureMainAxis(double crossExtent) {
    final horizontal = widget.mainAxis == LayoutAxis.horizontal;
    final nonFlexSize = children
        .where((element) => element.parentData is! FlexParentData)
        .map((e) => horizontal ? e.getIntrinsicWidth(crossExtent) : e.getIntrinsicHeight(crossExtent))
        .sum;

    var totalFlexFactor = 0.0;
    ({WidgetInstance child, double size, double flexFactor})? largestFlexChild;

    for (final flexChild in children.where((element) => element.parentData is FlexParentData)) {
      totalFlexFactor += (flexChild.parentData as FlexParentData).flexFactor;

      final size = horizontal ? flexChild.getIntrinsicWidth(crossExtent) : flexChild.getIntrinsicHeight(crossExtent);
      if (size > (largestFlexChild?.size ?? 0)) {
        largestFlexChild = (
          child: flexChild,
          size: size,
          flexFactor: (flexChild.parentData as FlexParentData).flexFactor,
        );
      }
    }

    final flexSize = largestFlexChild != null
        ? (totalFlexFactor / largestFlexChild.flexFactor) * largestFlexChild.size
        : 0;

    return nonFlexSize + flexSize;
  }

  double _measureCrossAxis(double mainExtent) {
    final horizontal = widget.mainAxis == LayoutAxis.horizontal;

    var crossSize = 0.0;

    var nonFlexSize = 0.0;
    for (final child in children.where((element) => element.parentData is! FlexParentData)) {
      final childSize = horizontal ? child.getIntrinsicHeight(mainExtent) : child.getIntrinsicWidth(mainExtent);

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
        horizontal ? child.getIntrinsicHeight(childSpace) : child.getIntrinsicWidth(childSpace),
      );
    }

    return crossSize;
  }
}

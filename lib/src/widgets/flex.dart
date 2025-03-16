import 'dart:collection';
import 'dart:math';

import '../../braid_ui.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';

/// A vertical array of widgets
class Column extends Flex {
  const Column({
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    required super.children,
  }) : super(mainAxis: LayoutAxis.vertical);
}

/// A horizontal array of widgets
class Row extends Flex {
  const Row({
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

class FlexParentData {
  double flexFactor;
  FlexParentData(this.flexFactor);
}

class FlexInstance extends WidgetInstance<Flex> with ChildRenderer<Flex>, ChildListRenderer<Flex> {
  List<WidgetInstance> _children = [];

  FlexInstance({
    required super.widget,
  });

  // TODO: revisit whether available main axis space should always
  // saturate constraints for non-flex children

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {
    for (final child in _children) {
      visitor(child);
    }
  }

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

    // first, lay out all non-flex children and store their sizes
    final childSizes = _children
        .where((element) => element.parentData is! FlexParentData)
        .map((e) => e.layout(childConstraints))
        .toList();

    // now, compute the remaining space on the main axis
    final remainingSpace =
        constraints.maxOnAxis(mainAxis) - childSizes.fold(0.0, (acc, size) => acc + size.getAxisExtent(mainAxis));

    // get the flex children and compute the total flex factor in order
    // to divvy up the remaining space properly later
    final flexChildren = _children.where((element) => element.parentData is FlexParentData);
    final totalFlexFactor = flexChildren.fold(
        0.0, (previousValue, element) => previousValue + (element.parentData as FlexParentData).flexFactor);

    // lay out all flex children with (for now) tight constraints
    // on the main axis according to their allotted space
    for (final child in flexChildren) {
      final space = remainingSpace * ((child.parentData as FlexParentData).flexFactor / totalFlexFactor);
      childSizes.add(child.layout(
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
    final (leadingSpace, betweenSpace) = widget.mainAxisAlignment._distributeSpace(
      size.getAxisExtent(mainAxis) - childSizes.fold(0, (acc, size) => acc + size.getAxisExtent(mainAxis)),
      childSizes.length,
    );

    // move children into position and apply cross-axis alignment
    var mainAxisOffset = leadingSpace;
    for (final child in _children) {
      child.transform.setAxisCoordinate(
        mainAxis,
        mainAxisOffset,
      );

      child.transform.setAxisCoordinate(
        crossAxis,
        widget.crossAxisAlignment._computeChildOffset(
          size.getAxisExtent(crossAxis) - child.transform.getAxisExtent(crossAxis),
        ),
      );

      mainAxisOffset += child.transform.getAxisExtent(mainAxis) + betweenSpace;
    }
  }
}

// ---

class Flex extends InstanceWidget {
  final LayoutAxis mainAxis;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  const Flex({
    super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    required this.mainAxis,
    required this.children,
  });

  @override
  WidgetProxy proxy() => FlexProxy(this);

  @override
  WidgetInstance instantiate() => FlexInstance(widget: this);
}

class FlexProxy extends InstanceWidgetProxy {
  List<WidgetProxy> _children = [];

  FlexProxy(super.widget);

  @override
  FlexInstance get instance => (super.instance as FlexInstance);

  @override
  void visitChildren(WidgetProxyVisitor visitor) {
    for (final child in _children) {
      visitor(child);
    }
  }

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    rebuild();
  }

  @override
  void updateWidget(Flex newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    instance.widget = widget as Flex;
    final newWidgets = (widget as Flex).children;

    var newChildrenTop = 0;
    var oldChildrenTop = 0;
    var newChildrenBottom = newWidgets.length - 1;
    var oldChildrenBottom = _children.length - 1;

    final newChildren = List<WidgetProxy?>.filled(newWidgets.length, null);

    // sync from the top
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = _children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      if (!Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget);
      oldChildrenTop++;
      newChildrenTop++;
    }

    // scan from the bottom
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = _children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      if (!Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }

      oldChildrenTop++;
      newChildrenTop++;
    }

    // scan middle, store keyed and disposed un-keyed

    final hasOldChildren = oldChildrenTop <= oldChildrenBottom;
    Map<Key, WidgetProxy>? keyedOldChildren;

    if (hasOldChildren) {
      keyedOldChildren = HashMap();
      while (oldChildrenTop <= oldChildrenBottom) {
        final oldChild = _children[oldChildrenTop];
        final key = oldChild.widget.key;

        if (key != null) {
          keyedOldChildren[key!] = oldChild;
        } else {
          oldChild.unmount();
        }

        oldChildrenTop++;
      }
    }

    // sync middle, updating keyed

    while (newChildrenTop <= newChildrenBottom) {
      WidgetProxy? oldChild;
      final newWidget = newWidgets[newChildrenTop];

      if (hasOldChildren) {
        final key = newWidget.key;
        if (key != null) {
          oldChild = keyedOldChildren![key];
          if (oldChild != null) {
            if (Widget.canUpdate(oldChild.widget, newWidget)) {
              keyedOldChildren.remove(key);
            } else {
              oldChild = null;
            }
          }
        }
      }

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget);
      newChildrenTop++;
    }

    newChildrenBottom = newWidgets.length - 1;
    oldChildrenBottom = _children.length - 1;

    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = _children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget);
      oldChildrenTop++;
      newChildrenTop++;
    }

    // dispose keyed proxies that were not reused
    if (hasOldChildren && keyedOldChildren!.isNotEmpty) {
      for (final proxy in keyedOldChildren.values) {
        proxy.unmount();
      }
    }

    // finally, install new children and instances
    _children = newChildren.cast();

    final newInstances = List<WidgetInstance?>.filled(newChildren.length, null);
    instance._children = newInstances.cast();
    for (final (idx, newChild) in newChildren.indexed) {
      newChild!.instanceCallback = (childInstance) => newInstances[idx] = instance.adopt(childInstance);
    }

    super.doRebuild();
  }
}

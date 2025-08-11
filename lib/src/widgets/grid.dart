import 'dart:math';

import 'package:collection/collection.dart';

import '../core/constraints.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'flex.dart';

sealed class CellFit {
  const CellFit._();

  const factory CellFit.tight() = _TightCellFit;
  const factory CellFit.loose({Alignment alignment}) = _LooseCellFit;

  bool get isTight;
}

final class _LooseCellFit extends CellFit {
  final Alignment alignment;
  const _LooseCellFit({this.alignment = Alignment.center}) : super._();

  @override
  bool get isTight => false;

  @override
  int get hashCode => alignment.hashCode;

  @override
  bool operator ==(Object other) => other is _LooseCellFit && other.alignment == alignment;
}

final class _TightCellFit extends CellFit {
  const _TightCellFit() : super._();

  @override
  bool get isTight => true;

  @override
  int get hashCode => 17;

  @override
  bool operator ==(Object other) => other is _TightCellFit;
}

class Grid extends MultiChildInstanceWidget {
  final LayoutAxis mainAxis;
  final int crossAxisCells;
  final CellFit cellFit;

  const Grid({
    super.key,
    required this.mainAxis,
    required this.crossAxisCells,
    this.cellFit = const CellFit.loose(),
    required super.children,
  });

  @override
  MultiChildWidgetInstance<MultiChildInstanceWidget> instantiate() => _GridInstance(widget: this);
}

class _GridInstance extends MultiChildWidgetInstance<Grid> {
  _GridInstance({required super.widget});

  @override
  set widget(Grid value) {
    if (widget.mainAxis == value.mainAxis &&
        widget.crossAxisCells == value.crossAxisCells &&
        widget.cellFit == value.cellFit) {
      return;
    }

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final mainAxis = widget.mainAxis;
    final crossAxis = mainAxis.opposite;

    final crossAxisCells = widget.crossAxisCells;
    final mainAxisCells = (children.length / widget.crossAxisCells).ceil();

    final mustMeasureCrossAxis =
        widget.cellFit.isTight && !crossAxis.choose(constraints.hasTightWidth, constraints.hasTightHeight);
    final mustMeasureMainAxis =
        widget.cellFit.isTight && !mainAxis.choose(constraints.hasTightWidth, constraints.hasTightHeight);

    final fixedCrossAxisCellSize = constraints.maxOnAxis(crossAxis) / crossAxisCells;
    final fixedMainAxisCellSize = constraints.maxOnAxis(mainAxis) / mainAxisCells;

    List<double>? dynamicCrossAxisCellSizes;
    if (mustMeasureCrossAxis) {
      dynamicCrossAxisCellSizes = _measureCrossAxis(fixedMainAxisCellSize);
    }

    List<double>? dynamicMainAxisCellSizes;
    if (mustMeasureMainAxis) {
      dynamicMainAxisCellSizes = _measureMainAxis(fixedCrossAxisCellSize);
    }

    for (int mainAxisIdx = 0; mainAxisIdx < mainAxisCells; mainAxisIdx++) {
      final maxMainAxisChildSize = mustMeasureMainAxis ? dynamicMainAxisCellSizes![mainAxisIdx] : fixedMainAxisCellSize;

      final firstChildIdx = mainAxisIdx * widget.crossAxisCells;
      final lastChildIdx = min(children.length, firstChildIdx + widget.crossAxisCells) - 1;

      for (var childIdx = firstChildIdx; childIdx <= lastChildIdx; childIdx++) {
        final child = children[childIdx];

        final maxCrossAxisChildSize = mustMeasureCrossAxis
            ? dynamicCrossAxisCellSizes![childIdx % widget.crossAxisCells]
            : fixedCrossAxisCellSize;

        final maxWidth = mainAxis == LayoutAxis.vertical ? maxCrossAxisChildSize : maxMainAxisChildSize;
        final maxHeight = mainAxis == LayoutAxis.vertical ? maxMainAxisChildSize : maxCrossAxisChildSize;

        final childConstraints = widget.cellFit.isTight
            ? Constraints.tightOnAxis(horizontal: maxWidth, vertical: maxHeight)
            : Constraints.loose(Size(maxWidth, maxHeight));

        child.layout(childConstraints);
      }
    }

    final actualCrossAxisSizes = List.filled(crossAxisCells, 0.0, growable: false);
    final actualMainAxisSizes = List.filled(mainAxisCells, 0.0, growable: false);

    final minCrossAxisCellSize = constraints.minOnAxis(crossAxis) / crossAxisCells;
    final minMainAxisCellSize = constraints.minOnAxis(mainAxis) / mainAxisCells;

    for (final (childIdx, child) in children.indexed) {
      final mainAxisCell = childIdx ~/ crossAxisCells;
      final crossAxisCell = childIdx % crossAxisCells;

      actualCrossAxisSizes[crossAxisCell] = max(
        minCrossAxisCellSize,
        max(actualCrossAxisSizes[crossAxisCell], child.transform.getAxisExtent(crossAxis)),
      );
      actualMainAxisSizes[mainAxisCell] = max(
        minMainAxisCellSize,
        max(actualMainAxisSizes[mainAxisCell], child.transform.getAxisExtent(mainAxis)),
      );
    }

    final alignment = widget.cellFit is _LooseCellFit ? (widget.cellFit as _LooseCellFit).alignment : Alignment.topLeft;

    var mainAxisPos = 0.0;
    for (var mainAxisCell = 0; mainAxisCell < mainAxisCells; mainAxisCell++) {
      var crossAxisPos = 0.0;

      for (var crossAxisCell = 0; crossAxisCell < crossAxisCells; crossAxisCell++) {
        var childIdx = mainAxisCell * crossAxisCells + crossAxisCell;
        if (childIdx >= children.length) break;

        var child = children[childIdx];

        child.transform.setAxisCoordinate(
          crossAxis,
          crossAxisPos +
              alignment.alignHorizontal(actualCrossAxisSizes[crossAxisCell], child.transform.getAxisExtent(crossAxis)),
        );
        child.transform.setAxisCoordinate(
          mainAxis,
          mainAxisPos +
              alignment.alignVertical(actualMainAxisSizes[mainAxisCell], child.transform.getAxisExtent(mainAxis)),
        );

        crossAxisPos += actualCrossAxisSizes[crossAxisCell];
      }

      mainAxisPos += actualMainAxisSizes[mainAxisCell];
    }

    transform.setSize(
      mainAxis == LayoutAxis.vertical
          ? Size(actualCrossAxisSizes.sum, actualMainAxisSizes.sum)
          : Size(actualMainAxisSizes.sum, actualCrossAxisSizes.sum),
    );
  }

  @override
  double measureIntrinsicWidth(double height) => switch (widget.mainAxis) {
    LayoutAxis.vertical => _measureCrossAxis(height),
    LayoutAxis.horizontal => _measureMainAxis(height),
  }.sum;

  @override
  double measureIntrinsicHeight(double width) => switch (widget.mainAxis) {
    LayoutAxis.vertical => _measureMainAxis(width),
    LayoutAxis.horizontal => _measureCrossAxis(width),
  }.sum;

  List<double> _measureCrossAxis(double mainAxisCellSize) {
    final crossAxisCells = widget.crossAxisCells;
    final measureFunction = widget.mainAxis.opposite.chooseCompute(
      () =>
          (WidgetInstance child) => child.getIntrinsicWidth(mainAxisCellSize),
      () =>
          (WidgetInstance child) => child.getIntrinsicHeight(mainAxisCellSize),
    );

    final intrinsics = children.map(measureFunction).toList(growable: false);

    final sizes = List.filled(crossAxisCells, 0.0, growable: false);
    for (var cell = 0; cell < crossAxisCells; cell++) {
      var cellSize = 0.0;

      for (var childIdx = cell; childIdx < children.length; childIdx += crossAxisCells) {
        cellSize = max(cellSize, intrinsics[childIdx]);
      }

      sizes[cell] = cellSize;
    }

    return sizes;
  }

  List<double> _measureMainAxis(double crossAxisCellSize) {
    final crossAxisCells = widget.crossAxisCells;
    final mainAxisCells = (children.length / widget.crossAxisCells).ceil();

    final measureFunction = widget.mainAxis.chooseCompute(
      () =>
          (WidgetInstance child) => child.getIntrinsicWidth(crossAxisCellSize),
      () =>
          (WidgetInstance child) => child.getIntrinsicHeight(crossAxisCellSize),
    );

    var intrinsics = children.map(measureFunction).toList(growable: false);

    var sizes = List.filled(mainAxisCells, 0.0, growable: false);
    for (var cell = 0; cell < mainAxisCells; cell++) {
      var cellSize = 0.0;

      final firstChild = cell * crossAxisCells;
      final lastChild = firstChild + (crossAxisCells - 1);

      for (var childIdx = firstChild; childIdx <= lastChild; childIdx++) {
        if (childIdx >= children.length) break;
        cellSize = max(cellSize, intrinsics[childIdx]);
      }

      sizes[cell] = cellSize;
    }

    return sizes;
  }

  @override
  double? measureBaselineOffset() => computeHighestBaselineOffset();
}

import 'dart:collection';
import 'dart:io';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../core/cursors.dart';
import '../core/key_modifiers.dart';
import '../core/math.dart';
import '../events_binding.dart';
import '../surface.dart';
import '../text/text_renderer.dart';
import '../widgets/basic.dart';
import '../widgets/image.dart';
import 'proxy.dart';
import 'widget.dart';

class WidgetTransform {
  Matrix4? _toParent;
  Matrix4? _toWidget;
  Aabb3? _aabb;

  double _x = 0, _y = 0;
  double _width = 0, _height = 0;

  set x(double value) => _setState(() => _x = value);
  set y(double value) => _setState(() => _y = value);
  set width(double value) => _setState(() => _width = value);
  set height(double value) => _setState(() => _height = value);

  void setSize(Size size) => _setState(() {
    _width = size.width;
    _height = size.height;
  });

  Size toSize() => Size(width, height);

  double get x => _x;
  double get y => _y;
  double get width => _width;
  double get height => _height;

  Matrix4 get toParent => _toParent ??= Matrix4.identity()..setTranslationRaw(_x, _y, 0);
  Matrix4 get toWidget => _toWidget ??= Matrix4.inverted(toParent);
  Aabb3 get aabb => _aabb ??= Aabb3.minMax(Vector3.zero(), Vector3(_width, _height, 0))..transform(toParent);

  void transformToParent(Matrix4 mat) => mat.translate(_x, _y, 0);
  void transformToWidget(Matrix4 mat) => mat.translate(-_x, -_y, 0);

  void toParentCoordinates(Vector3 vec) => vec.add(Vector3(_x, _y, 0));
  void toWidgetCoordinates(Vector3 vec) => vec.sub(Vector3(_x, _y, 0));

  void _setState(void Function() action) {
    action();
    recompute();
  }

  void recompute() {
    _toParent = null;
    _toWidget = null;
    _aabb = null;
  }
}

class CustomWidgetTransform extends WidgetTransform {
  bool _applyAtCenter = true;
  Matrix4 _matrix = Matrix4.identity();

  set matrix(Matrix4 value) => _setState(() => _matrix = value);
  Matrix4 get matrix => _matrix;

  set applyAtCenter(bool value) => _setState(() => _applyAtCenter = value);
  bool get applyAtCenter => _applyAtCenter;

  @override
  Matrix4 get toParent => _toParent ??= _applyAtCenter
      ? (Matrix4.identity()
          ..setTranslationRaw(_x + _width / 2, _y + _height / 2, 0)
          ..multiply(_matrix)
          ..translate(-_width / 2, -_height / 2))
      : Matrix4.copy(matrix);

  @override
  void transformToParent(Matrix4 mat) => mat.multiply(toParent);

  @override
  void transformToWidget(Matrix4 mat) => mat.multiply(toWidget);

  @override
  void toParentCoordinates(Vector3 vec) => toParent.transform3(vec);

  @override
  void toWidgetCoordinates(Vector3 vec) => toWidget.transform3(vec);
}

typedef Hit = ({WidgetInstance instance, ({double x, double y}) coordinates});

class HitTestState {
  final _hits = DoubleLinkedQueue<Hit>();

  bool get anyHit => _hits.isNotEmpty;
  Hit get firstHit => _hits.first;

  Iterable<Hit> get trace => _hits;
  Iterable<Hit> get occludedTrace sync* {
    for (final hit in _hits) {
      yield hit;

      if (hit.instance.flags & InstanceFlags.hitTestBoundary) {
        return;
      }
    }
  }

  Hit? firstWhere(bool Function(Hit hit) predicate) =>
      occludedTrace.cast<Hit?>().firstWhere((element) => predicate(element!), orElse: () => null);

  void addHit(WidgetInstance instance, double x, double y) {
    _hits.addFirst((instance: instance, coordinates: (x: x, y: y)));
  }

  @override
  String toString() => 'HitTestState [${_hits.map((e) => e.instance.runtimeType).join(', ')}]';
}

mixin MouseListener<T extends InstanceWidget> on WidgetInstance<T> {
  CursorStyle? cursorStyleAt(double x, double y) => null;

  bool onMouseDown(double x, double y, int button) => false;
  bool onMouseUp(double x, double y, int button) => false;
  void onMouseEnter() {}
  void onMouseMove(double toX, double toY) {}
  void onMouseExit() {}
  void onMouseDragStart(int button) {}
  void onMouseDrag(double x, double y, double dx, double dy) {}
  void onMouseDragEnd() {}
  bool onMouseScroll(double x, double y, double horizontal, double vertical) => false;

  @internal
  ({double x, double y})? lastMousePosition;
}

mixin KeyboardListener<T extends InstanceWidget> on WidgetInstance<T> {
  bool onKeyDown(int keyCode, KeyModifiers modifiers) => false;
  bool onKeyUp(int keyCode, KeyModifiers modifiers) => false;
  bool onChar(int charCode, KeyModifiers modifiers) => false;

  void onFocusGained() {}
  void onFocusLost() {}

  bool _requestFocusWhenHostAttached = false;
  void requestFocus() {
    if (_host case var host?) {
      host.moveFocusTo(this);
    } else {
      _requestFocusWhenHostAttached = true;
    }
  }

  @override
  void attachHost(InstanceHost host) {
    super.attachHost(host);

    if (_requestFocusWhenHostAttached) {
      _requestFocusWhenHostAttached = false;

      host.moveFocusTo(this);
    }
  }
}

extension type const InstanceFlags._(int _value) {
  static const none = InstanceFlags._(0);
  static const hitTestBoundary = InstanceFlags._(1);

  InstanceFlags operator +(InstanceFlags other) => InstanceFlags._(_value | other._value);
  InstanceFlags operator -(InstanceFlags other) => InstanceFlags._(_value & ~other._value);

  bool operator &(InstanceFlags other) => (_value & other._value) != 0;
}

abstract interface class InstanceHost {
  Surface get surface;
  EventsBinding get eventsBinding;

  TextRenderer get textRenderer;
  ImageCache get imageCache;

  /// Schedule a [WidgetInstance.layout] invocation for [instance],
  /// to be executed during the next layout pass.
  ///
  /// This function must generally not be called during a layout pass
  /// unless [notifySubtreeRebuild] has been invoked first since
  /// otherwise we run the risk of laying out some instances twice
  void scheduleLayout(WidgetInstance instance);

  /// Notify the layout scheduler that a widget or proxy subtree
  /// of the current element is (likely) about to rebuild and
  /// subsequently [scheduleLayout] may be invoked during the
  /// current layout pass
  ///
  /// This is used to implement the [LayoutBuilder] mechanism
  void notifySubtreeRebuild();

  /// Request that focus be moved to [focusTarget]. Given that
  /// the host allows the operation, it will generally be
  /// executed immediately and the listener is ready to receive
  /// input events from the next frame onwards
  void moveFocusTo(KeyboardListener focusTarget) {}

  void schedulePostLayoutCallback(Callback callback);
}

typedef WidgetInstanceVisitor = void Function(WidgetInstance child);

abstract class WidgetInstance<T extends InstanceWidget> with NodeWithDepth implements Comparable<WidgetInstance> {
  WidgetInstance({required this.widget});

  // ---

  late final WidgetTransform transform = createTransform();

  Object? parentData;
  InstanceFlags flags = InstanceFlags.none;

  InstanceHost? _host;
  InstanceHost? get host => _host;

  WidgetInstance? _parent;
  WidgetInstance? get parent => _parent;

  T widget;

  // ---

  bool debugHighlighted = false;

  // ---

  Constraints? _constraints;
  Constraints? get constraints => _constraints;

  bool _needsLayout = false;
  bool get needsLayout => _needsLayout;

  WidgetInstance? _relayoutBoundary;
  bool get isRelayoutBoundary => _relayoutBoundary == this;

  @nonVirtual
  Size layout(Constraints constraints) {
    if (!_needsLayout && constraints == _constraints) {
      return transform.toSize();
    }

    _constraints = constraints;
    _relayoutBoundary = constraints.isTight || _parent == null ? this : _parent!._relayoutBoundary!;

    doLayout(constraints);
    _needsLayout = false;

    return transform.toSize();
  }

  void doLayout(Constraints constraints);

  @protected
  double measureIntrinsicWidth(double height);
  @protected
  double measureIntrinsicHeight(double width);

  final Map<(LayoutAxis, double), double> _intrinsicSizeCache = HashMap();
  double getIntrinsicWidth(double height) =>
      _intrinsicSizeCache[(LayoutAxis.horizontal, height)] ??= measureIntrinsicWidth(height);
  double getIntrinsicHeight(double width) =>
      _intrinsicSizeCache[(LayoutAxis.vertical, width)] ??= measureIntrinsicHeight(width);

  @protected
  double? measureBaselineOffset();

  (double?,)? _baselineOffsetCache;
  double? getBaselineOffset() => (_baselineOffsetCache ??= (measureBaselineOffset(),)).$1;

  // ---

  void draw(DrawContext ctx);

  // ---

  void attachHost(InstanceHost host) {
    _host = host;
    visitChildren((child) => child.attachHost(host));
  }

  @protected
  W adopt<W extends WidgetInstance?>(W child) {
    if (child == null || child._parent == this) return child;

    child.depth = depth + 1;
    child._parent = this;
    if (host != null) {
      child.attachHost(host!);
    }

    return child;
  }

  // ---

  static void _clearChildLayoutCache(WidgetInstance child) => child.clearLayoutCache();
  void clearLayoutCache({bool recursive = true}) {
    _needsLayout = true;

    if (recursive) {
      visitChildren(_clearChildLayoutCache);
    }
  }

  @mustCallSuper
  void markNeedsLayout() {
    _needsLayout = true;
    _intrinsicSizeCache.clear();
    _baselineOffsetCache = null;

    if (isRelayoutBoundary) {
      host?.scheduleLayout(this);
    } else {
      _parent?.markNeedsLayout();
    }
  }

  bool _debugDisposed = false;

  @mustCallSuper
  void dispose() {
    assert(!_debugDisposed, 'tried to dispose a widget instance twice');
    _debugDisposed = true;
  }

  @protected
  WidgetTransform createTransform() => WidgetTransform();

  @override
  void visitChildren(WidgetInstanceVisitor visitor);

  /// Gather the ancestors of this instance (excluding the
  /// instance itself), ordered from immediate parent to root
  Iterable<WidgetInstance> get ancestors sync* {
    var ancestor = _parent;
    while (ancestor != null) {
      yield ancestor;
      ancestor = ancestor._parent;
    }
  }

  void hitTest(double x, double y, HitTestState state) {
    if (hitTestSelf(x, y)) state.addHit(this, x, y);

    final coordinates = Vector3.zero();
    visitChildren((child) {
      coordinates.setValues(x, y, 0);
      child.transform.toWidgetCoordinates(coordinates);

      child.hitTest(coordinates.x, coordinates.y, state);
    });
  }

  /// Compute the complete transform from [ancestor] to this
  /// instance. If [ancestor] is null, compute the transform
  /// from the root of the tree
  Matrix4 computeTransformFrom({required WidgetInstance? ancestor}) {
    final result = Matrix4.identity();

    result.multiply(transform.toWidget);

    for (final step in ancestors.takeWhile((value) => value != ancestor)) {
      result.multiply(step.transform.toWidget);
    }

    return result;
  }

  @protected
  bool hitTestSelf(double x, double y) => x >= 0 && x <= transform.width && y >= 0 && y <= transform.height;

  bool get hasParent => _parent != null;

  // ---

  @override
  int compareTo(WidgetInstance<InstanceWidget> other) => NodeWithDepth.compare(this, other);

  @override
  String toString() => '${isRelayoutBoundary ? 'BOUNDARY@' : ''}$runtimeType@${hashCode.toRadixString(16)}';
}

// --- rendering/layout mixins

mixin SingleChildProvider<T extends InstanceWidget> on WidgetInstance<T> {
  WidgetInstance get child;

  @override
  void visitChildren(WidgetInstanceVisitor visitor) => visitor(child);
}

mixin OptionalChildProvider<T extends InstanceWidget> on WidgetInstance<T> {
  WidgetInstance? get child;

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {
    if (child != null) {
      visitor(child!);
    }
  }
}

mixin ChildRenderer<T extends InstanceWidget> on WidgetInstance<T> {
  @protected
  void drawChild(DrawContext ctx, WidgetInstance child) {
    ctx.transform.scopedTransform(child.transform.transformToParent, (mat4) {
      child.draw(ctx);

      if (child.debugHighlighted) {
        ctx.primitives.rect(
          child.transform.width,
          child.transform.height,
          Color.rgb(0xFFD63A).copyWith(a: .5),
          ctx.transform,
          ctx.projection,
        );
      }
    });

    if (ctx.drawBoundingBoxes) {
      final aabb = child.transform.aabb;
      ctx.transform.scope((mat4) {
        mat4.translate(aabb.min.x, aabb.min.y, 0);
        ctx.primitives.roundedRect(
          aabb.max.x - aabb.min.x,
          aabb.max.y - aabb.min.y,
          const CornerRadius.all(2),
          Color.black,
          mat4,
          ctx.projection,
          outlineThickness: 1,
        );
      });
    }
  }
}

mixin SingleChildRenderer<T extends InstanceWidget> on ChildRenderer<T>, SingleChildProvider<T> {
  @override
  void draw(DrawContext ctx) {
    drawChild(ctx, child);
  }
}

mixin OptionalChildRenderer<T extends InstanceWidget> on ChildRenderer<T>, OptionalChildProvider<T> {
  @override
  void draw(DrawContext ctx) {
    if (child case var child?) {
      drawChild(ctx, child);
    }
  }
}

mixin ChildListRenderer<T extends InstanceWidget> on ChildRenderer<T> {
  @override
  void draw(DrawContext ctx) {
    visitChildren((child) => drawChild(ctx, child));
  }
}

mixin ShrinkWrapLayout<T extends InstanceWidget> on WidgetInstance<T>, SingleChildProvider<T> {
  @override
  void doLayout(Constraints constraints) {
    final size = child.layout(constraints);
    transform.setSize(size);
  }

  @override
  double measureIntrinsicWidth(double height) => child.getIntrinsicWidth(height);

  @override
  double measureIntrinsicHeight(double width) => child.getIntrinsicHeight(width);

  @override
  double? measureBaselineOffset() => child.getBaselineOffset();
}

mixin OptionalShrinkWrapLayout<T extends InstanceWidget> on WidgetInstance<T>, OptionalChildProvider<T> {
  @override
  void doLayout(Constraints constraints) {
    final size = child?.layout(constraints) ?? constraints.minSize;
    transform.setSize(size);
  }

  @override
  double measureIntrinsicWidth(double height) => child?.measureIntrinsicWidth(height) ?? 0;

  @override
  double measureIntrinsicHeight(double width) => child?.measureIntrinsicHeight(width) ?? 0;

  @override
  double? measureBaselineOffset() => child?.measureBaselineOffset();
}

// --- template classes

abstract class SingleChildWidgetInstance<T extends InstanceWidget> extends WidgetInstance<T>
    with SingleChildProvider, ChildRenderer, SingleChildRenderer {
  WidgetInstance? _child;

  SingleChildWidgetInstance({required super.widget});

  @override
  WidgetInstance get child {
    assert(_child != null, 'tried to retrieve child of SingleChildWidgetInstance before it was set');
    return _child!;
  }

  set child(WidgetInstance value) {
    if (value == _child) return;

    _child = adopt(value);
    markNeedsLayout();
  }
}

abstract class OptionalChildWidgetInstance<T extends InstanceWidget> extends WidgetInstance<T>
    with OptionalChildProvider, ChildRenderer, OptionalChildRenderer {
  WidgetInstance? _child;

  OptionalChildWidgetInstance({required super.widget});

  @override
  WidgetInstance? get child => _child;
  set child(WidgetInstance? value) {
    if (value == _child) return;

    _child = adopt(value);
    markNeedsLayout();
  }
}

abstract class MultiChildWidgetInstance<T extends MultiChildInstanceWidget> extends WidgetInstance<T>
    with ChildRenderer, ChildListRenderer {
  List<WidgetInstance> children = [];

  MultiChildWidgetInstance({required super.widget});

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {
    for (final child in children) {
      visitor(child);
    }
  }

  void insertChild(int index, WidgetInstance child) {
    children[index] = adopt(child);
    markNeedsLayout();
  }

  @protected
  double? computeFirstBaselineOffset() {
    for (final child in children) {
      final childBaseline = child.getBaselineOffset();
      if (childBaseline == null) continue;

      return childBaseline + child.transform.y;
    }

    return null;
  }

  @protected
  double? computeHighestBaselineOffset() {
    double? baselineMin(double? a, double? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a <= b ? a : b;
    }

    return children.fold(null, (acc, child) {
      final childBaseline = child.getBaselineOffset();
      if (childBaseline == null) return acc;

      return baselineMin(acc, childBaseline + child.transform.y);
    });
  }
}

abstract class LeafWidgetInstance<T extends InstanceWidget> extends WidgetInstance<T> {
  LeafWidgetInstance({required super.widget});

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {}
}

// --- instance tree debugging

void dumpInstancesGraphviz(WidgetInstance widget, [IOSink? out]) {
  out ??= stdout;

  if (widget._parent != null) {
    out.writeln('  ${_formatWidget(widget._parent!)} -> ${_formatWidget(widget)};');
  }
  widget.visitChildren((child) {
    dumpInstancesGraphviz(child, out);
  });
}

String _formatWidget(WidgetInstance widget) {
  return '"${widget.runtimeType}\\n${widget.hashCode.toRadixString(16)}\\n${widget.transform.x}, ${widget.transform.y}"';
}

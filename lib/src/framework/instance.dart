import 'dart:collection';
import 'dart:io';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../../braid_ui.dart';
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
  Matrix4 _matrix = Matrix4.identity();

  set matrix(Matrix4 value) => _setState(() => _matrix = value);
  Matrix4 get matrix => _matrix;

  @override
  Matrix4 get toParent => _toParent ??= Matrix4.identity()
    ..setTranslationRaw(_x + _width / 2, _y + _height / 2, 0)
    ..multiply(_matrix)
    ..translate(-_width / 2, -_height / 2);

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
  final _hitWidgets = DoubleLinkedQueue<Hit>();

  bool get anyHit => _hitWidgets.isNotEmpty;
  Hit get firstHit => _hitWidgets.first;

  Iterable<Hit> get trace => _hitWidgets;
  Iterable<Hit> get occludedTrace =>
      trace.takeWhile((value) => !(value.instance.flags & InstanceFlags.hitTestBoundary));

  Hit? firstWhere(bool Function(WidgetInstance instance) predicate) => occludedTrace.cast<Hit?>().firstWhere(
        (element) => predicate(element!.instance),
        orElse: () => null,
      );

  void addHit(WidgetInstance instance, double x, double y) {
    _hitWidgets.addFirst((instance: instance, coordinates: (x: x, y: y)));
  }

  @override
  String toString() => 'HitTestState [${_hitWidgets.map((e) => e.instance.runtimeType).join(', ')}]';
}

mixin MouseListener {
  bool onMouseDown() => false;
  void onMouseEnter() {}
  void onMouseExit() {}
  bool onMouseScroll(double horizontal, double vertical) => false;
}

mixin KeyboardListener {
  void onKeyDown(int keyCode, int modifiers);
  void onKeyUp(int keyCode, int modifiers);
  void onChar(int charCode, int modifiers);

  void onFocusGained();
  void onFocusLost();
}

extension type const InstanceFlags._(int _value) {
  static const none = InstanceFlags._(0);
  static const hitTestBoundary = InstanceFlags._(1);

  InstanceFlags operator +(InstanceFlags other) => InstanceFlags._(_value | other._value);
  InstanceFlags operator -(InstanceFlags other) => InstanceFlags._(_value & ~other._value);

  bool operator &(InstanceFlags other) => (_value & other._value) != 0;
}

abstract interface class InstanceHost {
  TextRenderer get textRenderer;

  void scheduleLayout(WidgetInstance instance);
  // TODO: this needs a better name
  void notifyContinuousLayout();
}

typedef VoidCallback = void Function();
typedef WidgetInstanceVisitor = void Function(WidgetInstance child);

abstract class WidgetInstance<T extends InstanceWidget> with NodeWithDepth implements Comparable<WidgetInstance> {
  WidgetInstance({
    required this.widget,
  });

  // ---

  late final WidgetTransform transform = createTransform();

  Object? parentData;
  InstanceFlags flags = InstanceFlags.none;

  InstanceHost? _host;
  InstanceHost? get host => _host;

  WidgetInstance? _parent;

  T widget;

  // ---

  Constraints? _constraints;

  bool _needsLayout = false;
  bool get needsLayout => _needsLayout;

  WidgetInstance? _relayoutBoundary;
  bool get isRelayoutBoundary => _relayoutBoundary == this;

  @nonVirtual
  Size layout(Constraints constraints) {
    print('${'  ' * depth}﹂layout $this ${constraints.isTight ? 'TIGHT' : ''}');
    if (!_needsLayout && constraints == _constraints) {
      print('${'  ' * depth}﹂skipped');
      return transform.toSize();
    }

    _constraints = constraints;
    _relayoutBoundary = constraints.isTight || _parent == null ? this : _parent!._relayoutBoundary!;

    doLayout(constraints);
    _needsLayout = false;

    return transform.toSize();
  }

  void doLayout(Constraints constraints);

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

  @protected
  void markNeedsLayout() {
    _needsLayout = true;

    if (isRelayoutBoundary) {
      host?.scheduleLayout(this);
    } else {
      _parent?.markNeedsLayout();
    }
  }

  void dispose() {}

  @protected
  WidgetTransform createTransform() => WidgetTransform();

  Constraints? get constraints => _constraints;

  @override
  void visitChildren(WidgetInstanceVisitor visitor);

  void hitTest(double x, double y, HitTestState state) {
    if (hitTestSelf(x, y)) state.addHit(this, x, y);

    final coordinates = Vector3.zero();
    visitChildren((child) {
      coordinates.setValues(x, y, 0);
      child.transform.toWidgetCoordinates(coordinates);

      child.hitTest(
        coordinates.x,
        coordinates.y,
        state,
      );
    });
  }

  @protected
  bool hitTestSelf(double x, double y) => x >= 0 && x <= transform.width && y >= 0 && y <= transform.height;

  bool get hasParent => _parent != null;

  // ---

  // void dump() {
  //   print('${'  ' * depth}﹂$this');
  //   for (final child in children) {
  //     child.dump();
  //   }
  // }

  @override
  int compareTo(WidgetInstance<InstanceWidget> other) => NodeWithDepth.compare(this, other);

  @visibleForOverriding
  String debugDescribeType() => runtimeType.toString();

  @override
  String toString() => '${isRelayoutBoundary ? 'BOUNDARY@' : ''}${debugDescribeType()}@${hashCode.toRadixString(16)}';
}

abstract class LeafWidgetInstance<T extends InstanceWidget> extends WidgetInstance<T> {
  LeafWidgetInstance({required super.widget});

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {}
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
    });

    if (ctx.drawBoundingBoxes) {
      final aabb = child.transform.aabb;
      ctx.transform.scope((mat4) {
        mat4.translate(aabb.min.x, aabb.min.y, 0);
        ctx.primitives.roundedRect(
            aabb.max.x - aabb.min.x, aabb.max.y - aabb.min.y, 5, Color.black, mat4, ctx.projection,
            outlineThickness: 1);
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
}

mixin OptionalShrinkWrapLayout<T extends InstanceWidget> on WidgetInstance<T>, OptionalChildProvider<T> {
  @override
  void doLayout(Constraints constraints) {
    final size = child?.layout(constraints) ?? constraints.minSize;
    transform.setSize(size);
  }
}

// --- template classes

abstract class SingleChildWidgetInstance<T extends InstanceWidget> extends WidgetInstance<T>
    with SingleChildProvider, ChildRenderer, SingleChildRenderer {
  WidgetInstance? _child;

  SingleChildWidgetInstance({
    required super.widget,
    // Widget? childWidget,
  }) {
    // if (childWidget != null) {
    //   _child = adopt(childWidget.assemble(this).instantiate());
    // }
  }

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

  OptionalChildWidgetInstance({
    required super.widget,
    // required Widget? childWidget,
  }) {
    // _child = adopt(childWidget?.assemble(this).instantiate());
  }

  @override
  WidgetInstance? get child => _child;
  set child(WidgetInstance? value) {
    if (value == _child) return;

    _child = adopt(value);
    markNeedsLayout();
  }
}

// --- widget tree debugging

WidgetInstance dumpGraphviz(WidgetInstance widget, [IOSink? out]) {
  out ??= stdout;

  if (widget._parent != null) {
    out.writeln('  ${_formatWidget(widget._parent!)} -> ${_formatWidget(widget)};');
  }
  widget.visitChildren((child) {
    dumpGraphviz(child, out);
  });

  return widget;
}

String _formatWidget(WidgetInstance widget) {
  return '"${widget.debugDescribeType()}\\n${widget.hashCode.toRadixString(16)}\\n${widget.transform.x}, ${widget.transform.y}"';
}

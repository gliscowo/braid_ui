import 'dart:collection';
import 'dart:io';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../immediate/foundation.dart';
import 'constraints.dart';
import 'math.dart';

extension type const Key(String value) {}

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
  Iterable<Hit> get occludedTrace => trace.takeWhile((value) => value.instance.flags & InstanceFlags.hitTestBoundary);

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

typedef LayoutData = ({
  LayoutContext ctx,
  Constraints constraints,
});

extension type const InstanceFlags._(int _value) {
  static const none = InstanceFlags._(0);
  static const hitTestBoundary = InstanceFlags._(1);

  InstanceFlags operator |(InstanceFlags other) => InstanceFlags._(_value | other._value);
  bool operator &(InstanceFlags other) => (_value & other._value) != 0;
}

abstract class WidgetInstance<T extends InstanceWidget> implements BuildContext {
  late final WidgetTransform transform = createTransform();

  Object? parentData;
  InstanceFlags flags = InstanceFlags.none;

  WidgetInstance? _parent;

  T widget;

  // ---

  WidgetInstance({
    required this.widget,
  });

  LayoutData? _layoutData;
  bool _needsLayout = false;

  @nonVirtual
  Size layout(LayoutContext ctx, Constraints constraints) {
    if (!_needsLayout && constraints == _layoutData?.constraints) {
      return transform.toSize();
    }

    _layoutData = (ctx: ctx, constraints: constraints);

    doLayout(ctx, constraints);
    _needsLayout = false;

    return transform.toSize();
  }

  void doLayout(LayoutContext ctx, Constraints constraints);

  // ---

  WidgetInstance? descendantFromKey(Key key) {
    for (final child in children) {
      if (child.widget.key == key) {
        return child;
      }

      if (child.descendantFromKey(key) case var result?) {
        return result;
      }
    }

    return null;
  }

  // TODO: not all instances should be queryable here, and
  // the ones which are should be cached
  A? ancestorOfType<A>() {
    var nextAncestor = _parent;
    while (nextAncestor != null) {
      if (nextAncestor is A) return nextAncestor as A;
      nextAncestor = nextAncestor._parent;
    }

    return null;
  }

  void update(double delta) {
    for (final child in children) {
      child.update(delta);
    }
  }

  void draw(DrawContext ctx);

  void notifyChildNeedsLayout() {
    print('$this notified by child');
    _needsLayout = true;

    final prevSize = transform.toSize();
    layout(_layoutData!.ctx, _layoutData!.constraints);

    if (prevSize != transform.toSize()) {
      _parent?.notifyChildNeedsLayout();
    }
  }

  void clearLayoutCache() {
    _needsLayout = true;
    for (final child in children) {
      child.clearLayoutCache();
    }
  }

  @protected
  void markNeedsLayout() {
    print('$this marked dirty');

    _needsLayout = true;
    _parent?.notifyChildNeedsLayout();
  }

  @mustCallSuper
  void dispose() {
    for (final child in children) {
      child.dispose();
    }
  }

  @protected
  set parent(WidgetInstance value) => _parent = value;

  @protected
  WidgetTransform createTransform() => WidgetTransform();

  @protected
  LayoutData? get layoutData => _layoutData;

  Iterable<WidgetInstance> get children => const [];

  void hitTest(double x, double y, HitTestState state) {
    if (hitTestSelf(x, y)) state.addHit(this, x, y);

    final coordinates = Vector3.zero();
    for (final child in children) {
      coordinates.setValues(x, y, 0);
      child.transform.toWidgetCoordinates(coordinates);

      child.hitTest(
        coordinates.x,
        coordinates.y,
        state,
      );
    }
  }

  @protected
  bool hitTestSelf(double x, double y) => x >= 0 && x <= transform.width && y >= 0 && y <= transform.height;

  bool get hasParent => _parent != null;

  @override
  String toString() => '$runtimeType@${hashCode.toRadixString(16)}';
}

// --- rendering/layout mixins

mixin SingleChildProvider<T extends InstanceWidget> on WidgetInstance<T> {
  WidgetInstance get child;

  @override
  Iterable<WidgetInstance> get children => [child];
}

mixin OptionalChildProvider<T extends InstanceWidget> on WidgetInstance<T> {
  WidgetInstance? get child;

  @override
  Iterable<WidgetInstance> get children => [if (child case var child?) child];
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
    for (final child in children) {
      drawChild(ctx, child);
    }
  }
}

mixin ShrinkWrapLayout<T extends InstanceWidget> on WidgetInstance<T>, SingleChildProvider<T> {
  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child.layout(ctx, constraints);
    transform.setSize(size);
  }
}

mixin OptionalShrinkWrapLayout<T extends InstanceWidget> on WidgetInstance<T>, OptionalChildProvider<T> {
  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child?.layout(ctx, constraints) ?? constraints.minSize;
    transform.setSize(size);
  }
}

WidgetInstance dumpGraphviz(WidgetInstance widget, [IOSink? out]) {
  out ??= stdout;

  if (widget._parent != null) {
    out.writeln('  ${_formatWidget(widget._parent!)} -> ${_formatWidget(widget)};');
  }
  for (var child in widget.children) {
    dumpGraphviz(child, out);
  }

  return widget;
}

String _formatWidget(WidgetInstance widget) {
  return '"${widget.runtimeType}\\n${widget.hashCode.toRadixString(16)}\\n${widget.transform.x}, ${widget.transform.y}"';
}

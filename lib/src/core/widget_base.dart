import 'dart:collection';
import 'dart:io';

import 'package:braid_ui/braid_ui.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

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
}

typedef Hit = ({Widget widget, ({double x, double y}) coordinates});

class HitTestState {
  final _hitWidgets = DoubleLinkedQueue<Hit>();

  bool get anyHit => _hitWidgets.isNotEmpty;
  Hit get firstHit => _hitWidgets.first;

  Iterable<Hit> get trace => _hitWidgets;
  Iterable<Hit> get occludedTrace => trace.takeWhile((value) => value.widget is! HitTestOccluder);

  Hit? firstWhere(bool Function(Widget widget) predicate) => occludedTrace.cast<Hit?>().firstWhere(
        (element) => predicate(element!.widget),
        orElse: () => null,
      );

  void addHit(Widget widget, double x, double y) {
    _hitWidgets.addFirst((widget: widget, coordinates: (x: x, y: y)));
  }

  @override
  String toString() => 'HitTestState [${_hitWidgets.map((e) => e.widget.runtimeType).join(', ')}]';
}

mixin MouseListener {
  bool onMouseDown() => false;
  void onMouseEnter() {}
  void onMouseExit() {}
  bool onMouseScroll(double horizontal, double vertical) => false;
}

mixin KeyboardListener {
  void onKeyDown(int keyCode, int modifiers);
  // void onKeyRelease();
  void onChar(int charCode, int modifiers);
}

typedef LayoutData = ({
  LayoutContext ctx,
  Constraints constraints,
});

abstract class Widget {
  late final WidgetTransform transform = createTransform();
  Key? key;

  Widget? _parent;

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

  Widget? descendantFromKey(Key key) {
    for (final child in children) {
      if (child.key == key) {
        return child;
      }

      if (child.descendantFromKey(key) case var result?) {
        return result;
      }
    }

    return null;
  }

  T? ancestorOfType<T>() {
    var nextAncestor = _parent;
    while (nextAncestor != null) {
      if (nextAncestor is T) return nextAncestor as T;
      nextAncestor = nextAncestor._parent;
    }

    return null;
  }

  void doLayout(LayoutContext ctx, Constraints constraints);

  void update(double delta) {
    for (final child in children) {
      child.update(delta);
    }
  }

  void draw(DrawContext ctx, double delta);

  void notifyChildNeedsLayout() {
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
    _needsLayout = true;
    _parent?.notifyChildNeedsLayout();
  }

  @protected
  set parent(Widget value) => _parent = value;

  @protected
  WidgetTransform createTransform() => WidgetTransform();

  @protected
  LayoutData? get layoutData => _layoutData;

  Iterable<Widget> get children => const [];

  void hitTest(double x, double y, HitTestState state) {
    if (hitTestSelf(x, y)) state.addHit(this, x, y);

    for (final child in children) {
      final (childX, childY) = transformCoords(x, y, child.transform.toWidget);
      child.hitTest(childX, childY, state);
    }
  }

  @protected
  bool hitTestSelf(double x, double y) => x >= 0 && x <= transform.width && y >= 0 && y <= transform.height;

  bool get hasParent => _parent != null;

  (double, double) transformCoords(double x, double y, Matrix4 transform) {
    final vec = Vector3(x, y, 0);
    transform.transform3(vec);
    return (vec.x, vec.y);
  }
}

// --- rendering/layout mixins

mixin SingleChildProvider on Widget {
  Widget get child;

  @override
  Iterable<Widget> get children => [child];
}

mixin OptionalChildProvider on Widget {
  Widget? get child;

  @override
  Iterable<Widget> get children => [if (child case var child?) child];
}

mixin ChildRenderer on Widget {
  @protected
  void drawChild(DrawContext ctx, double delta, Widget child) {
    ctx.transform.scopeWith(child.transform.toParent, (mat4) {
      child.draw(ctx, delta);
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

mixin SingleChildRenderer on ChildRenderer, SingleChildProvider {
  @override
  void draw(DrawContext ctx, double delta) {
    drawChild(ctx, delta, child);
  }
}

mixin OptionalChildRenderer on ChildRenderer, OptionalChildProvider {
  @override
  void draw(DrawContext ctx, double delta) {
    if (child case var child?) {
      drawChild(ctx, delta, child);
    }
  }
}

mixin ChildListRenderer on ChildRenderer {
  @override
  void draw(DrawContext ctx, double delta) {
    for (final child in children) {
      drawChild(ctx, delta, child);
    }
  }
}

mixin ShrinkWrapLayout on Widget, SingleChildProvider {
  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child.layout(ctx, constraints);
    transform.setSize(size);
  }
}

mixin OptionalShrinkWrapLayout on Widget, OptionalChildProvider {
  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child?.layout(ctx, constraints) ?? constraints.minSize;
    transform.setSize(size);
  }
}

Widget dumpGraphviz(Widget widget, [IOSink? out]) {
  out ??= stdout;

  if (widget._parent != null) {
    out.writeln('  ${_formatWidget(widget._parent!)} -> ${_formatWidget(widget)};');
  }
  for (var child in widget.children) {
    dumpGraphviz(child, out);
  }

  return widget;
}

String _formatWidget(Widget widget) {
  return '"${widget.runtimeType}\\n${widget.hashCode.toRadixString(16)}\\n${widget.transform.x}, ${widget.transform.y}"';
}

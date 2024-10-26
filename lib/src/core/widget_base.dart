import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
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

  void _setState(void Function() action) {
    action();
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

typedef Hit = (Widget, (double, double));

// TODO proper hit test occlusion
class HitTestState {
  final _hitWidgets = <Hit>[];

  bool get anyHit => _hitWidgets.isNotEmpty;
  Hit get lastHit => _hitWidgets.last;

  Iterable<Hit> get trace => _hitWidgets.reversed;

  Hit? firstWhere(bool Function(Widget widget) predicate) => trace.cast<Hit?>().firstWhere(
        (element) => predicate(element!.$1),
        orElse: () => null,
      );

  void addHit(Widget widget, double x, double y) {
    _hitWidgets.add((widget, (x, y)));
  }

  @override
  String toString() => 'HitTestState [${_hitWidgets.map((e) => e.$1.runtimeType).join(', ')}]';
}

mixin class MouseListener {
  void onMouseDown() {}
  void onMouseEnter() {}
  void onMouseExit() {}
}

abstract class Widget {
  late final WidgetTransform transform = createTransform();
  Key? key;

  Widget? _parent;

  LayoutContext? _layoutContext;
  Constraints? _constraints;
  bool _needsLayout = false;

  @nonVirtual
  Size layout(LayoutContext ctx, Constraints constraints) {
    if (!_needsLayout && constraints == _constraints) return transform.toSize();

    _layoutContext = ctx;
    _constraints = constraints;

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

  void update() {
    for (final child in children) {
      child.update();
    }
  }

  void draw(DrawContext ctx);

  void notifyChildNeedsLayout() {
    _needsLayout = true;

    final prevSize = transform.toSize();
    layout(_layoutContext!, _constraints!);

    if (prevSize != transform.toSize()) {
      _parent?.notifyChildNeedsLayout();
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

  // bool hitTest(double screenX, double screenY, {Matrix4? transform}) {
  //   final (x, y) = _transformCoords(screenX, screenY, transform ?? this.transform.toWidget);
  //   return x >= 0 && x <= this.transform.width && y >= 0 && y <= this.transform.height;
  // }

  (double, double) transformCoords(double x, double y, Matrix4 transform) {
    final vec = Vector3(x, y, 0);
    transform.transform3(vec);
    return (vec.x, vec.y);
  }
}

mixin ChildRenderer on Widget {
  void drawChild(DrawContext ctx, Widget child) {
    ctx.transform.scopeWith(child.transform.toParent, (mat4) {
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

mixin SingleChildProvider on Widget {
  Widget get child;

  @override
  Iterable<Widget> get children => [child];
}

mixin SingleChildRenderer on ChildRenderer, SingleChildProvider {
  @override
  void draw(DrawContext ctx) {
    drawChild(ctx, child);
  }
}

mixin ChildListRenderer on ChildRenderer {
  @override
  List<Widget> get children;

  @override
  void draw(DrawContext ctx) {
    for (final child in children) {
      drawChild(ctx, child);
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

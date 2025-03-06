import 'dart:collection';
import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../text/text.dart';
import 'constraints.dart';
import 'cursors.dart';
import 'math.dart';
import 'widget_base.dart';

typedef WidgetBuilder = Widget Function();

class Padding extends OptionalChildWiget {
  Insets _insets;

  Padding({
    required Insets insets,
    super.child,
  }) : _insets = insets;

  Insets get insets => _insets;
  set insets(Insets value) {
    if (_insets == value) return;

    _insets = value;
    markNeedsLayout();
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final childConstraints = Constraints(
      max(0, constraints.minWidth - insets.horizontal),
      max(0, constraints.minHeight - insets.vertical),
      max(0, constraints.maxWidth - insets.horizontal),
      max(0, constraints.maxHeight - insets.vertical),
    );

    final size = (child?.layout(ctx, childConstraints) ?? Size.zero).withInsets(insets);
    transform.setSize(size);

    child?.transform.x = insets.left;
    child?.transform.y = insets.top;
  }
}

abstract class SingleChildWidget extends Widget with SingleChildProvider, ChildRenderer, SingleChildRenderer {
  late Widget _child;

  @override
  Widget get child => _child;
  set child(Widget widget) {
    if (widget == child) return;

    _child = widget..parent = this;
    markNeedsLayout();
  }

  SingleChildWidget({
    required Widget child,
  }) : _child = child {
    child.parent = this;
  }

  SingleChildWidget.lateChild();

  @nonVirtual
  @protected
  void initChild(Widget widget) {
    _child = widget..parent = this;
  }
}

abstract class OptionalChildWiget extends Widget with OptionalChildProvider, ChildRenderer, OptionalChildRenderer {
  Widget? _child;

  @override
  Widget? get child => _child;
  set child(Widget? widget) {
    if (widget == child) return;

    //TODO should probably unset parent on the old child
    _child = widget?..parent = this;
    markNeedsLayout();
  }

  OptionalChildWiget({Widget? child}) : _child = child {
    _child?.parent = this;
  }
}

class Center extends SingleChildWidget {
  final double? widthFactor, heightFactor;

  Center({
    this.widthFactor,
    this.heightFactor,
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final childSize = child.layout(ctx, constraints.asLoose());
    final selfSize = Size(
            widthFactor != null || !constraints.hasBoundedWidth
                ? childSize.width * (widthFactor ?? 1)
                : constraints.maxWidth,
            heightFactor != null || !constraints.hasBoundedHeight
                ? childSize.height * (heightFactor ?? 1)
                : constraints.maxHeight)
        .constrained(constraints);

    child.transform.x = ((selfSize.width - childSize.width) / 2).floorToDouble();
    child.transform.y = ((selfSize.height - childSize.height) / 2).floorToDouble();

    transform.setSize(selfSize);
  }
}

class Panel extends OptionalChildWiget with OptionalShrinkWrapLayout {
  Color color;
  double cornerRadius;

  Panel({
    required this.color,
    this.cornerRadius = 10.0,
    super.child,
  });

  @override
  void draw(DrawContext ctx) {
    if (cornerRadius <= 1) {
      ctx.primitives.rect(transform.width, transform.height, color, ctx.transform, ctx.projection);
    } else {
      ctx.primitives.roundedRect(transform.width, transform.height, cornerRadius, color, ctx.transform, ctx.projection);
    }

    super.draw(ctx);
  }
}

class HitTestOccluder extends SingleChildWidget with ShrinkWrapLayout {
  HitTestOccluder({required super.child});
}

class MouseArea extends SingleChildWidget with ShrinkWrapLayout, MouseListener {
  void Function()? clickCallback;
  void Function()? enterCallback;
  void Function()? exitCallback;
  void Function(double horizontal, double vertical)? scrollCallback;
  CursorStyle? cursorStyle;

  bool _hovered = false;

  MouseArea({
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.scrollCallback,
    this.cursorStyle,
    required super.child,
  });

  @override
  bool onMouseDown() => (clickCallback?..call()) != null;

  @override
  void onMouseEnter() {
    _hovered = true;
    enterCallback?.call();
  }

  @override
  void onMouseExit() {
    _hovered = false;
    exitCallback?.call();
  }

  @override
  bool onMouseScroll(double horizontal, double vertical) => (scrollCallback?..call(horizontal, vertical)) != null;

  bool get hovered => _hovered;
}

class KeyboardInput extends SingleChildWidget with ShrinkWrapLayout, KeyboardListener {
  void Function(int keyCode, int modifiers)? keyDownCallback;
  void Function(int keyCode, int modifiers)? keyUpCallback;
  void Function(int charCode, int modifiers)? charCallback;
  void Function()? focusGainedCallback;
  void Function()? focusLostCallback;

  bool _focused = false;

  KeyboardInput({
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    required super.child,
  });

  @override
  void onKeyDown(int keyCode, int modifiers) => keyDownCallback?.call(keyCode, modifiers);

  @override
  void onKeyUp(int keyCode, int modifiers) => keyUpCallback?.call(keyCode, modifiers);

  @override
  void onChar(int charCode, int modifiers) => charCallback?.call(charCode, modifiers);

  @override
  void onFocusGained() {
    _focused = true;
    focusGainedCallback?.call();
  }

  @override
  void onFocusLost() {
    _focused = false;
    focusLostCallback?.call();
  }

  bool get focused => _focused;
}

class HappyWidget extends Widget {
  final Size size;
  final double cornerRadius;
  HappyWidget(this.size, {this.cornerRadius = 10});

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final constrained = size.constrained(constraints);
    transform.setSize(constrained);
  }

  @override
  void draw(DrawContext ctx) {
    final (hitTestX, hitTestY) = Matrix4.inverted(ctx.transform).transform2(
      ctx.renderContext.window.cursorX,
      ctx.renderContext.window.cursorY,
    );

    final hovered = hitTestSelf(hitTestX, hitTestY);
    ctx.primitives.roundedRect(
      transform.width,
      transform.height,
      cornerRadius,
      hovered ? Color.red : Color.ofRgb(0x5865f2),
      ctx.transform,
      ctx.projection,
    );

    ctx.transform.translate(5.0, 5.0);
    ctx.textRenderer.drawText(Text.string('hi chyz :)'), 16, Color.white, ctx.transform, ctx.projection);
  }
}

class Gradient extends SingleChildWidget with ShrinkWrapLayout {
  Color startColor;
  Color endColor;
  double position;
  double size;
  double angle;

  Gradient({
    required super.child,
    required this.startColor,
    required this.endColor,
    this.position = 0,
    this.size = 1,
    this.angle = 0,
  });

  @override
  void draw(DrawContext ctx) {
    ctx.primitives.gradientRect(
      transform.width,
      transform.height,
      startColor,
      endColor,
      position,
      size,
      angle,
      ctx.transform,
      ctx.projection,
    );

    super.draw(ctx);
  }
}

class Constrained extends SingleChildWidget {
  final Constraints constraints;

  Constrained({
    required this.constraints,
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child.layout(ctx, this.constraints.respecting(constraints));
    transform.width = size.width;
    transform.height = size.height;
  }
}

class Transform extends SingleChildWidget with ShrinkWrapLayout {
  Transform({
    required Matrix4 matrix,
    required super.child,
  }) {
    (transform as CustomWidgetTransform).matrix = matrix;
  }

  Matrix4 get matrix => (transform as CustomWidgetTransform).matrix;
  set matrix(Matrix4 value) {
    (transform as CustomWidgetTransform).matrix = value;
    markNeedsLayout();
  }

  @override
  CustomWidgetTransform createTransform() => CustomWidgetTransform();
}

class LayoutAfterTransform extends SingleChildWidget {
  LayoutAfterTransform({
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    child.transform.x = 0;
    child.transform.y = 0;

    child.layout(ctx, constraints);

    final size = Size(
      child.transform.aabb.width,
      child.transform.aabb.height,
    ).constrained(constraints);

    child.transform.x = -child.transform.aabb.min.x;
    child.transform.y = -child.transform.aabb.min.y;

    transform.width = size.width;
    transform.height = size.height;
  }
}

//TODO support nested clips
class Clip extends SingleChildWidget with ShrinkWrapLayout {
  Clip({
    required super.child,
  });

  @override
  void draw(DrawContext ctx) {
    final scissorBox = Aabb3.copy(transform.aabb)..transform(ctx.transform);
    gl.scissor(
      scissorBox.min.x.toInt(),
      ctx.renderContext.window.height - scissorBox.min.y.toInt() - scissorBox.height.toInt(),
      scissorBox.width.toInt(),
      scissorBox.height.toInt(),
    );

    gl.enable(glScissorTest);
    super.draw(ctx);
    gl.disable(glScissorTest);
  }
}

class StencilClip extends SingleChildWidget with ShrinkWrapLayout {
  static final _framebufferByWindow = <Window, GlFramebuffer>{};
  static var stencilValue = 0;

  StencilClip({
    required super.child,
  });

  @override
  void draw(DrawContext ctx) {
    stencilValue++;

    final window = ctx.renderContext.window;
    final framebuffer = _framebufferByWindow[window] ??= (() {
      final buffer = GlFramebuffer.trackingWindow(window, stencil: true);
      ctx.renderContext.frameEvents.listen((_) => buffer.clear(color: Color.ofArgb(0), depth: 0, stencil: 0));
      return buffer;
    })();

    framebuffer.bind();
    gl.enable(glStencilTest);

    gl.stencilFunc(glEqual, stencilValue - 1, 0xFF);
    gl.stencilOp(glKeep, glIncr, glIncr);
    ctx.primitives.rect(transform.width, transform.height, Color.ofArgb(0), ctx.transform, ctx.projection);

    gl.stencilFunc(glEqual, stencilValue, 0xFF);
    gl.stencilOp(glKeep, glKeep, glKeep);

    super.draw(ctx);

    gl.disable(glStencilTest);
    framebuffer.unbind();

    stencilValue--;
    if (stencilValue == 0) {
      ctx.primitives.blitFramebuffer(framebuffer);
    }
  }
}

class Pages extends SingleChildWidget with ShrinkWrapLayout {
  final bool _cache;
  final List<WidgetBuilder> _builders;
  final Map<int, Widget> _pages = HashMap();

  int _page = 0;

  Pages({
    bool cache = true,
    required List<WidgetBuilder> pageBuilders,
  })  : _cache = cache,
        _builders = pageBuilders,
        super.lateChild() {
    initChild(_builders.first());
  }

  int get page => _page;
  set page(int value) {
    if (_page == value) return;
    _page = value;

    final newChild = _cache ? _pages[_page] ??= _builders[_page]() : _builders[_page]();
    child = newChild;

    markNeedsLayout();
  }
}

class Overlay extends SingleChildWidget with ShrinkWrapLayout {
  late MouseArea _mouseArea;

  Overlay({
    bool barrierDismissable = false,
    required Widget Function(Overlay overlay) contentBuilder,
  }) : super.lateChild() {
    initChild(HitTestOccluder(
      child: _mouseArea = MouseArea(
        clickCallback: barrierDismissable ? close : null,
        child: Panel(
          color: Color.black.copyWith(a: .75),
          cornerRadius: 0,
          child: Center(
            child: HitTestOccluder(
              child: contentBuilder(this),
            ),
          ),
        ),
      ),
    ));
  }

  static void open({
    bool barrierDismissable = false,
    required Widget context,
    required Widget Function(Overlay overlay) contentBuilder,
  }) {
    final scaffold = context.ancestorOfType<AppScaffold>();
    if (scaffold == null) {
      throw 'missing scaffold to mount overlay';
    }

    scaffold.addOverlay(Overlay(
      barrierDismissable: barrierDismissable,
      contentBuilder: contentBuilder,
    ));
  }

  void close() => ancestorOfType<AppScaffold>()!.removeOverlay(this);

  bool get barrierDismissable => _mouseArea.clickCallback != null;
  set barrierDismissable(bool value) {
    _mouseArea.clickCallback = value ? close : null;
  }
}

class AppScaffold extends Widget with ChildRenderer, ChildListRenderer {
  final Widget _root;
  final List<Overlay> _overlays = [];

  AppScaffold({
    required Widget root,
  }) : _root = root {
    _root.parent = this;
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    var selfSize = Size.zero;
    for (final child in children) {
      selfSize = Size.max(selfSize, child.layout(ctx, constraints));
    }

    transform.setSize(selfSize.constrained(constraints));
  }

  @override
  Iterable<Widget> get children sync* {
    yield _root;
    yield* _overlays;
  }

  void addOverlay(Overlay overlay) {
    _overlays.add(overlay..parent = this);
    markNeedsLayout();
  }

  void removeOverlay(Overlay overlay) {
    _overlays.remove(overlay);
    markNeedsLayout();
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    if (hasParent) return;

    if (layoutData case LayoutData data) {
      layout(data.ctx, data.constraints);
    }
  }
}

// TODO: whether this has a good justification for existing is
// questionable, in fact it should likely be merged with or
// subsumed by FlexChild
class Expanded extends OptionalChildWiget with ChildRenderer {
  bool _horizontal, _vertical;

  Expanded({
    bool horizontal = false,
    bool vertical = false,
    super.child,
  })  : _vertical = vertical,
        _horizontal = horizontal;

  Expanded.horizontal({Widget? child}) : this(horizontal: true, child: child);
  Expanded.vertical({Widget? child}) : this(vertical: true, child: child);
  Expanded.both({Widget? child}) : this(horizontal: true, vertical: true, child: child);

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final innerConstraints = Constraints.tightOnAxis(
      horizontal: horizontal ? double.infinity : null,
      vertical: vertical ? double.infinity : null,
    ).respecting(constraints);

    transform.setSize(child?.layout(ctx, innerConstraints) ??
        Size(
          vertical ? constraints.minWidth : constraints.maxWidth,
          !vertical ? constraints.minHeight : constraints.maxHeight,
        ));
  }

  bool get horizontal => _horizontal;
  set horizontal(bool value) {
    _horizontal = value;
    markNeedsLayout();
  }

  bool get vertical => _vertical;
  set vertical(bool value) {
    _vertical = value;
    markNeedsLayout();
  }
}

class Divider extends SingleChildWidget with ShrinkWrapLayout {
  late Panel _panel;

  final bool _vertical;
  double _thickness;

  Divider.vertical({
    double thickness = 1,
    double cornerRadius = 0,
    Color? color,
  })  : _vertical = true,
        _thickness = thickness,
        super.lateChild() {
    initChild(Expanded.vertical(
      child: _panel = Panel(
        color: color ?? Color.white,
        cornerRadius: cornerRadius,
      ),
    ));
  }

  Divider.horizontal({
    double thickness = 1,
    double cornerRadius = 0,
    Color? color,
  })  : _vertical = false,
        _thickness = thickness,
        super.lateChild() {
    initChild(Expanded.horizontal(
      child: _panel = Panel(
        color: color ?? Color.white,
        cornerRadius: cornerRadius,
      ),
    ));
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final innerConstraints = Constraints.tightOnAxis(
      vertical: !_vertical ? _thickness : null,
      horizontal: _vertical ? _thickness : null,
    ).respecting(constraints);

    super.doLayout(ctx, innerConstraints);
  }

  Color get color => _panel.color;
  set color(Color value) => _panel.color = value;

  double get cornerRadius => _panel.cornerRadius;
  set cornerRadius(double value) => _panel.cornerRadius = value;

  double get thickness => _thickness;
  set thickness(double value) {
    _thickness = value;
    markNeedsLayout();
  }
}

import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../immediate/foundation.dart';
import '../text/text.dart';
import 'constraints.dart';
import 'math.dart';
import 'widget_base.dart';

typedef WidgetBuilder = Widget Function();

class PaddingInstance extends OptionalChildWidgetInstance {
  Padding _widget;

  PaddingInstance({
    required Padding widget,
    super.child,
  }) : _widget = widget;

  @override
  Padding get widget => _widget;
  set widget(Padding value) {
    if (_widget.insets == value.insets) return;

    _widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final insets = _widget.insets;
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

abstract class SingleChildWidgetInstance extends WidgetInstance
    with SingleChildProvider, ChildRenderer, SingleChildRenderer {
  late WidgetInstance _child;

  @override
  WidgetInstance get child => _child;
  set child(WidgetInstance widget) {
    if (widget == _child) return;

    _child.dispose();
    _child = widget..parent = this;
    markNeedsLayout();
  }

  SingleChildWidgetInstance({
    required WidgetInstance child,
  }) : _child = child {
    child.parent = this;
  }

  SingleChildWidgetInstance.lateChild();

  @nonVirtual
  @protected
  void initChild(WidgetInstance widget) {
    _child = widget..parent = this;
  }
}

abstract class OptionalChildWidgetInstance extends WidgetInstance
    with OptionalChildProvider, ChildRenderer, OptionalChildRenderer {
  WidgetInstance? _child;

  @override
  WidgetInstance? get child => _child;
  set child(WidgetInstance? widget) {
    if (widget == _child) return;

    if (_child != null) {
      _child!.dispose();
    }

    _child = widget?..parent = this;
    markNeedsLayout();
  }

  OptionalChildWidgetInstance({WidgetInstance? child}) : _child = child {
    _child?.parent = this;
  }
}

class CenterInstance extends SingleChildWidgetInstance {
  Center _widget;

  CenterInstance({
    required Center widget,
    required super.child,
  }) : _widget = widget;

  @override
  Center get widget => _widget;
  set widget(Center value) {
    if (_widget.widthFactor == value.widthFactor && _widget.heightFactor == value.heightFactor) return;

    _widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final widthFactor = _widget.widthFactor, heightFactor = _widget.heightFactor;

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

class PanelInstance extends OptionalChildWidgetInstance with OptionalShrinkWrapLayout {
  Panel _widget;

  PanelInstance({
    required Panel widget,
    super.child,
  }) : _widget = widget;

  @override
  Panel get widget => _widget;
  set widget(Panel value) {
    if (_widget.color == value.color && _widget.cornerRadius == value.cornerRadius) return;

    _widget = value;
    markNeedsLayout();
  }

  @override
  void draw(DrawContext ctx) {
    final cornerRadius = _widget.cornerRadius;
    if (cornerRadius <= 1) {
      ctx.primitives.rect(transform.width, transform.height, _widget.color, ctx.transform, ctx.projection);
    } else {
      ctx.primitives
          .roundedRect(transform.width, transform.height, cornerRadius, _widget.color, ctx.transform, ctx.projection);
    }

    super.draw(ctx);
  }
}

class HitTestOccluder extends SingleChildWidgetInstance with ShrinkWrapLayout {
  HitTestOccluder({required super.child});
}

class MouseAreaInstance extends SingleChildWidgetInstance with ShrinkWrapLayout, MouseListener {
  MouseArea _widget;
  bool _hovered = false;

  MouseAreaInstance({
    required MouseArea widget,
    required super.child,
  }) : _widget = widget;

  @override
  MouseArea get widget => _widget;
  @override
  set widget(MouseArea area) => _widget = area;

  @override
  bool onMouseDown() => (_widget.clickCallback?..call()) != null;

  @override
  void onMouseEnter() {
    _hovered = true;
    _widget.enterCallback?.call();
  }

  @override
  void onMouseExit() {
    _hovered = false;
    _widget.exitCallback?.call();
  }

  @override
  bool onMouseScroll(double horizontal, double vertical) =>
      (_widget.scrollCallback?..call(horizontal, vertical)) != null;

  bool get hovered => _hovered;
}

class KeyboardInput extends SingleChildWidgetInstance with ShrinkWrapLayout, KeyboardListener {
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

class HappyWidget extends WidgetInstance {
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

class Gradient extends SingleChildWidgetInstance with ShrinkWrapLayout {
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

class Constrained extends SingleChildWidgetInstance {
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

class Transform extends SingleChildWidgetInstance with ShrinkWrapLayout {
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

class LayoutAfterTransform extends SingleChildWidgetInstance {
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
class Clip extends SingleChildWidgetInstance with ShrinkWrapLayout {
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

class StencilClip extends SingleChildWidgetInstance with ShrinkWrapLayout {
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

// class Pages extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   final bool _cache;
//   final List<WidgetBuilder> _builders;
//   final Map<int, WidgetInstance> _pages = HashMap();

//   int _page = 0;

//   Pages({
//     bool cache = true,
//     required List<WidgetBuilder> pageBuilders,
//   })  : _cache = cache,
//         _builders = pageBuilders,
//         super.lateChild() {
//     initChild(_builders.first());
//   }

//   int get page => _page;
//   set page(int value) {
//     if (_page == value) return;
//     _page = value;

//     final newChild = _cache ? _pages[_page] ??= _builders[_page]() : _builders[_page]();
//     child = newChild;

//     markNeedsLayout();
//   }
// }

class Overlay extends WidgetInstance {
  @override
  void doLayout(LayoutContext ctx, Constraints constraints) => transform.setSize(constraints.minSize);

  @override
  void draw(DrawContext ctx) {}
}

// class Overlay extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   late MouseArea _mouseArea;

//   Overlay({
//     bool barrierDismissable = false,
//     required WidgetInstance Function(Overlay overlay) contentBuilder,
//   }) : super.lateChild() {
//     initChild(HitTestOccluder(
//       child: _mouseArea = MouseArea(
//         clickCallback: barrierDismissable ? close : null,
//         child: PanelInstance(
//           color: Color.black.copyWith(a: .75),
//           cornerRadius: 0,
//           child: CenterInstance(
//             child: HitTestOccluder(
//               child: contentBuilder(this),
//             ),
//           ),
//         ),
//       ),
//     ));
//   }

//   static void open({
//     bool barrierDismissable = false,
//     required WidgetInstance context,
//     required WidgetInstance Function(Overlay overlay) contentBuilder,
//   }) {
//     final scaffold = context.ancestorOfType<AppScaffold>();
//     if (scaffold == null) {
//       throw 'missing scaffold to mount overlay';
//     }

//     scaffold.addOverlay(Overlay(
//       barrierDismissable: barrierDismissable,
//       contentBuilder: contentBuilder,
//     ));
//   }

//   void close() => ancestorOfType<AppScaffold>()!.removeOverlay(this);

//   bool get barrierDismissable => _mouseArea.clickCallback != null;
//   set barrierDismissable(bool value) {
//     _mouseArea.clickCallback = value ? close : null;
//   }
// }

class AppScaffold extends WidgetInstance with ChildRenderer, ChildListRenderer {
  WidgetInstance _root;
  final List<Overlay> _overlays = [];

  AppScaffold({
    required WidgetInstance root,
  }) : _root = root {
    _root.parent = this;
  }

  WidgetInstance get root => _root;
  set root(WidgetInstance value) {
    if (_root == value) return;

    _root.dispose();
    _root = value;
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
  Iterable<WidgetInstance> get children sync* {
    yield _root;
    yield* _overlays;
  }

  void addOverlay(Overlay overlay) {
    _overlays.add(overlay..parent = this);
    markNeedsLayout();
  }

  void removeOverlay(Overlay overlay) {
    _overlays.remove(overlay);
    overlay.dispose();
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
class Expanded extends OptionalChildWidgetInstance with ChildRenderer {
  bool _horizontal, _vertical;

  Expanded({
    bool horizontal = false,
    bool vertical = false,
    super.child,
  })  : _vertical = vertical,
        _horizontal = horizontal;

  Expanded.horizontal({WidgetInstance? child}) : this(horizontal: true, child: child);
  Expanded.vertical({WidgetInstance? child}) : this(vertical: true, child: child);
  Expanded.both({WidgetInstance? child}) : this(horizontal: true, vertical: true, child: child);

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

// class Divider extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   late PanelInstance _panel;

//   final bool _vertical;
//   double _thickness;

//   Divider.vertical({
//     double thickness = 1,
//     double cornerRadius = 0,
//     Color? color,
//   })  : _vertical = true,
//         _thickness = thickness,
//         super.lateChild() {
//     initChild(Expanded.vertical(
//       child: _panel = PanelInstance(
//         color: color ?? Color.white,
//         cornerRadius: cornerRadius,
//       ),
//     ));
//   }

//   Divider.horizontal({
//     double thickness = 1,
//     double cornerRadius = 0,
//     Color? color,
//   })  : _vertical = false,
//         _thickness = thickness,
//         super.lateChild() {
//     initChild(Expanded.horizontal(
//       child: _panel = PanelInstance(
//         color: color ?? Color.white,
//         cornerRadius: cornerRadius,
//       ),
//     ));
//   }

//   @override
//   void doLayout(LayoutContext ctx, Constraints constraints) {
//     final innerConstraints = Constraints.tightOnAxis(
//       vertical: !_vertical ? _thickness : null,
//       horizontal: _vertical ? _thickness : null,
//     ).respecting(constraints);

//     super.doLayout(ctx, innerConstraints);
//   }

//   Color get color => _panel.color;
//   set color(Color value) => _panel.color = value;

//   double get cornerRadius => _panel.cornerRadius;
//   set cornerRadius(double value) => _panel.cornerRadius = value;

//   double get thickness => _thickness;
//   set thickness(double value) {
//     _thickness = value;
//     markNeedsLayout();
//   }
// }

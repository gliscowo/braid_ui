import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../immediate/foundation.dart';
import 'constraints.dart';
import 'math.dart';
import 'widget_base.dart';

typedef WidgetBuilder = Widget Function();

class PaddingInstance extends OptionalChildWidgetInstance<Padding> {
  PaddingInstance({
    required super.widget,
  });

  @override
  set widget(Padding value) {
    if (widget.insets == value.insets) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final insets = widget.insets;
    final childConstraints = Constraints(
      max(0, constraints.minWidth - insets.horizontal),
      max(0, constraints.minHeight - insets.vertical),
      max(0, constraints.maxWidth - insets.horizontal),
      max(0, constraints.maxHeight - insets.vertical),
    );

    final size = (child?.layout(childConstraints) ?? Size.zero).withInsets(insets);
    transform.setSize(size);

    child?.transform.x = insets.left;
    child?.transform.y = insets.top;
  }
}

abstract class SingleChildWidgetInstance<T extends SingleChildInstanceWidget> extends WidgetInstance<T>
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

abstract class OptionalChildWidgetInstance<T extends OptionalChildInstanceWidget> extends WidgetInstance<T>
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

class CenterInstance extends SingleChildWidgetInstance<Center> {
  CenterInstance({
    required super.widget,
  });

  @override
  set widget(Center value) {
    if (widget.widthFactor == value.widthFactor && widget.heightFactor == value.heightFactor) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final widthFactor = widget.widthFactor, heightFactor = widget.heightFactor;

    final childSize = child.layout(constraints.asLoose());
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

class PanelInstance extends OptionalChildWidgetInstance<Panel> with OptionalShrinkWrapLayout {
  PanelInstance({
    required super.widget,
  });

  @override
  void draw(DrawContext ctx) {
    final cornerRadius = widget.cornerRadius;
    if (cornerRadius <= 1) {
      ctx.primitives.rect(transform.width, transform.height, widget.color, ctx.transform, ctx.projection);
    } else {
      ctx.primitives
          .roundedRect(transform.width, transform.height, cornerRadius, widget.color, ctx.transform, ctx.projection);
    }

    super.draw(ctx);
  }
}

class MouseAreaInstance extends SingleChildWidgetInstance<MouseArea> with ShrinkWrapLayout, MouseListener {
  bool _hovered = false;

  MouseAreaInstance({
    required super.widget,
  });

  @override
  bool onMouseDown() => (widget.clickCallback?..call()) != null;

  @override
  void onMouseEnter() {
    _hovered = true;
    widget.enterCallback?.call();
  }

  @override
  void onMouseExit() {
    _hovered = false;
    widget.exitCallback?.call();
  }

  @override
  bool onMouseScroll(double horizontal, double vertical) =>
      (widget.scrollCallback?..call(horizontal, vertical)) != null;

  bool get hovered => _hovered;
}

class KeyboardInputInstance extends SingleChildWidgetInstance<KeyboardInput> with ShrinkWrapLayout, KeyboardListener {
  bool _focused = false;

  KeyboardInputInstance({
    required super.widget,
  });

  @override
  void onKeyDown(int keyCode, int modifiers) => widget.keyDownCallback?.call(keyCode, modifiers);

  @override
  void onKeyUp(int keyCode, int modifiers) => widget.keyUpCallback?.call(keyCode, modifiers);

  @override
  void onChar(int charCode, int modifiers) => widget.charCallback?.call(charCode, modifiers);

  @override
  void onFocusGained() {
    _focused = true;
    widget.focusGainedCallback?.call();
  }

  @override
  void onFocusLost() {
    _focused = false;
    widget.focusLostCallback?.call();
  }

  bool get focused => _focused;
}

// class HappyWidget extends WidgetInstance {
//   final Size size;
//   final double cornerRadius;
//   HappyWidget(this.size, {this.cornerRadius = 10});

//   @override
//   void doLayout(Constraints constraints) {
//     final constrained = size.constrained(constraints);
//     transform.setSize(constrained);
//   }

//   @override
//   void draw(DrawContext ctx) {
//     final (hitTestX, hitTestY) = Matrix4.inverted(ctx.transform).transform2(
//       ctx.renderContext.window.cursorX,
//       ctx.renderContext.window.cursorY,
//     );

//     final hovered = hitTestSelf(hitTestX, hitTestY);
//     ctx.primitives.roundedRect(
//       transform.width,
//       transform.height,
//       cornerRadius,
//       hovered ? Color.red : Color.ofRgb(0x5865f2),
//       ctx.transform,
//       ctx.projection,
//     );

//     ctx.transform.translate(5.0, 5.0);
//     ctx.textRenderer.drawText(Text.string('hi chyz :)'), 16, Color.white, ctx.transform, ctx.projection);
//   }
// }

class Gradient extends OptionalChildInstanceWidget {
  final Color startColor;
  final Color endColor;
  final double position;
  final double size;
  final double angle;

  Gradient({
    super.key,
    required this.startColor,
    required this.endColor,
    this.position = 0,
    this.size = 1,
    this.angle = 0,
    super.child,
  });

  @override
  GradientInstance instantiate() => GradientInstance(widget: this);
}

class GradientInstance extends OptionalChildWidgetInstance<Gradient> with OptionalShrinkWrapLayout {
  GradientInstance({
    required super.widget,
  });

  @override
  void draw(DrawContext ctx) {
    ctx.primitives.gradientRect(
      transform.width,
      transform.height,
      widget.startColor,
      widget.endColor,
      widget.position,
      widget.size,
      widget.angle,
      ctx.transform,
      ctx.projection,
    );

    super.draw(ctx);
  }
}

class ConstrainedInstance extends SingleChildWidgetInstance<Constrained> {
  ConstrainedInstance({
    required super.widget,
  });

  @override
  set widget(Constrained value) {
    if (widget.constraints == value.constraints) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final size = child.layout(widget.constraints.respecting(constraints));
    transform.setSize(size);
  }
}

class Transform extends SingleChildInstanceWidget {
  final Matrix4 matrix;

  Transform({
    super.key,
    required this.matrix,
    required super.child,
  });

  @override
  TransformInstance instantiate() => TransformInstance(widget: this);
}

class TransformInstance extends SingleChildWidgetInstance<Transform> with ShrinkWrapLayout {
  TransformInstance({
    required super.widget,
  }) {
    (transform as CustomWidgetTransform).matrix = widget.matrix;
  }

  @override
  set widget(Transform value) {
    if (widget.matrix == value.matrix) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  CustomWidgetTransform createTransform() => CustomWidgetTransform();
}

class LayoutAfterTransform extends SingleChildInstanceWidget {
  LayoutAfterTransform({
    super.key,
    required super.child,
  });

  @override
  LayoutAfterTransformInstance instantiate() => LayoutAfterTransformInstance(widget: this);
}

class LayoutAfterTransformInstance<LayoutAfterTransform> extends SingleChildWidgetInstance {
  LayoutAfterTransformInstance({
    required super.widget,
  });

  @override
  void doLayout(Constraints constraints) {
    child.transform.x = 0;
    child.transform.y = 0;

    child.layout(constraints);

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

class Clip extends SingleChildInstanceWidget {
  Clip({
    super.key,
    required super.child,
  });

  @override
  ClipInstance instantiate() => ClipInstance(widget: this);
}

//TODO support nested clips
class ClipInstance extends SingleChildWidgetInstance<Clip> with ShrinkWrapLayout {
  ClipInstance({
    required super.widget,
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

class StencipClip extends SingleChildInstanceWidget {
  StencipClip({
    super.key,
    required super.child,
  });

  @override
  StencilClipInstance instantiate() => StencilClipInstance(widget: this);
}

class StencilClipInstance extends SingleChildWidgetInstance with ShrinkWrapLayout {
  static final _framebufferByWindow = <Window, GlFramebuffer>{};
  static var stencilValue = 0;

  StencilClipInstance({
    required super.widget,
  });

  @override
  void draw(DrawContext ctx) {
    stencilValue++;

    final window = ctx.renderContext.window;
    final framebuffer = _framebufferByWindow[window] ??= (() {
      final buffer = GlFramebuffer.trackingWindow(window, stencil: true);
      ctx.renderContext.frameEvents.listen((_) => buffer.clear(color: const Color(0), depth: 0, stencil: 0));
      return buffer;
    })();

    framebuffer.bind();
    gl.enable(glStencilTest);

    gl.stencilFunc(glEqual, stencilValue - 1, 0xFF);
    gl.stencilOp(glKeep, glIncr, glIncr);
    ctx.primitives.rect(transform.width, transform.height, const Color(0), ctx.transform, ctx.projection);

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

// class Overlay extends WidgetInstance {
//   @override
//   void doLayout(Constraints constraints) => transform.setSize(constraints.minSize);

//   @override
//   void draw(DrawContext ctx) {}
// }

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

class AppScaffold extends SingleChildInstanceWidget {
  final BuildScope scope;

  AppScaffold({
    required Widget app,
    required this.scope,
  }) : super(child: app);

  @override
  AppScaffoldProxy proxy() => AppScaffoldProxy(this);

  @override
  AppRoot instantiate() => AppRoot(widget: this);
}

class AppScaffoldProxy extends SingleChildInstanceWidgetProxy {
  AppScaffoldProxy(super.widget);

  @override
  bool mounted = false;

  void setup() {
    mounted = true;

    child = (widget as SingleChildInstanceWidget).child.proxy();
    instance.child = child!.associatedInstance;
  }

  @override
  BuildScope get buildScope => (widget as AppScaffold).scope;
}

class AppRoot extends WidgetInstance<SingleChildInstanceWidget>
    with ChildRenderer, ChildListRenderer
    implements SingleChildWidgetInstance {
  late WidgetInstance _root;
  // final List<Overlay> _overlays = [];

  AppRoot({
    required super.widget,
  });

  WidgetInstance get root => _root;
  set root(WidgetInstance value) {
    if (_root == value) return;

    _root.dispose();
    _root = value;
  }

  @override
  void doLayout(Constraints constraints) {
    var selfSize = Size.zero;
    for (final child in children) {
      selfSize = Size.max(selfSize, child.layout(constraints));
    }

    transform.setSize(selfSize.constrained(constraints));
  }

  @override
  Iterable<WidgetInstance> get children sync* {
    yield _root;
    // yield* _overlays;
  }

  // void addOverlay(Overlay overlay) {
  //   _overlays.add(overlay..parent = this);
  //   markNeedsLayout();
  // }

  // void removeOverlay(Overlay overlay) {
  //   _overlays.remove(overlay);
  //   overlay.dispose();
  //   markNeedsLayout();
  // }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    if (hasParent) return;

    if (constraints case Constraints constraints) {
      layout(constraints);
    }
  }

  @override
  WidgetInstance<InstanceWidget>? get _child => _root;

  @override
  WidgetInstance<InstanceWidget> get child => _root;

  @override
  set _child(WidgetInstance<InstanceWidget>? __child) => _root = __child!;

  @override
  set child(WidgetInstance<InstanceWidget> value) => _root = value;
}

// TODO: whether this has a good justification for existing is
// questionable, in fact it should likely be merged with or
// subsumed by FlexChild
// class Expanded extends OptionalChildWidgetInstance with ChildRenderer {
//   bool _horizontal, _vertical;

//   Expanded({
//     bool horizontal = false,
//     bool vertical = false,
//     super.child,
//   })  : _vertical = vertical,
//         _horizontal = horizontal;

//   Expanded.horizontal({WidgetInstance? child}) : this(horizontal: true, child: child);
//   Expanded.vertical({WidgetInstance? child}) : this(vertical: true, child: child);
//   Expanded.both({WidgetInstance? child}) : this(horizontal: true, vertical: true, child: child);

//   @override
//   void doLayout(Constraints constraints) {
//     final innerConstraints = Constraints.tightOnAxis(
//       horizontal: horizontal ? double.infinity : null,
//       vertical: vertical ? double.infinity : null,
//     ).respecting(constraints);

//     transform.setSize(child?.layout(ctx, innerConstraints) ??
//         Size(
//           vertical ? constraints.minWidth : constraints.maxWidth,
//           !vertical ? constraints.minHeight : constraints.maxHeight,
//         ));
//   }

//   bool get horizontal => _horizontal;
//   set horizontal(bool value) {
//     _horizontal = value;
//     markNeedsLayout();
//   }

//   bool get vertical => _vertical;
//   set vertical(bool value) {
//     _vertical = value;
//     markNeedsLayout();
//   }
// }

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
//   void doLayout(Constraints constraints) {
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

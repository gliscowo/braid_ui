import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'flex.dart';

abstract class VisitorWidget extends Widget {
  final Widget child;

  const VisitorWidget({super.key, required this.child});

  @override
  VisitorProxy proxy();
}

typedef InstanceVisitor<T> = void Function(T widget, WidgetInstance instance);

class VisitorProxy<T extends VisitorWidget> extends ComposedProxy with InstanceListenerProxy {
  final InstanceVisitor<T> visitor;
  VisitorProxy(VisitorWidget super.widget, this.visitor);

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
    rebuild();
  }

  @override
  void updateWidget(covariant Widget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    child = refreshChild(child, (widget as VisitorWidget).child, slot);
    super.doRebuild();
  }

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, covariant Object? slot) {
    visitor(widget as T, instance!);
  }
}

// ---

class Flexible extends VisitorWidget {
  final double flexFactor;

  const Flexible({super.key, this.flexFactor = 1.0, required super.child});

  static _visitor(Flexible widget, WidgetInstance instance) {
    if (instance.parentData case FlexParentData data) {
      data.flexFactor = widget.flexFactor;
    } else {
      instance.parentData = FlexParentData(widget.flexFactor);
    }
  }

  @override
  VisitorProxy proxy() => VisitorProxy<Flexible>(this, _visitor);
}

class HitTestOccluder extends VisitorWidget {
  const HitTestOccluder({super.key, required super.child});

  static _visitor(HitTestOccluder _, WidgetInstance instance) {
    instance.flags += InstanceFlags.hitTestBoundary;
  }

  @override
  VisitorProxy proxy() => VisitorProxy<HitTestOccluder>(this, _visitor);
}

// ---

class Padding extends OptionalChildInstanceWidget {
  final Insets insets;

  const Padding({super.key, required this.insets, super.child});

  @override
  PaddingInstance instantiate() => PaddingInstance(widget: this);
}

class PaddingInstance extends OptionalChildWidgetInstance<Padding> {
  PaddingInstance({required super.widget});

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

    final size = (child?.layout(childConstraints) ?? Size.zero).withInsets(insets).constrained(constraints);
    transform.setSize(size);

    child?.transform.x = insets.left;
    child?.transform.y = insets.top;
  }
}

// ---

class Sized extends SingleChildInstanceWidget with ConstraintWidget {
  final double? width;
  final double? height;

  const Sized({super.key, this.width, this.height, required super.child});

  @override
  Constraints get constraints => Constraints.tightOnAxis(horizontal: width, vertical: height);

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => ConstrainedInstance(widget: this);
}

class Constrained extends SingleChildInstanceWidget with ConstraintWidget {
  @override
  final Constraints constraints;

  const Constrained({super.key, required this.constraints, required super.child});

  @override
  ConstrainedInstance instantiate() => ConstrainedInstance(widget: this);
}

mixin ConstraintWidget on SingleChildInstanceWidget {
  Constraints get constraints;
}

class ConstrainedInstance extends SingleChildWidgetInstance<ConstraintWidget> {
  ConstrainedInstance({required super.widget});

  @override
  set widget(ConstraintWidget value) {
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

// ---

class Alignment {
  static const topLeft = Alignment(horizontal: 0, vertical: 0);
  static const top = Alignment(horizontal: .5, vertical: 0);
  static const topRight = Alignment(horizontal: 1, vertical: 0);
  static const left = Alignment(horizontal: 0, vertical: .5);
  static const center = Alignment(horizontal: .5, vertical: .5);
  static const right = Alignment(horizontal: 1, vertical: .5);
  static const bottomLeft = Alignment(horizontal: 0, vertical: 1);
  static const bottom = Alignment(horizontal: .5, vertical: 1);
  static const bottomRight = Alignment(horizontal: 1, vertical: 1);

  // ---

  final double horizontal;
  final double vertical;

  const Alignment({required this.horizontal, required this.vertical});

  (double, double) align(Size space, Size object) => (
    ((space.width - object.width) * horizontal).floorToDouble(),
    ((space.height - object.height) * vertical).floorToDouble(),
  );

  get _props => (horizontal, vertical);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is Alignment && other._props == _props;
}

class Center extends Align {
  const Center({super.key, super.widthFactor, super.heightFactor, required super.child})
    : super(alignment: Alignment.center);
}

class Align extends SingleChildInstanceWidget {
  final Alignment alignment;
  final double? widthFactor;
  final double? heightFactor;

  const Align({super.key, this.widthFactor, this.heightFactor, required this.alignment, required super.child});

  @override
  SingleChildWidgetInstance instantiate() => _AlignInstance(widget: this);
}

class _AlignInstance extends SingleChildWidgetInstance<Align> {
  _AlignInstance({required super.widget});

  @override
  set widget(Align value) {
    if (widget.widthFactor == value.widthFactor &&
        widget.heightFactor == value.heightFactor &&
        widget.alignment == value.alignment) {
      return;
    }

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final widthFactor = widget.widthFactor, heightFactor = widget.heightFactor;
    final alignment = widget.alignment;

    final childSize = child.layout(constraints.asLoose());
    final selfSize = Size(
      widthFactor != null || !constraints.hasBoundedWidth ? childSize.width * (widthFactor ?? 1) : constraints.maxWidth,
      heightFactor != null || !constraints.hasBoundedHeight
          ? childSize.height * (heightFactor ?? 1)
          : constraints.maxHeight,
    ).constrained(constraints);

    final (childX, childY) = alignment.align(selfSize, childSize);
    child.transform.x = childX;
    child.transform.y = childY;

    transform.setSize(selfSize);
  }
}

// ---

class Panel extends OptionalChildInstanceWidget {
  final Color color;
  final double cornerRadius;
  final double? outlineThickness;

  const Panel({super.key, required this.color, this.cornerRadius = 0.0, this.outlineThickness, super.child});

  @override
  OptionalChildWidgetInstance instantiate() => _PanelInstance(widget: this);
}

class _PanelInstance extends OptionalChildWidgetInstance<Panel> with OptionalShrinkWrapLayout {
  _PanelInstance({required super.widget});

  @override
  void draw(DrawContext ctx) {
    final cornerRadius = widget.cornerRadius;
    if (cornerRadius <= 1 && widget.outlineThickness == null) {
      ctx.primitives.rect(transform.width, transform.height, widget.color, ctx.transform, ctx.projection);
    } else {
      ctx.primitives.roundedRect(
        transform.width,
        transform.height,
        cornerRadius,
        widget.color,
        ctx.transform,
        ctx.projection,
        outlineThickness: widget.outlineThickness,
      );
    }

    super.draw(ctx);
  }
}

// ---

typedef CustomDrawFunction = void Function(DrawContext ctx, WidgetTransform transform);

class CustomDraw extends LeafInstanceWidget {
  final CustomDrawFunction drawFunction;

  CustomDraw({super.key, required this.drawFunction});

  @override
  CustomDrawInstance instantiate() => CustomDrawInstance(widget: this);
}

class CustomDrawInstance extends LeafWidgetInstance<CustomDraw> {
  CustomDrawInstance({required super.widget});

  @override
  void doLayout(Constraints constraints) {
    final size = constraints.minSize;
    transform.setSize(size);
  }

  @override
  void draw(DrawContext ctx) => widget.drawFunction(ctx, transform);
}

// ---

class MouseArea extends SingleChildInstanceWidget {
  final void Function(double x, double y)? clickCallback;
  final void Function()? enterCallback;
  final void Function()? exitCallback;
  final void Function()? dragStartCallback;
  final void Function(double x, double y, double dx, double dy)? dragCallback;
  final void Function()? dragEndCallback;
  final void Function(double horizontal, double vertical)? scrollCallback;
  final CursorStyle? cursorStyle;

  const MouseArea({
    super.key,
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.dragStartCallback,
    this.dragCallback,
    this.dragEndCallback,
    this.scrollCallback,
    this.cursorStyle,
    required super.child,
  });

  @override
  MouseAreaInstance instantiate() => MouseAreaInstance(widget: this);
}

class MouseAreaInstance extends SingleChildWidgetInstance<MouseArea> with ShrinkWrapLayout, MouseListener {
  MouseAreaInstance({required super.widget});

  @override
  CursorStyle? get cursorStyle => widget.cursorStyle;

  @override
  bool onMouseDown(double x, double y) => (widget.clickCallback?..call(x, y)) != null || widget.dragCallback != null;

  @override
  void onMouseEnter() => widget.enterCallback?.call();

  @override
  void onMouseExit() => widget.exitCallback?.call();

  @override
  void onMouseDragStart() => widget.dragStartCallback?.call();

  @override
  void onMouseDrag(double x, double y, double dx, double dy) => widget.dragCallback?.call(x, y, dx, dy);

  @override
  void onMouseDragEnd() => widget.dragEndCallback?.call();

  @override
  bool onMouseScroll(double x, double y, double horizontal, double vertical) =>
      (widget.scrollCallback?..call(horizontal, vertical)) != null;
}

// ---

class KeyboardInput extends SingleChildInstanceWidget {
  final void Function(int keyCode, int modifiers)? keyDownCallback;
  final void Function(int keyCode, int modifiers)? keyUpCallback;
  final void Function(int charCode, int modifiers)? charCallback;
  final void Function()? focusGainedCallback;
  final void Function()? focusLostCallback;

  const KeyboardInput({
    super.key,
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    required super.child,
  });

  @override
  KeyboardInputInstance instantiate() => KeyboardInputInstance(widget: this);
}

class KeyboardInputInstance extends SingleChildWidgetInstance<KeyboardInput> with ShrinkWrapLayout, KeyboardListener {
  bool _focused = false;

  KeyboardInputInstance({required super.widget});

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

// ---

class Gradient extends OptionalChildInstanceWidget {
  final Color startColor;
  final Color endColor;
  final double position;
  final double size;
  final double angle;

  const Gradient({
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
  GradientInstance({required super.widget});

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

// ---

class Transform extends SingleChildInstanceWidget {
  final Matrix4 matrix;

  Transform({super.key, required this.matrix, required super.child});

  @override
  TransformInstance instantiate() => TransformInstance(widget: this);
}

class TransformInstance extends SingleChildWidgetInstance<Transform> with ShrinkWrapLayout {
  TransformInstance({required super.widget}) {
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

// ---

class LayoutAfterTransform extends SingleChildInstanceWidget {
  const LayoutAfterTransform({super.key, required super.child});

  @override
  LayoutAfterTransformInstance instantiate() => LayoutAfterTransformInstance(widget: this);
}

class LayoutAfterTransformInstance<LayoutAfterTransform> extends SingleChildWidgetInstance {
  LayoutAfterTransformInstance({required super.widget});

  @override
  void doLayout(Constraints constraints) {
    child.transform.x = 0;
    child.transform.y = 0;

    child.layout(constraints);

    final size = Size(child.transform.aabb.width, child.transform.aabb.height).constrained(constraints);

    child.transform.x = -child.transform.aabb.min.x;
    child.transform.y = -child.transform.aabb.min.y;

    transform.width = size.width;
    transform.height = size.height;
  }
}

// ---

class Clip extends SingleChildInstanceWidget {
  const Clip({super.key, required super.child});

  @override
  ClipInstance instantiate() => ClipInstance(widget: this);
}

//TODO support nested clips
class ClipInstance extends SingleChildWidgetInstance<Clip> with ShrinkWrapLayout {
  ClipInstance({required super.widget});

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

// ---

class StencipClip extends SingleChildInstanceWidget {
  const StencipClip({super.key, required super.child});

  @override
  StencilClipInstance instantiate() => StencilClipInstance(widget: this);
}

class StencilClipInstance extends SingleChildWidgetInstance with ShrinkWrapLayout {
  static final _framebufferByWindow = <Window, GlFramebuffer>{};
  static var stencilValue = 0;

  StencilClipInstance({required super.widget});

  @override
  void draw(DrawContext ctx) {
    stencilValue++;

    final window = ctx.renderContext.window;
    final framebuffer =
        _framebufferByWindow[window] ??=
            (() {
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

// ---

typedef WidgetBuilder = Widget Function(BuildContext context);

class Builder extends Widget {
  final WidgetBuilder builder;

  const Builder({super.key, required this.builder});

  @override
  WidgetProxy proxy() => _BuilderProxy(this);
}

class _BuilderProxy extends ComposedProxy with SingleChildWidgetProxy {
  _BuilderProxy(Builder super.widget);

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
    rebuild();
  }

  @override
  void updateWidget(covariant Widget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    super.doRebuild();
    child = refreshChild(child, (widget as Builder).builder(this), slot);
  }
}

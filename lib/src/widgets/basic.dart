import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:vector_math/vector_math.dart';

import '../../glfw.dart';
import '../context.dart';
import '../core/constraints.dart';
import '../core/cursors.dart';
import '../core/key_modifiers.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'flex.dart';

typedef VoidCallback = void Function();

// ---

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

  static void _visitor(Flexible widget, WidgetInstance instance) {
    if (instance.parentData case FlexParentData data) {
      data.flexFactor = widget.flexFactor;
    } else {
      instance.parentData = FlexParentData(widget.flexFactor);
    }

    instance.markNeedsLayout();
  }

  @override
  VisitorProxy proxy() => VisitorProxy<Flexible>(this, _visitor);
}

class HitTestTrap extends VisitorWidget {
  const HitTestTrap({super.key, required super.child});

  static void _visitor(HitTestTrap _, WidgetInstance instance) {
    instance.flags += InstanceFlags.hitTestBoundary;
  }

  @override
  VisitorProxy proxy() => VisitorProxy<HitTestTrap>(this, _visitor);
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

  @override
  double measureIntrinsicWidth(double height) => (child?.measureIntrinsicWidth(height) ?? 0) + widget.insets.horizontal;

  @override
  double measureIntrinsicHeight(double width) => (child?.measureIntrinsicHeight(width) ?? 0) + widget.insets.vertical;

  @override
  double? measureBaselineOffset() {
    final childBaseline = child?.measureBaselineOffset();
    if (childBaseline == null) return null;

    return childBaseline + widget.insets.top;
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

class Constrain extends SingleChildInstanceWidget with ConstraintWidget {
  @override
  final Constraints constraints;

  const Constrain({super.key, required this.constraints, required super.child});

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

  @override
  double measureIntrinsicWidth(double height) => child.measureIntrinsicWidth(height);

  @override
  double measureIntrinsicHeight(double width) => child.measureIntrinsicHeight(width);

  @override
  double? measureBaselineOffset() => child.measureBaselineOffset();
}

// ---

// TODO: this should live somewhere more generic
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
    alignHorizontal(space.width, object.width),
    alignVertical(space.height, object.height),
  );

  double alignHorizontal(double space, double object) => ((space - object) * horizontal).floorToDouble();
  double alignVertical(double space, double object) => ((space - object) * vertical).floorToDouble();

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

  @override
  double measureIntrinsicWidth(double height) => child.measureIntrinsicWidth(height) * (widget.widthFactor ?? 1);

  @override
  double measureIntrinsicHeight(double width) => child.measureIntrinsicHeight(width) * (widget.heightFactor ?? 1);

  @override
  double? measureBaselineOffset() => child.measureBaselineOffset();
}

// ---

class Panel extends OptionalChildInstanceWidget {
  final Color color;
  final CornerRadius cornerRadius;
  final double? outlineThickness;

  const Panel({
    super.key,
    required this.color,
    this.cornerRadius = const CornerRadius(),
    this.outlineThickness,
    super.child,
  });

  @override
  OptionalChildWidgetInstance instantiate() => PanelInstance(widget: this);
}

class PanelInstance extends OptionalChildWidgetInstance<Panel> with OptionalShrinkWrapLayout {
  PanelInstance({required super.widget});

  @override
  void draw(DrawContext ctx) {
    final cornerRadius = widget.cornerRadius;
    if (cornerRadius.isVanishing && widget.outlineThickness == null) {
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

  @override
  double measureIntrinsicWidth(double height) => 0;

  @override
  double measureIntrinsicHeight(double width) => 0;

  @override
  double? measureBaselineOffset() => null;
}

// ---

class MouseArea extends SingleChildInstanceWidget {
  final bool Function(double x, double y, int button)? clickCallback;
  final bool Function(double x, double y, int button)? unClickCallback;
  final VoidCallback? enterCallback;
  final void Function(double toX, double toY)? moveCallback;
  final VoidCallback? exitCallback;
  final void Function(int button)? dragStartCallback;
  final void Function(double x, double y, double dx, double dy)? dragCallback;
  final VoidCallback? dragEndCallback;
  final bool Function(double horizontal, double vertical)? scrollCallback;
  final CursorStyle? Function(double x, double y)? cursorStyleSupplier;

  MouseArea({
    super.key,
    this.clickCallback,
    this.unClickCallback,
    this.enterCallback,
    this.moveCallback,
    this.exitCallback,
    this.dragStartCallback,
    this.dragCallback,
    this.dragEndCallback,
    this.scrollCallback,
    CursorStyle? cursorStyle,
    CursorStyle? Function(double x, double y)? cursorStyleSupplier,
    required super.child,
  }) : cursorStyleSupplier = (cursorStyleSupplier ?? (_, _) => cursorStyle);

  @override
  MouseAreaInstance instantiate() => MouseAreaInstance(widget: this);
}

// in this process, likely also build a higher-level abstraction for
// handling user input
class MouseAreaInstance extends SingleChildWidgetInstance<MouseArea> with ShrinkWrapLayout, MouseListener {
  MouseAreaInstance({required super.widget});

  @override
  CursorStyle? cursorStyleAt(double x, double y) => widget.cursorStyleSupplier?.call(x, y);

  @override
  bool onMouseDown(double x, double y, int button) =>
      (widget.clickCallback?.call(x, y, button) ?? false) || widget.dragCallback != null;

  @override
  bool onMouseUp(double x, double y, int button) => widget.unClickCallback?.call(x, y, button) ?? false;

  @override
  void onMouseEnter() => widget.enterCallback?.call();

  @override
  void onMouseMove(double toX, double toY) => widget.moveCallback?.call(toX, toY);

  @override
  void onMouseExit() => widget.exitCallback?.call();

  @override
  void onMouseDragStart(int button) => widget.dragStartCallback?.call(button);

  @override
  void onMouseDrag(double x, double y, double dx, double dy) => widget.dragCallback?.call(x, y, dx, dy);

  @override
  void onMouseDragEnd() => widget.dragEndCallback?.call();

  @override
  bool onMouseScroll(double x, double y, double horizontal, double vertical) =>
      widget.scrollCallback?.call(horizontal, vertical) ?? false;
}

// ---

class KeyboardInput extends SingleChildInstanceWidget {
  final bool Function(int keyCode, KeyModifiers modifiers)? keyDownCallback;
  final bool Function(int keyCode, KeyModifiers modifiers)? keyUpCallback;
  final bool Function(int charCode, KeyModifiers modifiers)? charCallback;
  final VoidCallback? focusGainedCallback;
  final VoidCallback? focusLostCallback;

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
  bool onKeyDown(int keyCode, KeyModifiers modifiers) => widget.keyDownCallback?.call(keyCode, modifiers) ?? false;

  @override
  bool onKeyUp(int keyCode, KeyModifiers modifiers) => widget.keyUpCallback?.call(keyCode, modifiers) ?? false;

  @override
  bool onChar(int charCode, KeyModifiers modifiers) => widget.charCallback?.call(charCode, modifiers) ?? false;

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

extension type const ActionTrigger._(({Set<int> mouseButtons, Set<int> keyCodes, KeyModifiers keyModifiers}) _value) {
  const ActionTrigger({
    Set<int> mouseButtons = const {},
    Set<int> keyCodes = const {},
    KeyModifiers keyModifiers = KeyModifiers.none,
  }) : this._((mouseButtons: mouseButtons, keyCodes: keyCodes, keyModifiers: keyModifiers));

  bool isTriggeredByMouseButton(int button) => _value.mouseButtons.contains(button);
  bool isTriggeredByKeyCode(int code, KeyModifiers modifiers) =>
      _value.keyCodes.contains(code) && _value.keyModifiers == modifiers;

  static const click = ActionTrigger(
    mouseButtons: {glfwMouseButtonLeft},
    keyCodes: {glfwKeySpace, glfwKeyEnter, glfwKeyKpEnter},
  );

  static const secondaryClick = ActionTrigger(
    mouseButtons: {glfwMouseButtonRight},
    keyCodes: {glfwKeySpace, glfwKeyEnter, glfwKeyKpEnter},
    keyModifiers: KeyModifiers(glfwModShift),
  );
}

class Actions extends StatefulWidget {
  final VoidCallback? enterCallback;
  final VoidCallback? exitCallback;
  final CursorStyle? cursorStyle;

  final VoidCallback? focusGainedCallback;
  final VoidCallback? focusLostCallback;

  final Map<List<ActionTrigger>, VoidCallback> actions;

  final Widget child;

  const Actions({
    super.key,
    this.enterCallback,
    this.exitCallback,
    this.cursorStyle,
    this.focusGainedCallback,
    this.focusLostCallback,
    required this.actions,
    required this.child,
  });

  Actions.click({
    super.key,
    this.enterCallback,
    this.exitCallback,
    this.cursorStyle,
    this.focusGainedCallback,
    this.focusLostCallback,
    required VoidCallback? onClick,
    required this.child,
  }) : actions = {
         if (onClick != null) const [ActionTrigger.click]: onClick,
       };

  @override
  WidgetState<Actions> createState() => ActionsState();
}

class ActionsState extends WidgetState<Actions> {
  List<_ActionSequence> _sequences = [];

  final List<_ActionSequence> _queuedSequences = [];
  Timer? _dispatchTimer;

  @override
  void init() {
    _sequences = widget.actions.entries.map((e) => _ActionSequence(e.key, e.value)).toList();
  }

  // TODO: probably not ideal to rebuild this list every time
  @override
  void didUpdateWidget(Actions oldWidget) {
    _sequences = widget.actions.entries.map((e) => _ActionSequence(e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MouseArea(
      enterCallback: widget.enterCallback,
      exitCallback: widget.exitCallback,
      cursorStyle: widget.cursorStyle,
      clickCallback: (x, y, button) {
        return _stepActions((trigger) {
          return trigger.isTriggeredByMouseButton(button)
              ? _ActionTriggerResult.activated
              : _ActionTriggerResult.notActivated;
        });
      },
      child: KeyboardInput(
        focusGainedCallback: widget.focusGainedCallback,
        focusLostCallback: widget.focusLostCallback,
        keyDownCallback:
            (keyCode, modifiers) => _stepActions((trigger) {
              if (trigger.isTriggeredByKeyCode(keyCode, modifiers)) return _ActionTriggerResult.activated;

              return KeyModifiers.isModifier(keyCode)
                  ? _ActionTriggerResult.ignored
                  : _ActionTriggerResult.notActivated;
            }),
        child: widget.child,
      ),
    );
  }

  bool _stepActions(_ActionTriggerResult Function(ActionTrigger trigger) test) {
    // in case we currently have a dispatch queued, we
    // must cancel it *now* to avoid prematurely triggering
    // a dispatch before the user is done entering triggers
    _dispatchTimer?.cancel();

    // now, begin by stepping all sequences with current input and keeping
    // only the ones which didn't ignore it. this can lead to a few outcomes
    // for each sequence. to break it down:
    // - singular sequences:
    //   these can always step and, if so, will immediately complete
    // - non-singular sequences:
    //   whether these can step depends on their current state:
    //   - non-negative trigger index:
    //     if triggered, will step and potentially complete
    //     if not triggered, will not step and poison the trigger index
    //   - negative (poisoned) trigger index:
    //     will not step
    final steppedSequences =
        _sequences
            .map((e) => (sequence: e, step: e.step(test)))
            .whereNot((element) => element.step == _ActionSequenceStep.ignore)
            .toList();

    // next, get the sequence to treat as completed on this iteration - if any
    // - if multiple sequences completed, pick the first one
    // - always prioritize non-singular sequences over singular sequences.
    //   this is important, since the current trigger could both finish
    //   a non-singular sequence (user intent) and immediately complete a
    //   singular one (this would be an artifact)
    final completed = steppedSequences
        .where((element) => element.step == _ActionSequenceStep.complete)
        .fold<({_ActionSequence sequence, _ActionSequenceStep step})?>(null, (acc, element) {
          if (acc == null) return element;
          return acc.sequence.isSingular && !element.sequence.isSingular ? element : acc;
        });

    // if we have successfully resolved all ambiguity, that is,
    // every remaining (non-poisoned) sequence stepped to completion,
    // dispatch immediately
    if (steppedSequences.every((e) => e.step == _ActionSequenceStep.complete) && completed != null) {
      _dispatch(completedSequence: completed.sequence, runQueued: completed.sequence.isSingular);
      return true;
    } else {
      // otherwise, queue up the completed sequence (if any)
      // and queue dispatch after the maximum possible input delay

      if (completed != null) {
        // if the sequence we just complete is non-singular, clear
        // the queue - this is important, since otherwise we could duplicate
        // the respective events
        if (!completed.sequence.isSingular) {
          _queuedSequences.clear();
        }

        _queuedSequences.add(completed.sequence);
        completed.sequence.nextTriggerIndex = 0;
      }

      _dispatchTimer = Timer(_maxInputDelay, () => _dispatch(completedSequence: null, runQueued: true));

      return steppedSequences.isNotEmpty;
    }
  }

  void _dispatch({required _ActionSequence? completedSequence, required bool runQueued}) {
    if (runQueued) {
      for (final sequence in _queuedSequences) {
        sequence.callback();
      }
    }

    completedSequence?.callback();

    _queuedSequences.clear();
    for (final sequence in _sequences) {
      sequence.nextTriggerIndex = 0;
    }
  }

  static const _maxInputDelay = Duration(milliseconds: 250);
}

enum _ActionTriggerResult {
  /// the trigger was not activated by this input.
  /// non-singular sequences should posion
  notActivated,

  /// the trigger was activated by this input.
  /// sequences should step
  activated,

  /// the trigger entirely ignored this input.
  /// non-singular sequences should not poison
  /// and sequences should not step
  ignored,
}

enum _ActionSequenceStep { ignore, advance, complete }

class _ActionSequence {
  final List<ActionTrigger> triggers;
  final VoidCallback callback;

  /// whether this sequence is singular, i.e. it only has
  /// a single trigger and can be completed at any time
  final bool isSingular;

  int nextTriggerIndex = 0;

  _ActionSequence(this.triggers, this.callback) : isSingular = triggers.length == 1;

  /// step this sequence
  /// - if the sequence ignored the input, is poisoned or is completed, return [_ActionSequenceStep.ignore]
  /// - if the sequence activated its final trigger, return [_ActionSequenceStep.complete]
  /// - if the sequence activated an intermediate trigger, return [_ActionSequenceStep.advance]
  _ActionSequenceStep step(_ActionTriggerResult Function(ActionTrigger trigger) test) {
    if (nextTriggerIndex < 0 || nextTriggerIndex >= triggers.length) return _ActionSequenceStep.ignore;

    final result = test(triggers[nextTriggerIndex]);
    if (result == _ActionTriggerResult.activated) {
      nextTriggerIndex++;
      return nextTriggerIndex == triggers.length ? _ActionSequenceStep.complete : _ActionSequenceStep.advance;
    } else if (!isSingular && result == _ActionTriggerResult.notActivated) {
      // only poison non-singular sequences. this is important, because
      // otherwise we could incorrectly swallow a singular sequence completed
      // just after the first trigger of a non-singular sequence
      nextTriggerIndex = -1;
    }

    return _ActionSequenceStep.ignore;
  }
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
    if (widget.matrix == value.matrix) {
      (transform as CustomWidgetTransform).recompute();
      return;
    }

    super.widget = value;
    (transform as CustomWidgetTransform).matrix = widget.matrix;

    markNeedsLayout();
  }

  @override
  CustomWidgetTransform createTransform() => CustomWidgetTransform();
}

// ---

class SizeToAABB extends SingleChildInstanceWidget {
  const SizeToAABB({super.key, required super.child});

  @override
  SizeToAABBInstance instantiate() => SizeToAABBInstance(widget: this);
}

class SizeToAABBInstance extends SingleChildWidgetInstance<SizeToAABB> {
  SizeToAABBInstance({required super.widget});

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

  // TODO: these implementations are not correct

  @override
  double measureIntrinsicWidth(double height) => child.measureIntrinsicWidth(height);

  @override
  double measureIntrinsicHeight(double width) => child.measureIntrinsicHeight(width);

  @override
  double? measureBaselineOffset() => child.measureBaselineOffset();
}

// ---

class Clip extends SingleChildInstanceWidget {
  final bool clipHitTest;
  final bool clipDrawing;

  const Clip({super.key, this.clipHitTest = true, this.clipDrawing = true, required super.child});

  @override
  ClipInstance instantiate() => ClipInstance(widget: this);
}

//TODO support nested clips
class ClipInstance extends SingleChildWidgetInstance<Clip> with ShrinkWrapLayout {
  ClipInstance({required super.widget});

  @override
  void hitTest(double x, double y, HitTestState state) {
    if (widget.clipHitTest && (x < 0 || x > transform.width || y < 0 || y > transform.height)) {
      return;
    }

    super.hitTest(x, y, state);
  }

  @override
  void draw(DrawContext ctx) {
    if (!widget.clipDrawing) {
      super.draw(ctx);
      return;
    }

    final scissorBox = Aabb3.minMax(Vector3.zero(), Vector3(transform.width, transform.height, 0))
      ..transform(ctx.transform);
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

class StencilClip extends SingleChildInstanceWidget {
  const StencilClip({super.key, required super.child});

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

class Builder extends StatelessWidget {
  final WidgetBuilder builder;

  const Builder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context);
}

// ---

class Visibility extends SingleChildInstanceWidget {
  final bool visible;
  final bool reportSize;

  Visibility({this.visible = false, this.reportSize = false, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _VisibilityInstance(widget: this);
}

class _VisibilityInstance extends SingleChildWidgetInstance<Visibility> {
  _VisibilityInstance({required super.widget});

  @override
  set widget(Visibility value) {
    if (widget.visible == value.visible && widget.reportSize == value.reportSize) return;

    super.widget = value;
    markNeedsLayout();
  }

  @override
  void doLayout(Constraints constraints) {
    final childSize = child.layout(constraints);
    if (widget.visible || widget.reportSize) {
      transform.setSize(childSize);
    } else {
      transform.setSize(Size.zero);
    }
  }

  @override
  double measureIntrinsicWidth(double height) =>
      widget.visible || widget.reportSize ? child.measureIntrinsicWidth(height) : 0;

  @override
  double measureIntrinsicHeight(double width) =>
      widget.visible || widget.reportSize ? child.measureIntrinsicHeight(width) : 0;

  @override
  double? measureBaselineOffset() => widget.visible || widget.reportSize ? child.measureBaselineOffset() : null;

  @override
  void draw(DrawContext ctx) {
    if (!widget.visible) return;
    super.draw(ctx);
  }

  @override
  void hitTest(double x, double y, HitTestState state) {
    if (!widget.visible) return;
    super.hitTest(x, y, state);
  }
}

// ---

class IntrinsicWidth extends SingleChildInstanceWidget {
  IntrinsicWidth({super.key, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _IntrinsicWidthInstance(widget: this);
}

class _IntrinsicWidthInstance extends SingleChildWidgetInstance {
  _IntrinsicWidthInstance({required super.widget});

  @override
  void doLayout(Constraints constraints) {
    final childSize = child.getIntrinsicWidth(constraints.maxHeight);

    final childConstraints = Constraints(
      childSize,
      constraints.minHeight,
      childSize,
      constraints.maxHeight,
    ).respecting(constraints);

    transform.setSize(child.layout(childConstraints));
  }

  @override
  double measureIntrinsicWidth(double height) => child.measureIntrinsicWidth(height);

  @override
  double measureIntrinsicHeight(double width) => child.measureIntrinsicHeight(width);

  @override
  double? measureBaselineOffset() => child.measureBaselineOffset();
}

// ---

class IntrinsicHeight extends SingleChildInstanceWidget {
  IntrinsicHeight({super.key, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _IntrinsicHeightInstance(widget: this);
}

class _IntrinsicHeightInstance extends SingleChildWidgetInstance {
  _IntrinsicHeightInstance({required super.widget});

  @override
  void doLayout(Constraints constraints) {
    final childSize = child.getIntrinsicHeight(constraints.maxWidth);

    final childConstraints = Constraints(
      constraints.minWidth,
      childSize,
      constraints.maxWidth,
      childSize,
    ).respecting(constraints);

    transform.setSize(child.layout(childConstraints));
  }

  @override
  double measureIntrinsicWidth(double height) => child.measureIntrinsicWidth(height);

  @override
  double measureIntrinsicHeight(double width) => child.measureIntrinsicHeight(width);

  @override
  double? measureBaselineOffset() => child.measureBaselineOffset();
}

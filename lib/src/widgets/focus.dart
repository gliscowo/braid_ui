import 'dart:collection';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../../glfw.dart';
import '../core/key_modifiers.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'inspector.dart';
import 'stack.dart';

mixin FocusNode<F extends Focusable> on WidgetState<F> {
  FocusNode? get parent;
  Iterable<FocusNode> get ancestors sync* {
    var ancestor = parent;
    while (ancestor != null) {
      yield ancestor;
      ancestor = ancestor.parent;
    }
  }

  int get depth;

  // void addChild(FocusNode child) => focusChildren.add(child);
  // void removeChild(FocusNode child) => focusChildren.remove(child);

  bool onKeyDown(int keyCode, KeyModifiers modifiers) {
    return widget.keyDownCallback?.call(keyCode, modifiers) ?? false;
  }

  bool onKeyUp(int keyCode, KeyModifiers modifiers) {
    return widget.keyUpCallback?.call(keyCode, modifiers) ?? false;
  }

  bool onChar(int charCode, KeyModifiers modifiers) {
    return widget.charCallback?.call(charCode, modifiers) ?? false;
  }

  void requestPrimaryFocus();

  // ---

  static FocusNode? maybeOf(BuildContext context) => context.getAncestor<_FocusNodeProvider<FocusNode>>()?.node;
}

class _FocusNodeProvider<F extends FocusNode> extends InheritedWidget {
  final F node;
  _FocusNodeProvider({required this.node, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

// ---

class Focusable extends StatefulWidget {
  final bool Function(int keyCode, KeyModifiers modifiers)? keyDownCallback;
  final bool Function(int keyCode, KeyModifiers modifiers)? keyUpCallback;
  final bool Function(int charCode, KeyModifiers modifiers)? charCallback;
  final Callback? focusGainedCallback;
  final Callback? focusLostCallback;
  final bool autoFocus;

  final Widget child;

  const Focusable({
    super.key,
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    this.autoFocus = false,
    required this.child,
  });

  @override
  WidgetState<Focusable> createState() => _FocusableState();
}

class _FocusableState<F extends Focusable> extends WidgetState<F> with FocusNode {
  @override
  late final FocusNode parent;
  late final _FocusScopeState? scope;

  @override
  late final int depth;

  @override
  void requestPrimaryFocus() {
    scope?.moveFocus(this);
  }

  @override
  void init() {
    parent = FocusNode.maybeOf(context)!;
    scope = _FocusScopeState.maybeOf(context)?..onFocusableCreated(this);

    depth = parent.depth + 1;

    if (widget.autoFocus) {
      requestPrimaryFocus();
    }
  }

  @override
  void dispose() {
    scope?.onFocusableDisposed(this);
  }

  @protected
  void onClick() {
    requestPrimaryFocus();
  }

  @override
  Widget build(BuildContext context) {
    return FocusClickArea(
      clickCallback: onClick,
      child: _FocusNodeProvider<FocusNode>(node: this, child: widget.child),
    );
  }
}

// ---

class FocusScope extends Focusable {
  const FocusScope({
    super.key,
    super.keyDownCallback,
    super.keyUpCallback,
    super.charCallback,
    super.focusGainedCallback,
    super.focusLostCallback,
    super.autoFocus = false,
    required super.child,
  });

  @override
  WidgetState<FocusScope> createState() => _FocusScopeState();
}

class _FocusScopeState extends _FocusableState<FocusScope> {
  List<FocusNode> focused = [];

  final List<FocusNode> descendants = [];
  final Queue<_FocusScopeState> previouslyFocusedScopes = Queue();

  @override
  bool onKeyDown(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant.onKeyDown(keyCode, modifiers)) {
        return true;
      }
    }

    if (keyCode == glfwKeyTab) {
      final currentFocusIdx = focused.isNotEmpty ? descendants.indexOf(focused.first) : null;
      final nextFocusIdx =
          (modifiers.shift
              ? currentFocusIdx != null
                    ? currentFocusIdx - 1
                    : descendants.length - 1
              : currentFocusIdx != null
              ? currentFocusIdx + 1
              : 0) %
          descendants.length;

      moveFocus(descendants[nextFocusIdx]);
      return true;
    }

    return super.onKeyDown(keyCode, modifiers);
  }

  @override
  bool onKeyUp(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant.onKeyUp(keyCode, modifiers)) {
        return true;
      }
    }

    return super.onKeyUp(keyCode, modifiers);
  }

  @override
  bool onChar(int charCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant.onChar(charCode, modifiers)) {
        return true;
      }
    }

    return super.onChar(charCode, modifiers);
  }

  @override
  void onClick() {
    super.onClick();
    moveFocus(null);
  }

  void moveFocus(FocusNode? to) {
    scope?.moveFocus(this);
    final nowFocused = to != null
        // TODO: this takeWhile is cringe
        ? [to].followedBy(to.ancestors).takeWhile((value) => value != this).toList()
        : <FocusNode>[];

    for (final node in nowFocused) {
      if (focused.contains(node)) {
        focused.remove(node);
      } else {
        node.widget.focusGainedCallback?.call();
      }
    }

    for (final noLongerFocused in focused) {
      noLongerFocused.widget.focusLostCallback?.call();
    }

    if (focused.firstOrNull case _FocusScopeState scope when !nowFocused.contains(scope)) {
      previouslyFocusedScopes.add(scope);
    }

    focused = nowFocused;
  }

  void onFocusableCreated(FocusNode descendant) {
    descendants.add(descendant);
  }

  void onFocusableDisposed(FocusNode descendant) {
    if (descendant == focused.firstOrNull && previouslyFocusedScopes.isNotEmpty) {
      moveFocus(previouslyFocusedScopes.removeLast());
    }

    descendants.remove(descendant);
    focused.remove(descendant);
    previouslyFocusedScopes.removeWhere((element) => element == descendant);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StackBase(
          child: _FocusNodeProvider<_FocusScopeState>(node: this, child: super.build(context)),
        ),
        CustomDraw(
          drawFunction: (ctx, transform) {
            if (focused.isEmpty) return;

            final instance = focused.first.context.instance!;
            final transform = instance.parent!.computeTransformFrom(ancestor: context.instance)..invert();

            final box = Aabb3.copy(instance.transform.aabb)..transform(transform);
            ctx.transform.scope((mat4) {
              mat4.translateByVector3(box.min);
              ctx.primitives.roundedRect(
                box.width,
                box.height,
                const CornerRadius.all(2.5),
                Color.ofHsv(focused.first.depth / 8 % 1, .75, 1),
                ctx.transform,
                ctx.projection,
                outlineThickness: 1,
              );
            });
          },
        ),
      ],
    );
  }

  // ---

  static _FocusScopeState? maybeOf(BuildContext context) =>
      context.getAncestor<_FocusNodeProvider<_FocusScopeState>>()?.node;
}

// ---

typedef KeyDownEvent = ({int keyCode, KeyModifiers modifiers});
typedef KeyUpEvent = ({int keyCode, KeyModifiers modifiers});
typedef CharEvent = ({int charCode, KeyModifiers modifiers});

class RootFocusScope extends Focusable {
  final Stream<KeyDownEvent> onKeyDown;
  final Stream<KeyUpEvent> onKeyUp;
  final Stream<CharEvent> onChar;

  RootFocusScope({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
    required this.onChar,
    required super.child,
  });

  @override
  WidgetState<RootFocusScope> createState() => _RootFocusScopeState();
}

class _RootFocusScopeState extends WidgetState<RootFocusScope> with FocusNode, StreamListenerState {
  @override
  FocusNode? get parent => null;

  @override
  final int depth = 0;

  @override
  void requestPrimaryFocus() {}

  late _FocusScopeState scope;

  @override
  void init() {
    streamListen((widget) => widget.onKeyDown, (event) => scope.onKeyDown(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onKeyUp, (event) => scope.onKeyUp(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onChar, (event) => scope.onChar(event.charCode, event.modifiers));
  }

  @override
  Widget build(BuildContext context) {
    return _FocusNodeProvider<FocusNode>(
      node: this,
      child: FocusScope(
        child: Builder(
          builder: (context) {
            scope = _FocusScopeState.maybeOf(context)!;
            return widget.child;
          },
        ),
      ),
    );
  }
}

// ---

class FocusClickArea extends SingleChildInstanceWidget {
  final Callback clickCallback;
  FocusClickArea({super.key, required this.clickCallback, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => FocusClickAreaInstance(widget: this);
}

class FocusClickAreaInstance extends SingleChildWidgetInstance<FocusClickArea> with ShrinkWrapLayout {
  FocusClickAreaInstance({required super.widget});
}

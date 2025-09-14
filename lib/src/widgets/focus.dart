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

// TODO:
//  - track primary focus, ideally store on root scope
//  - correctly fire unfocus and refocus events for the descendants of a scope

class _FocusStateProvider<F extends FocusableState> extends InheritedWidget {
  final F state;
  _FocusStateProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

// ---

class FocusPolicy extends InheritedWidget {
  final bool clickFocus;
  const FocusPolicy({super.key, required this.clickFocus, required super.child});

  @override
  bool mustRebuildDependents(covariant FocusPolicy newWidget) => newWidget.clickFocus != clickFocus;

  // ---

  static FocusPolicy of(BuildContext context) => context.dependOnAncestor<FocusPolicy>()!;
}

class Focusable extends StatefulWidget {
  final bool Function(int keyCode, KeyModifiers modifiers)? keyDownCallback;
  final bool Function(int keyCode, KeyModifiers modifiers)? keyUpCallback;
  final bool Function(int charCode, KeyModifiers modifiers)? charCallback;
  final Callback? focusGainedCallback;
  final Callback? focusLostCallback;
  final bool autoFocus;
  final bool? clickFocus;

  final Widget child;

  const Focusable({
    super.key,
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    this.autoFocus = false,
    this.clickFocus,
    required this.child,
  });

  @override
  WidgetState<Focusable> createState() => FocusableState();

  // ---

  static FocusableState? maybeOf(BuildContext context) =>
      context.getAncestor<_FocusStateProvider<FocusableState>>()?.state;
  static FocusableState of(BuildContext context) => maybeOf(context)!;
}

class FocusableState<F extends Focusable> extends WidgetState<F> {
  late final FocusableState? _parent;
  late final _FocusScopeState? _scope;

  late final int depth;

  void requestFocus() {
    _scope?.moveFocus(this);
  }

  @protected
  void _onClick() {
    if (widget.clickFocus ?? context.getAncestor<FocusPolicy>()!.clickFocus) {
      requestFocus();
    }
  }

  bool _onKeyDown(int keyCode, KeyModifiers modifiers) {
    return widget.keyDownCallback?.call(keyCode, modifiers) ?? false;
  }

  bool _onKeyUp(int keyCode, KeyModifiers modifiers) {
    return widget.keyUpCallback?.call(keyCode, modifiers) ?? false;
  }

  bool _onChar(int charCode, KeyModifiers modifiers) {
    return widget.charCallback?.call(charCode, modifiers) ?? false;
  }

  Iterable<FocusableState> get _scopedAncestors sync* {
    var ancestor = _parent;
    while (ancestor != null && ancestor is! _FocusScopeState) {
      yield ancestor;
      ancestor = ancestor._parent;
    }
  }

  @override
  void init() {
    _parent = Focusable.maybeOf(context);
    _scope = _FocusScopeState.maybeOf(context);

    depth = (_parent?.depth ?? -1) + 1;

    if (widget.autoFocus) {
      requestFocus();
    }
  }

  @override
  void dispose() {
    _scope?.onFocusableDisposed(this);
  }

  @override
  Widget build(BuildContext context) {
    return FocusClickArea(
      clickCallback: _onClick,
      child: _FocusStateProvider<FocusableState>(state: this, child: widget.child),
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
  StatefulProxy proxy() => _FocusScopeProxy(this);

  @override
  WidgetState<FocusScope> createState() => _FocusScopeState();
}

class _FocusScopeProxy extends StatefulProxy {
  _FocusScopeProxy(FocusScope super.widget);

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
    (state as _FocusScopeState).collectDescendants = () {
      final descendants = <FocusableState>[];
      visitChildren((child) => _collectFocusDescendants(child, descendants));

      return descendants;
    };
  }

  static void _collectFocusDescendants(WidgetProxy proxy, List<FocusableState> into) {
    if (proxy case StatefulProxy(state: FocusableState state)) {
      into.add(state);

      if (state is _FocusScopeState) {
        return;
      }
    }

    proxy.visitChildren((child) {
      _collectFocusDescendants(child, into);
    });
  }
}

class _FocusScopeState extends FocusableState<FocusScope> {
  List<FocusableState> focused = [];

  late List<FocusableState> Function() collectDescendants;
  final Queue<_FocusScopeState> previouslyFocusedScopes = Queue();

  @override
  bool _onKeyDown(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant._onKeyDown(keyCode, modifiers)) {
        return true;
      }
    }

    if (keyCode == glfwKeyTab) {
      final descendants = collectDescendants();

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

    return super._onKeyDown(keyCode, modifiers);
  }

  @override
  bool _onKeyUp(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant._onKeyUp(keyCode, modifiers)) {
        return true;
      }
    }

    return super._onKeyUp(keyCode, modifiers);
  }

  @override
  bool _onChar(int charCode, KeyModifiers modifiers) {
    for (final descendant in focused) {
      if (descendant._onChar(charCode, modifiers)) {
        return true;
      }
    }

    return super._onChar(charCode, modifiers);
  }

  @override
  void _onClick() {
    super._onClick();
    moveFocus(null);
  }

  void moveFocus(FocusableState? to) {
    _scope?.moveFocus(this);
    final nowFocused = to != null ? [to].followedBy(to._scopedAncestors).toList() : <FocusableState>[];

    for (final state in nowFocused) {
      if (focused.contains(state)) {
        focused.remove(state);
      } else {
        state.widget.focusGainedCallback?.call();
      }
    }

    for (final noLongerFocused in focused) {
      noLongerFocused.widget.focusLostCallback?.call();
    }

    if (focused.firstOrNull case _FocusScopeState scope when !nowFocused.contains(scope)) {
      previouslyFocusedScopes.add(scope);
    } else if (nowFocused.firstOrNull is! _FocusScopeState) {
      previouslyFocusedScopes.clear();
    }

    focused = nowFocused;
  }

  void onFocusableDisposed(FocusableState descendant) {
    if (descendant == focused.firstOrNull && previouslyFocusedScopes.isNotEmpty) {
      moveFocus(previouslyFocusedScopes.removeLast());
    }

    focused.remove(descendant);
    previouslyFocusedScopes.removeWhere((element) => element == descendant);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StackBase(
          child: _FocusStateProvider<_FocusScopeState>(state: this, child: super.build(context)),
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
      context.getAncestor<_FocusStateProvider<_FocusScopeState>>()?.state;
}

// ---

typedef KeyDownEvent = ({int keyCode, KeyModifiers modifiers});
typedef KeyUpEvent = ({int keyCode, KeyModifiers modifiers});
typedef CharEvent = ({int charCode, KeyModifiers modifiers});

class RootFocusScope extends StatefulWidget {
  final Stream<KeyDownEvent> onKeyDown;
  final Stream<KeyUpEvent> onKeyUp;
  final Stream<CharEvent> onChar;
  final Widget child;

  RootFocusScope({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
    required this.onChar,
    required this.child,
  });

  @override
  WidgetState<RootFocusScope> createState() => _RootFocusScopeState();
}

class _RootFocusScopeState extends WidgetState<RootFocusScope> with StreamListenerState {
  late _FocusScopeState scope;

  @override
  void init() {
    streamListen((widget) => widget.onKeyDown, (event) => scope._onKeyDown(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onKeyUp, (event) => scope._onKeyUp(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onChar, (event) => scope._onChar(event.charCode, event.modifiers));
  }

  @override
  Widget build(BuildContext context) {
    return FocusPolicy(
      clickFocus: true,
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

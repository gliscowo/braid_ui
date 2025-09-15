import 'dart:collection';

import 'package:collection/collection.dart';

import '../core/key_modifiers.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'input_handling.dart';
import 'inspector.dart';
import 'stack.dart';

enum FocusLevel { base, highlight }

extension IsFocused on FocusLevel? {
  bool get isFocused => this != null;
}

class _FocusStateProvider<F extends FocusableState> extends InheritedWidget {
  final F state;
  final FocusLevel? level;
  _FocusStateProvider({required this.state, required this.level, required super.child});

  @override
  bool mustRebuildDependents(covariant _FocusStateProvider<F> newWidget) => newWidget.level != level;
}

enum FocusTraversalDirection { forwards, backwards }

class TraverseFocusIntent extends Intent {
  final FocusTraversalDirection direction;
  const TraverseFocusIntent(this.direction);
}

class TraverseFocusAction extends Action<TraverseFocusIntent> {
  const TraverseFocusAction();

  @override
  void invoke(BuildContext context, TraverseFocusIntent intent) =>
      Focusable.of(context).primaryFocus.traverseFocus(intent.direction);
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
  final void Function(FocusLevel? level)? focusLevelChangeCallback;
  final bool skipTraversal;
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
    this.focusLevelChangeCallback,
    this.skipTraversal = false,
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

  static FocusLevel? levelOf(BuildContext context) =>
      context.dependOnAncestor<_FocusStateProvider<FocusableState>>()?.level;
  static bool isFocused(BuildContext context) => levelOf(context).isFocused;
}

class FocusableState<F extends Focusable> extends WidgetState<F> {
  late final FocusableState? _parent;
  late final _FocusScopeState? _scope;
  FocusLevel? _level;

  late final int depth;

  FocusableState get primaryFocus => _scope?.primaryFocus ?? this;

  Iterable<FocusableState> get ancestors sync* {
    var ancestor = _parent;
    while (ancestor != null) {
      yield ancestor;
      ancestor = ancestor._parent;
    }
  }

  void requestFocus({FocusLevel level = FocusLevel.highlight}) {
    _scope?.updateFocus(this, level);
  }

  void unfocus() {
    _scope?.updateFocus(null, null);
  }

  void traverseFocus(FocusTraversalDirection direction) {
    _scope?.traverseFocus(direction);
  }

  void _onFocusChange(FocusLevel? newLevel) {
    assert(_level != newLevel, '_onFocusChange($newLevel) invoked on a state which is already at $newLevel');

    widget.focusLevelChangeCallback?.call(newLevel);
    if (!_level.isFocused && newLevel.isFocused) {
      widget.focusGainedCallback?.call();
    } else if (_level.isFocused && !newLevel.isFocused) {
      widget.focusLostCallback?.call();
    }

    _level = newLevel;
  }

  void _onClick() {
    if (widget.clickFocus ?? context.getAncestor<FocusPolicy>()!.clickFocus) {
      requestFocus(level: FocusLevel.base);
    }
  }

  bool _onKeyDown(int keyCode, KeyModifiers modifiers) {
    assert(_level.isFocused, '_onKeyDown invoked on a state which is not focused');
    return widget.keyDownCallback?.call(keyCode, modifiers) ?? false;
  }

  bool _onKeyUp(int keyCode, KeyModifiers modifiers) {
    assert(_level.isFocused, '_onKeyUp invoked on a state which is not focused');
    return widget.keyUpCallback?.call(keyCode, modifiers) ?? false;
  }

  bool _onChar(int charCode, KeyModifiers modifiers) {
    assert(_level.isFocused, '_onChar invoked on a state which is not focused');
    return widget.charCallback?.call(charCode, modifiers) ?? false;
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
      child: _FocusStateProvider<FocusableState>(state: this, level: _level, child: widget.child),
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
    super.focusLevelChangeCallback,
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

typedef _FocusEntry = ({FocusableState state, FocusLevel level});

class _FocusScopeState extends FocusableState<FocusScope> {
  late List<FocusableState> Function() collectDescendants;

  List<FocusableState> focusedDescendants = [];
  _FocusEntry? previousPrimaryFocus;

  final Queue<_FocusEntry> previouslyFocusedScopes = Queue();

  void updateFocus(FocusableState? primary, FocusLevel? level) {
    if (primary == focusedDescendants.firstOrNull && primary?._level == level) {
      return;
    }

    if (!_level.isFocused && primary != null) {
      requestFocus();
    }

    final nowFocused = primary != null
        ? [primary].followedBy(primary.ancestors.takeWhile((value) => value != this)).toList()
        : <FocusableState>[];

    for (final state in nowFocused) {
      if (focusedDescendants.contains(state)) {
        focusedDescendants.remove(state);

        if (state._level != level) {
          state._onFocusChange(level);
        }
      } else {
        state._onFocusChange(level);
      }
    }

    if (focusedDescendants.firstOrNull case _FocusScopeState scope when !nowFocused.contains(scope)) {
      previouslyFocusedScopes.add((state: scope, level: scope._level!));
    } else if (nowFocused.firstOrNull is! _FocusScopeState) {
      previouslyFocusedScopes.clear();
    }

    for (final noLongerFocused in focusedDescendants) {
      noLongerFocused._onFocusChange(null);
    }

    focusedDescendants = nowFocused;
  }

  void onFocusableDisposed(FocusableState descendant) {
    if (descendant == focusedDescendants.firstOrNull && previouslyFocusedScopes.isNotEmpty) {
      final (state: scope, :level) = previouslyFocusedScopes.removeLast();
      updateFocus(scope, level);
    }

    focusedDescendants.remove(descendant);
    previouslyFocusedScopes.removeWhere((element) => element.state == descendant);
  }

  @override
  FocusableState get primaryFocus {
    if (_level.isFocused) {
      var candidate = focusedDescendants.firstOrNull;
      if (candidate is _FocusScopeState) candidate = candidate.primaryFocus;

      return candidate ?? this;
    } else {
      return super.primaryFocus;
    }
  }

  @override
  void traverseFocus(FocusTraversalDirection direction) {
    final descendants = collectDescendants();

    final searchStartIdx = focusedDescendants.isNotEmpty
        ? descendants.indexOf(focusedDescendants.first)
        : (direction == FocusTraversalDirection.backwards ? 0 : -1);
    final offset = direction == FocusTraversalDirection.backwards ? -1 : 1;

    var nextFocusIdx = searchStartIdx;
    do {
      nextFocusIdx = (nextFocusIdx + offset) % descendants.length;
    } while (descendants[nextFocusIdx].widget.skipTraversal);

    updateFocus(descendants[nextFocusIdx], FocusLevel.highlight);
  }

  @override
  void _onFocusChange(FocusLevel? newLevel) {
    final previousLevel = _level;
    super._onFocusChange(newLevel);

    if (previousLevel.isFocused && !newLevel.isFocused) {
      final primaryFocus = focusedDescendants.firstOrNull;
      previousPrimaryFocus = primaryFocus != null ? (state: primaryFocus, level: primaryFocus._level!) : null;

      updateFocus(null, null);
    } else if (!previousLevel.isFocused && newLevel.isFocused && previousPrimaryFocus != null) {
      updateFocus(previousPrimaryFocus!.state, previousPrimaryFocus!.level);
    }
  }

  @override
  bool _onKeyDown(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focusedDescendants) {
      if (descendant._onKeyDown(keyCode, modifiers)) {
        return true;
      }
    }

    return super._onKeyDown(keyCode, modifiers);
  }

  @override
  bool _onKeyUp(int keyCode, KeyModifiers modifiers) {
    for (final descendant in focusedDescendants) {
      if (descendant._onKeyUp(keyCode, modifiers)) {
        return true;
      }
    }

    return super._onKeyUp(keyCode, modifiers);
  }

  @override
  bool _onChar(int charCode, KeyModifiers modifiers) {
    for (final descendant in focusedDescendants) {
      if (descendant._onChar(charCode, modifiers)) {
        return true;
      }
    }

    return super._onChar(charCode, modifiers);
  }

  @override
  void _onClick() {
    super._onClick();
    updateFocus(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StackBase(
          child: _FocusStateProvider<_FocusScopeState>(state: this, level: _level, child: super.build(context)),
        ),
        CustomDraw(
          drawFunction: (ctx, transform) {
            // if (focusedDescendants.isEmpty) return;

            // final instance = focusedDescendants.first.context.instance!;
            // final transform = instance.parent!.computeTransformFrom(ancestor: context.instance)..invert();

            // final box = Aabb3.copy(instance.transform.aabb)..transform(transform);
            // ctx.transform.scope((mat4) {
            //   mat4.translateByVector3(box.min);
            //   ctx.primitives.roundedRect(
            //     box.width,
            //     box.height,
            //     const CornerRadius.all(2.5),
            //     Color.ofHsv(focusedDescendants.first.depth / 8 % 1, .75, 1),
            //     ctx.transform,
            //     ctx.projection,
            //     outlineThickness: 1,
            //   );
            // });
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
  _FocusScopeState? scope;
  late FocusableState primaryFocus;

  @override
  void init() {
    streamListen((widget) => widget.onKeyDown, (event) => scope!._onKeyDown(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onKeyUp, (event) => scope!._onKeyUp(event.keyCode, event.modifiers));
    streamListen((widget) => widget.onChar, (event) => scope!._onChar(event.charCode, event.modifiers));
  }

  @override
  Widget build(BuildContext context) {
    return FocusPolicy(
      clickFocus: true,
      child: FocusScope(
        child: Builder(
          builder: (context) {
            // the root scope is always focused
            scope ??= (primaryFocus = _FocusScopeState.maybeOf(context)!.._onFocusChange(FocusLevel.base));

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

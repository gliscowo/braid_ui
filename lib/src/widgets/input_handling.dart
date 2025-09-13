import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'focus.dart';

abstract class Intent {
  const Intent();
}

abstract class Action<I extends Intent> {
  @nonVirtual
  Type get intentType => I;

  void invoke(I intent);

  Action<J> downcast<J extends I>() => ForwardingAction(this);
}

class CallbackAction<I extends Intent> extends Action<I> {
  final void Function(I intent) callback;
  CallbackAction(this.callback);

  @override
  void invoke(I intent) => callback(intent);
}

class ForwardingAction<I extends Intent, J extends I> extends Action<J> {
  final Action<I> delegate;
  ForwardingAction(this.delegate);

  @override
  void invoke(J intent) => delegate.invoke(intent);
}

// ---

class Shortcuts extends StatefulWidget {
  final Map<List<ActionTrigger>, Intent> shortcuts;
  final Widget child;

  const Shortcuts({super.key, required this.shortcuts, required this.child});

  @override
  WidgetState<Shortcuts> createState() => _ShortcutsState();
}

class _ShortcutsState extends WidgetState<Shortcuts> {
  late final _IntentScopeState scope;
  late Map<List<ActionTrigger>, Callback> actions;

  @override
  void init() {
    scope = _IntentScopeState.of(context);
    _buildActions();
  }

  @override
  void didUpdateWidget(Shortcuts oldWidget) {
    _buildActions();
  }

  void _buildActions() {
    actions = {
      for (final MapEntry(key: triggers, value: intent) in widget.shortcuts.entries)
        triggers: () => scope.actionForIntent(intent.runtimeType)?.invoke(intent),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Actions(actions: actions, child: widget.child);
  }
}

// ---

extension type ActionsMap.fromMap(Map<Type, Action> _value) implements Map<Type, Action> {
  factory ActionsMap(List<Action> actions) {
    final map = <Type, Action>{};

    for (final action in actions) {
      final intentType = action.intentType;
      assert(!map.containsKey(intentType), 'duplicate intent type in ActionsMap');

      map[intentType] = action;
    }

    return ActionsMap.fromMap(map);
  }
}

class Intents extends StatefulWidget {
  final ActionsMap actions;
  final Widget child;

  const Intents({super.key, required this.actions, required this.child});

  @override
  WidgetState<Intents> createState() => _IntentsState();
}

class _IntentsState extends WidgetState<Intents> {
  late final _IntentScopeState scope;

  @override
  void init() {
    scope = _IntentScopeState.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Focusable(
      focusGainedCallback: () => scope.onDescendantFocusGained(this),
      focusLostCallback: () => scope.onDescendantFocusLost(this),
      child: _IntentsProvider(state: this, child: widget.child),
    );
  }
}

class _IntentsProvider extends InheritedWidget {
  final _IntentsState state;
  _IntentsProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

// ---

class IntentScope extends StatefulWidget {
  final Widget child;
  const IntentScope({super.key, required this.child});

  @override
  WidgetState<IntentScope> createState() => _IntentScopeState();

  // ---

  static void invoke(BuildContext context, Intent intent) =>
      _IntentScopeState.of(context).actionForIntent(intent.runtimeType)?.invoke(intent);
}

class _IntentScopeState extends WidgetState<IntentScope> {
  final List<_IntentsState> _focusedDescendants = [];

  void onDescendantFocusGained(_IntentsState descendant) => _focusedDescendants.add(descendant);
  void onDescendantFocusLost(_IntentsState descendant) => _focusedDescendants.remove(descendant);

  Action? actionForIntent(Type intentType) {
    return _focusedDescendants
        .cast<_IntentsState?>()
        .lastWhere((element) => element!.widget.actions.containsKey(intentType), orElse: () => null)
        ?.widget
        .actions[intentType];
  }

  @override
  Widget build(BuildContext context) {
    return _IntentScopeProvider(scope: this, child: widget.child);
  }

  // ---

  static _IntentScopeState of(BuildContext context) => context.getAncestor<_IntentScopeProvider>()!.scope;
}

class _IntentScopeProvider extends InheritedWidget {
  final _IntentScopeState scope;
  _IntentScopeProvider({required this.scope, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

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
  late Map<List<ActionTrigger>, Callback> actions;

  @override
  void init() {
    _buildActions();
  }

  @override
  void didUpdateWidget(Shortcuts oldWidget) {
    _buildActions();
  }

  void _buildActions() {
    actions = {
      for (final MapEntry(key: triggers, value: intent) in widget.shortcuts.entries)
        triggers: () => Intents.invoke(context, intent),
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

  // ---

  static void invoke(BuildContext context, Intent intent) {
    actionForIntent(context, intent.runtimeType)?.invoke(intent);
  }

  static Action? actionForIntent(BuildContext context, Type intentType) {
    var intents = Focusable.of(context).primaryFocus.context.getAncestor<_IntentsProvider>()?.state;
    while (intents != null && !intents.widget.actions.containsKey(intentType)) {
      intents = intents.context.getAncestor<_IntentsProvider>()?.state;
    }

    return intents?.widget.actions[intentType];
  }
}

class _IntentsState extends WidgetState<Intents> {
  @override
  Widget build(BuildContext context) {
    return _IntentsProvider(
      state: this,
      child: Focusable(child: widget.child),
    );
  }
}

class _IntentsProvider extends InheritedWidget {
  final _IntentsState state;
  _IntentsProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

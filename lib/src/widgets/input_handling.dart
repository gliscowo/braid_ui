import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'focus.dart';

abstract class Intent {
  const Intent();
}

abstract class Action<I extends Intent> {
  const Action();

  @nonVirtual
  Type get intentType => I;

  void invoke(BuildContext context, I intent);

  Action<J> downcast<J extends I>() => ForwardingAction(this);
}

class CallbackAction<I extends Intent> extends Action<I> {
  final void Function(BuildContext context, I intent) callback;
  CallbackAction(this.callback);

  @override
  void invoke(BuildContext context, I intent) => callback(context, intent);
}

class ForwardingAction<I extends Intent, J extends I> extends Action<J> {
  final Action<I> delegate;
  ForwardingAction(this.delegate);

  @override
  void invoke(BuildContext context, J intent) => delegate.invoke(context, intent);
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

extension type const ActionsMap.fromMap(Map<Type, Action> _value) implements Map<Type, Action> {
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
  final bool focusable;
  final bool autoFocus;

  final ActionsMap actions;
  final Widget child;

  const Intents({super.key, this.focusable = true, this.autoFocus = false, required this.actions, required this.child});

  @override
  WidgetState<Intents> createState() => _IntentsState();

  // ---

  static void invoke(BuildContext context, Intent intent) {
    actionForIntent(context, intent.runtimeType)?.invoke(context, intent);
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
      child: widget.focusable ? Focusable(autoFocus: widget.autoFocus, child: widget.child) : widget.child,
    );
  }
}

class _IntentsProvider extends InheritedWidget {
  final _IntentsState state;
  _IntentsProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

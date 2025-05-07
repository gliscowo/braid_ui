import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';

typedef ObservableListener = void Function();

abstract mixin class Observable {
  final List<ObservableListener> _listeners = [];

  void subscribe(ObservableListener listener) {
    _listeners.add(listener);
  }

  void unsubscribe(ObservableListener listener) {
    _listeners.remove(listener);
  }

  @protected
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class ObservableValue<T> with Observable {
  T _value;
  ObservableValue(this._value);

  T get value => _value;
  set value(T value) {
    if (_value == value) return;

    _value = value;
    notifyListeners();
  }
}

abstract class ShareableState {
  late SharedStateWidgetState _backingState;

  void setState(void Function() fn) {
    _backingState.setState(() {
      fn();
      _backingState.generation++;
    });
  }
}

class SharedState<T extends ShareableState> extends StatefulWidget {
  final T Function() initState;
  final Widget child;

  const SharedState({super.key, required this.initState, required this.child});

  @override
  WidgetState<StatefulWidget> createState() => SharedStateWidgetState<T>();

  static T get<T extends ShareableState>(BuildContext context) {
    final provider = context.dependOnAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to read inherited state which is not provided by the current context');

    return provider!.state.state;
  }

  static void set<T extends ShareableState>(BuildContext context, void Function(T state) fn) {
    final provider = context.getAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to set inherited state which is not provided by the current context');

    provider!.state.state.setState(() => fn(provider.state.state));
  }
}

class SharedStateWidgetState<T extends ShareableState> extends WidgetState<SharedState<T>> {
  late T state;
  int generation = 0;

  @override
  void init() {
    super.init();
    state = widget.initState().._backingState = this;
  }

  @override
  Widget build(BuildContext context) {
    return _SharedStateProvider(state: this, generation: generation, child: widget.child);
  }
}

class _SharedStateProvider<T extends ShareableState> extends InheritedWidget {
  final SharedStateWidgetState<T> state;
  final int generation;

  _SharedStateProvider({super.key, required this.state, required this.generation, required super.child});

  @override
  bool mustRebuildDependents(covariant _SharedStateProvider<T> newWidget) {
    return generation != newWidget.generation;
  }
}

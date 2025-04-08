import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';

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

class ObservableBuilder<T> extends Builder {
  final Observable observable;

  const ObservableBuilder({required this.observable, required super.builder});

  @override
  WidgetProxy proxy() => ObservableBuilderProxy(this);
}

class ObservableBuilderProxy<T> extends BuilderProxy {
  late final ObservableListener listener = _listener;
  ObservableBuilderProxy(ObservableBuilder<T> super.widget) {
    (widget as ObservableBuilder<T>).observable.subscribe(_listener);
  }

  @override
  void updateWidget(covariant ObservableBuilder<T> newWidget) {
    final oldObservable = (widget as ObservableBuilder<T>).observable;
    if (oldObservable != newWidget.observable) {
      oldObservable.unsubscribe(listener);
    }
    super.updateWidget(newWidget);

    if (oldObservable != newWidget.observable) {
      newWidget.observable.subscribe(listener);
    }
  }

  void _listener() => rebuild(force: true);
}

abstract class ShareableState {}

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

  // TODO: this shouldn't introduce a dependency since its effectively write-only
  static void set<T extends ShareableState>(BuildContext context, void Function(T state) fn) {
    final provider = context.dependOnAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to set inherited state which is not provided by the current context');

    provider!.state.setState(() {
      fn(provider.state.state);
      provider.state.generation++;
    });
  }
}

class SharedStateWidgetState<T extends ShareableState> extends WidgetState<SharedState<T>> {
  late T state;
  int generation = 0;

  @override
  void init() {
    super.init();
    state = widget.initState();
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

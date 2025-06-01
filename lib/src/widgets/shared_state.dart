import 'dart:collection';

import '../framework/proxy.dart';
import '../framework/widget.dart';

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

  static T get<T extends ShareableState>(BuildContext context, {bool withDependency = true}) {
    final provider =
        withDependency
            ? context.dependOnAncestor<_SharedStateProvider<T>>()
            : context.getAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to read shared state which is not provided by the current context');

    return provider!.state.state;
  }

  static S select<T extends ShareableState, S>(BuildContext context, S Function(T state) selector) {
    final provider = context.getAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to select from shared state which is not provided by the current context');

    final capturedValue = selector(provider!.state.state);
    context.dependOnAncestor<_SharedStateProvider<T>>((capturedValue: capturedValue, selector: selector));

    return capturedValue;
  }

  static void set<T extends ShareableState>(BuildContext context, void Function(T state) fn) {
    final provider = context.getAncestor<_SharedStateProvider<T>>();
    assert(provider != null, 'attempted to set shared state which is not provided by the current context');

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

  @override
  WidgetProxy proxy() => _SharedStateProviderProxy<T>(this);
}

typedef _StateAspect<T extends ShareableState> = ({Object? capturedValue, Object? Function(T) selector});

class _SharedStateProviderProxy<T extends ShareableState> extends InheritedProxy {
  _SharedStateProviderProxy(super.widget);

  final Map<WidgetProxy, Object> _dependenciesByDependent = HashMap();

  @override
  void addDependency(WidgetProxy dependent, Object? dependency) {
    super.addDependency(dependent, dependency);

    final existingDependency = _dependenciesByDependent[dependent];
    if (existingDependency != null && existingDependency is! List) {
      return;
    }

    if (dependency is! _StateAspect<T>) {
      _dependenciesByDependent[dependent] = const ();
      return;
    }

    final aspects =
        existingDependency as List<_StateAspect<T>>? ?? (_dependenciesByDependent[dependent] = <_StateAspect<T>>[]);
    aspects.add(dependency);
  }

  @override
  bool mustRebuildDependent(WidgetProxy dependent) {
    final dependency = _dependenciesByDependent[dependent];
    if (dependency is List<_StateAspect<T>>) {
      return dependency.any(
        (element) => element.capturedValue != element.selector((widget as _SharedStateProvider).state.state as T),
      );
    } else {
      return true;
    }
  }

  @override
  void notifyDependent(WidgetProxy dependent) {
    super.notifyDependent(dependent);
    _dependenciesByDependent.remove(dependent);
  }
}

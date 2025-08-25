import 'package:meta/meta.dart';

import '../framework/proxy.dart';
import '../framework/widget.dart';
import '../widgets/inspector.dart';

mixin Listenable {
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  @protected
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class CompoundListenable with Listenable {
  final List<Listenable> _children = [];

  void addChild(Listenable child) {
    child.addListener(_listener);
    _children.add(child);
  }

  void removeChild(Listenable child) {
    child.removeListener(_listener);
    _children.remove(child);
  }

  void clear() {
    for (final child in _children) {
      child.removeListener(_listener);
    }

    _children.clear();
  }

  void _listener() => notifyListeners();
}

class ListenableValue<V> with Listenable {
  V _value;
  ListenableValue(this._value);

  V get value => _value;

  set value(V value) {
    _value = value;
    notifyListeners();
  }
}

// ---

class StreamBuilder<T> extends StatefulWidget {
  final Widget? child;
  final Stream<T> stream;
  final Widget Function(BuildContext context, T? lastestEvent, Widget? child) builder;

  const StreamBuilder({super.key, this.child, required this.stream, required this.builder});

  @override
  WidgetState<StreamBuilder<T>> createState() => _StreamBuilderState<T>();
}

class _StreamBuilderState<T> extends WidgetState<StreamBuilder<T>> with StreamListenerState {
  T? latestEvent;

  @override
  void init() => streamListen(
    (widget) => widget.stream,
    (event) => setState(() {
      latestEvent = event;
    }),
  );

  @override
  Widget build(BuildContext context) => widget.builder(context, latestEvent, widget.child);
}

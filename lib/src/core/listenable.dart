import 'package:meta/meta.dart';

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

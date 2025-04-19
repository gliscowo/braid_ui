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

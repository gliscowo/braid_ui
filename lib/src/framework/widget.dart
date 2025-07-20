import 'package:meta/meta.dart';

import 'instance.dart';
import 'proxy.dart';

abstract interface class BuildContext {
  T? getAncestor<T extends InheritedWidget>();
  T? dependOnAncestor<T extends InheritedWidget>([Object? dependency]);

  WidgetInstance? get instance;
}

// ---

extension type const Key(String value) {}

// ---

@immutable
abstract class Widget {
  final Key? key;

  const Widget({this.key});

  WidgetProxy proxy();

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return (oldWidget.runtimeType == newWidget.runtimeType) && oldWidget.key == newWidget.key;
  }
}

// ---

abstract class InheritedWidget extends Widget {
  final Widget child;

  const InheritedWidget({super.key, required this.child});

  bool mustRebuildDependents(covariant InheritedWidget newWidget);

  @override
  WidgetProxy proxy() => InheritedProxy(this);
}

// ---

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);

  // ---

  @override
  StatelessProxy proxy() => StatelessProxy(this);
}

// ---

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});

  WidgetState createState();

  // ---

  @override
  StatefulProxy proxy() => StatefulProxy(this);
}

// ---

abstract class InstanceWidget extends Widget {
  const InstanceWidget({super.key});

  @factory
  WidgetInstance instantiate();
}

abstract class SingleChildInstanceWidget extends InstanceWidget {
  final Widget child;

  const SingleChildInstanceWidget({super.key, required this.child});

  @override
  @factory
  SingleChildWidgetInstance instantiate();

  // ---

  @override
  SingleChildInstanceWidgetProxy proxy() => SingleChildInstanceWidgetProxy(this);
}

abstract class OptionalChildInstanceWidget extends InstanceWidget {
  final Widget? child;

  const OptionalChildInstanceWidget({super.key, this.child});

  @override
  @factory
  OptionalChildWidgetInstance instantiate();

  // ---

  @override
  OptionalChildInstanceWidgetProxy proxy() => OptionalChildInstanceWidgetProxy(this);
}

abstract class MultiChildInstanceWidget extends InstanceWidget {
  final List<Widget> children;

  const MultiChildInstanceWidget({super.key, required this.children});

  @override
  @factory
  MultiChildWidgetInstance instantiate();

  // ---

  @override
  MultiChildInstanceWidgetProxy proxy() => MultiChildInstanceWidgetProxy(this);
}

abstract class LeafInstanceWidget extends InstanceWidget {
  const LeafInstanceWidget({super.key});

  @override
  @factory
  LeafWidgetInstance instantiate();

  // ---

  @override
  LeafInstanceWidgetProxy proxy() => LeafInstanceWidgetProxy(this);
}

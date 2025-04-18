import '../core/constraints.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';

typedef LayoutBuilderCallback = Widget Function(BuildContext context, Constraints constraints);

class LayoutBuilder extends InstanceWidget {
  final LayoutBuilderCallback builder;

  const LayoutBuilder({required this.builder});

  @override
  WidgetInstance instantiate() => _LayoutBuilderInstance(widget: this);

  @override
  InstanceWidgetProxy proxy() => _LayoutBuilderProxy(this);
}

class _LayoutBuilderProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  @override
  late final BuildScope buildScope = BuildScope(() => instance.markNeedsLayout());

  @override
  _LayoutBuilderInstance get instance => super.instance as _LayoutBuilderInstance;

  _LayoutBuilderProxy(LayoutBuilder super.widget) {
    instance._callback = _rebuild;
  }

  @override
  void updateWidget(LayoutBuilder newWidget) {
    super.updateWidget(newWidget);
    instance.markNeedsLayout();
  }

  void _rebuild(Constraints constraints) {
    final newWidget = (widget as LayoutBuilder).builder(this, constraints);
    child = refreshChild(child, newWidget, null);

    buildScope.rebuildDirtyProxies();
  }

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, covariant Object? slot) {
    this.instance.child = instance!;
  }
}

class _LayoutBuilderInstance extends OptionalChildWidgetInstance with OptionalShrinkWrapLayout {
  late final void Function(Constraints constraints) _callback;

  _LayoutBuilderInstance({required super.widget});

  @override
  void doLayout(Constraints constraints) {
    host!.notifySubtreeRebuild();
    _callback(constraints);

    super.doLayout(constraints);
  }
}

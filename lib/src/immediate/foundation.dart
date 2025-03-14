import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../../braid_ui.dart';

abstract interface class BuildContext {}

// ---

mixin NodeWithDepth {
  int _depth = -1;
  int get depth => _depth;
  set depth(int value) {
    if (_depth == value) return;

    _depth = value;
    for (final child in children) {
      child.depth = _depth + 1;
    }
  }

  Iterable<NodeWithDepth> get children;

  static int compare(NodeWithDepth a, NodeWithDepth b) => a._depth.compareTo(b._depth);
}

// ---

@immutable
abstract class Widget {
  final Key? key;

  const Widget({
    this.key,
  });

  WidgetProxy proxy();

  static bool canUpdate(Widget oldWidget, Widget newWidget) {
    return (oldWidget.runtimeType == newWidget.runtimeType) && oldWidget.key == newWidget.key;
  }
}

abstract class InstanceWidget extends Widget {
  const InstanceWidget({super.key});

  @factory
  WidgetInstance instantiate();
}

abstract class SingleChildInstanceWidget extends InstanceWidget {
  final Widget child;

  const SingleChildInstanceWidget({
    super.key,
    required this.child,
  });

  @override
  @factory
  SingleChildWidgetInstance instantiate();

  // ---

  @override
  SingleChildInstanceWidgetProxy proxy() => SingleChildInstanceWidgetProxy(this);
}

abstract class OptionalChildInstanceWidget extends InstanceWidget {
  final Widget? child;

  const OptionalChildInstanceWidget({
    super.key,
    this.child,
  });

  @override
  @factory
  OptionalChildWidgetInstance instantiate();

  // ---

  @override
  OptionalChildInstanceWidgetProxy proxy() => OptionalChildInstanceWidgetProxy(this);
}

abstract class LeafInstanceWidget extends InstanceWidget {
  const LeafInstanceWidget({super.key});

  @override
  LeafInstaceWidgetProxy proxy() => LeafInstaceWidgetProxy(this);
}

// ---

class BuildScope {
  final List<WidgetProxy> _dirtyProxies = [];
  bool _resortProxies = true;

  void scheduleRebuild(WidgetProxy proxy) {
    _dirtyProxies.add(proxy);
    _resortProxies = true;
  }

  void rebuildDirtyProxies() {
    for (var idx = 0; idx < _dirtyProxies.length; idx = _nextDirtyindex(idx)) {
      _dirtyProxies[idx].rebuild();
    }

    _dirtyProxies.clear();
  }

  int _nextDirtyindex(int idx) {
    if (!_resortProxies) return idx + 1;

    _dirtyProxies.sort();
    _resortProxies = false;

    idx++;
    while (idx > 0 && _dirtyProxies[idx - 1].needsRebuild) {
      idx--;
    }

    return idx;
  }
}

sealed class WidgetProxy with NodeWithDepth implements BuildContext, Comparable<WidgetProxy> {
  Widget _widget;
  Widget get widget => _widget;
  set widget(Widget value) {
    if (_widget == value) return;

    _widget = value;
    rebuild(force: true);
  }

  WidgetProxy? _parent;
  WidgetProxy? get parent => _parent;

  bool get mounted => _parent != null;

  WidgetProxy(this._widget);

  BuildScope? _parentBuildScope;
  BuildScope get buildScope => _parentBuildScope!;

  @override
  Iterable<WidgetProxy> get children => const [];

  void mount(WidgetProxy parent) {
    assert(parent.mounted, 'parent proxy must be mounted before its children');

    _parent = parent;
    _parentBuildScope = parent.buildScope;
    depth = parent.depth + 1;
  }

  void unmount() {
    for (final child in children) {
      child.unmount();
    }
  }

  bool needsRebuild = false;
  void markNeedsRebuild() {
    if (needsRebuild) return;

    needsRebuild = true;
    buildScope.scheduleRebuild(this);
  }

  void reassemble() {
    markNeedsRebuild();
    for (final child in children) {
      child.reassemble();
    }
  }

  @nonVirtual
  void rebuild({bool force = false}) {
    if (!force && !needsRebuild) return;

    doRebuild();
  }

  @mustCallSuper
  void doRebuild() {
    needsRebuild = false;
  }

  // ---

  WidgetInstance get associatedInstance;

  // ---

  @override
  int compareTo(WidgetProxy other) => NodeWithDepth.compare(this, other);

  @override
  String toString() => '$runtimeType (${_widget.runtimeType})';
}

abstract class InstanceWidgetProxy extends WidgetProxy {
  WidgetInstance instance;

  InstanceWidgetProxy(InstanceWidget super.widget) : instance = widget.instantiate();

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);

    while (parent is! InstanceWidgetProxy) {
      (parent as ComposedProxy)._descendantInstance = instance;
      parent = parent._parent!;
    }
  }

  @override
  void unmount() {
    super.unmount();
    instance.dispose();
  }

  @override
  WidgetInstance<InstanceWidget> get associatedInstance => instance;
}

mixin SingleChildWidgetProxy on WidgetProxy {
  WidgetProxy? _child;

  WidgetProxy? get child => _child;
  set child(WidgetProxy? value) {
    _child?.unmount();

    if (value != null) {
      value.mount(this);
      _child = value;
    } else {
      _child = null;
    }
  }

  @override
  Iterable<WidgetProxy> get children => [if (_child != null) _child!];
}

class SingleChildInstanceWidgetProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  SingleChildInstanceWidgetProxy(SingleChildInstanceWidget super.widget);

  @override
  SingleChildWidgetInstance get instance => (super.instance as SingleChildWidgetInstance);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    child = (widget as SingleChildInstanceWidget).child.proxy();
    instance.child = child!.associatedInstance;
  }

  @override
  void doRebuild() {
    instance.widget = widget as SingleChildInstanceWidget;

    final newWidget = (widget as SingleChildInstanceWidget).child;
    if (Widget.canUpdate(child!.widget, newWidget)) {
      child!.widget = newWidget;
    } else {
      child = newWidget.proxy();
    }

    instance.child = child!.associatedInstance;
    super.doRebuild();
  }
}

class OptionalChildInstanceWidgetProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  OptionalChildInstanceWidgetProxy(OptionalChildInstanceWidget super.widget);

  @override
  OptionalChildWidgetInstance get instance => (super.instance as OptionalChildWidgetInstance);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    child = (widget as OptionalChildInstanceWidget).child?.proxy();
    if (child != null) {
      instance.child = child!.associatedInstance;
    }
  }

  @override
  void doRebuild() {
    instance.widget = (widget as OptionalChildInstanceWidget);

    final newWidget = (widget as OptionalChildInstanceWidget).child;
    if (newWidget != null) {
      if (Widget.canUpdate(child!.widget, newWidget)) {
        child!.widget = newWidget;
      } else {
        child = newWidget.proxy();
      }
      instance.child = child!.associatedInstance;
    } else {
      instance.child = null;
    }

    super.doRebuild();
  }
}

class LeafInstaceWidgetProxy extends InstanceWidgetProxy {
  LeafInstaceWidgetProxy(super.widget);

  @override
  void doRebuild() {
    instance.widget = (widget as InstanceWidget);
    super.doRebuild();
  }
}

abstract class ComposedProxy extends WidgetProxy with SingleChildWidgetProxy {
  WidgetInstance? _descendantInstance;

  ComposedProxy(super.widget);

  @override
  WidgetInstance<InstanceWidget> get associatedInstance {
    assert(
      _descendantInstance != null,
      'cannot query associated instance of ComposedProxy'
      'before descendant InstanceWidgetProxy has been mounted',
    );
    return _descendantInstance!;
  }
}

class StatelessProxy extends ComposedProxy {
  StatelessProxy(StatelessWidget super.widget);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    child = (widget as StatelessWidget).build(this).proxy();
  }

  @override
  void doRebuild() {
    final newWidget = (widget as StatelessWidget).build(this);
    if (Widget.canUpdate(child!.widget, newWidget)) {
      child!.widget = newWidget;
    } else {
      child = newWidget.proxy();
    }

    super.doRebuild();
  }
}

class StatefulProxy extends ComposedProxy {
  final WidgetState _state;

  StatefulProxy(StatefulWidget super.widget) : _state = widget.createState() {
    _state
      .._widget = (widget as StatefulWidget)
      .._owner = this;
  }

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    _state.init();
    child = _state.build(this).proxy();
  }

  @override
  void unmount() {
    super.unmount();
    _state.dispose();
  }

  @override
  void doRebuild() {
    final newWidget = _state.build(this);
    if (Widget.canUpdate(child!.widget, newWidget)) {
      child!.widget = newWidget;
    } else {
      child = newWidget.proxy();
    }

    super.doRebuild();
  }

  @override
  set widget(Widget value) {
    final oldWidget = widget as StatefulWidget;
    _state
      .._widget = value as StatefulWidget
      ..didUpdateWidget(oldWidget);

    super.widget = value;
  }
}

// ---

abstract class VisitorWidget extends Widget {
  final Widget child;

  const VisitorWidget({
    super.key,
    required this.child,
  });

  @override
  VisitorProxy proxy();
}

typedef InstanceVisitor = void Function(WidgetInstance instance);

class VisitorProxy extends ComposedProxy {
  final InstanceVisitor visitor;
  VisitorProxy(VisitorWidget super.widget, this.visitor);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    child = (widget as VisitorWidget).child.proxy();

    visitor(child!.associatedInstance);
  }

  @override
  void doRebuild() {
    final newWidget = (widget as VisitorWidget).child;
    if (Widget.canUpdate(child!.widget, newWidget)) {
      child!.widget = newWidget;
    } else {
      child = newWidget.proxy();
    }

    visitor(child!.associatedInstance);

    super.doRebuild();
  }
}

// ---

class Flexible extends VisitorWidget {
  final double flexFactor;

  const Flexible({
    super.key,
    this.flexFactor = 1.0,
    required super.child,
  });

  @override
  VisitorProxy proxy() => VisitorProxy(
        this,
        (instance) {
          if (instance.parentData case FlexParentData data) {
            data.flexFactor = flexFactor;
          } else {
            instance.parentData = FlexParentData(flexFactor);
          }
        },
      );
}

class Padding extends OptionalChildInstanceWidget {
  final Insets insets;

  const Padding({
    super.key,
    required this.insets,
    super.child,
  });

  @override
  PaddingInstance instantiate() => PaddingInstance(widget: this);
}

class Constrained extends SingleChildInstanceWidget {
  final Constraints constraints;

  Constrained({
    super.key,
    required this.constraints,
    required super.child,
  });

  @override
  ConstrainedInstance instantiate() => ConstrainedInstance(widget: this);
}

class Center extends SingleChildInstanceWidget {
  final double? widthFactor, heightFactor;

  const Center({
    super.key,
    this.widthFactor,
    this.heightFactor,
    required super.child,
  });

  @override
  CenterInstance instantiate() => CenterInstance(widget: this);
}

class Panel extends OptionalChildInstanceWidget {
  final Color color;
  final double cornerRadius;

  Panel({
    super.key,
    required this.color,
    this.cornerRadius = 10.0,
    super.child,
  });

  @override
  PanelInstance instantiate() => PanelInstance(widget: this);
}

class Label extends LeafInstanceWidget {
  final Text text;
  final LabelStyle style;

  Label({
    super.key,
    required String text,
    this.style = LabelStyle.empty,
  }) : text = Text.string(text);

  Label.text({
    super.key,
    required this.text,
    this.style = LabelStyle.empty,
  });

  @override
  LabelInstance instantiate() => LabelInstance(widget: this);
}

class MouseArea extends SingleChildInstanceWidget {
  final void Function()? clickCallback;
  final void Function()? enterCallback;
  final void Function()? exitCallback;
  final void Function(double horizontal, double vertical)? scrollCallback;
  final CursorStyle? cursorStyle;

  const MouseArea({
    super.key,
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.scrollCallback,
    this.cursorStyle,
    required super.child,
  });

  @override
  MouseAreaInstance instantiate() => MouseAreaInstance(widget: this);
}

class KeyboardInput extends SingleChildInstanceWidget {
  final void Function(int keyCode, int modifiers)? keyDownCallback;
  final void Function(int keyCode, int modifiers)? keyUpCallback;
  final void Function(int charCode, int modifiers)? charCallback;
  final void Function()? focusGainedCallback;
  final void Function()? focusLostCallback;

  const KeyboardInput({
    super.key,
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    required super.child,
  });

  @override
  KeyboardInputInstance instantiate() => KeyboardInputInstance(widget: this);
}

class HitTestOccluder extends VisitorWidget {
  const HitTestOccluder({
    super.key,
    required super.child,
  });

  @override
  VisitorProxy proxy() => VisitorProxy(
        this,
        (instance) => instance.flags += InstanceFlags.hitTestBoundary,
      );
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

abstract class WidgetState<T extends StatefulWidget> {
  Widget build(BuildContext context);

  T? _widget;
  T get widget => _widget!;

  void init() {}
  void dispose() {}

  StatefulProxy? _owner;

  @nonVirtual
  void setState(void Function() fn) {
    assert(_owner != null, "setState invoked on WidgetState before it was mounted");

    fn();
    _owner!.markNeedsRebuild();
  }

  void didUpdateWidget(covariant T oldWidget) {}
}

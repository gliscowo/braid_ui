import 'dart:collection';

import 'package:meta/meta.dart';

import 'instance.dart';
import 'widget.dart';

typedef DepthNodeVisitor = void Function(NodeWithDepth child);

/// Common functionality for tree nodes which need to track their
/// depth. Provides the respective field, a setter which recursively
/// adjusts child depth and [compare] for implementing an ordering
/// based on node depth
///
/// This mechanism is used by both by the proxy and instance trees to ensure
/// that rebuilding and layout respectively happen in top->bottom order
///
/// [depth] starts at `-1` on all nodes and must be set to `0` at the root
/// once the tree is constructred to establish proper depth values throughout
mixin NodeWithDepth {
  int _depth = -1;
  int get depth => _depth;
  set depth(int value) {
    if (_depth == value) return;

    _depth = value;
    visitChildren((child) {
      child.depth = _depth + 1;
    });
  }

  void visitChildren(DepthNodeVisitor visitor);

  static int compare(NodeWithDepth a, NodeWithDepth b) => a._depth.compareTo(b._depth);
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
    _dirtyProxies.sort();

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

// ---

enum ProxyLifecycle { initial, live, dead }

typedef WidgetProxyVisitor = void Function(WidgetProxy child);
typedef InstanceCallback = void Function(WidgetInstance childInstance);

sealed class WidgetProxy with NodeWithDepth implements BuildContext, Comparable<WidgetProxy> {
  WidgetProxy(this._widget);

  Widget _widget;
  Widget get widget => _widget;

  WidgetProxy? _parent;
  WidgetProxy? get parent => _parent;

  bool get mounted => _parent != null;

  BuildScope? _parentBuildScope;
  BuildScope get buildScope => _parentBuildScope!;

  ProxyLifecycle lifecycle = ProxyLifecycle.initial;

  final Map<Type, InheritedProxy?> _dependencies = HashMap();

  void mount(WidgetProxy parent) {
    assert(parent.mounted, 'parent proxy must be mounted before its children');

    assert(lifecycle == ProxyLifecycle.initial, 'proxy must be in "initial" lifecycle state when mount() is called');
    lifecycle = ProxyLifecycle.live;

    _parent = parent;
    _parentBuildScope = parent.buildScope;
    depth = parent.depth + 1;
  }

  static void _unmountChild(WidgetProxy child) => child.unmount();
  void unmount() {
    assert(lifecycle == ProxyLifecycle.live, 'proxy must be in "live" lifecycle state when unmount() is called');
    lifecycle = ProxyLifecycle.dead;

    for (final dependency in _dependencies.values.nonNulls) {
      dependency.removeDependent(this);
    }

    visitChildren(_unmountChild);
  }

  bool needsRebuild = true;
  void markNeedsRebuild() {
    if (needsRebuild) return;

    needsRebuild = true;
    buildScope.scheduleRebuild(this);
  }

  static void _reassembleChild(WidgetProxy child) => child.reassemble();
  void reassemble() {
    markNeedsRebuild();
    visitChildren(_reassembleChild);
  }

  // ---

  WidgetProxy? refreshChild(WidgetProxy? child, Widget? newWidget) {
    if (newWidget == null) {
      if (child != null) child.unmount();
      return null;
    }

    if (child != null && Widget.canUpdate(child.widget, newWidget)) {
      if (!identical(child.widget, newWidget)) {
        child.updateWidget(newWidget);
      }

      return child;
    } else {
      if (child != null) {
        child.unmount();
      }

      return newWidget.proxy()..mount(this);
    }
  }

  /// Update the configuration of this element, called by the framework when
  /// a new widget becomes available (through, for instance, a parent rebuild)
  ///
  /// The base implementation simply updates the [_widget] field
  @mustCallSuper
  void updateWidget(covariant Widget newWidget) {
    _widget = newWidget;
  }

  @nonVirtual
  void rebuild({bool force = false}) {
    if (!(force || (needsRebuild && lifecycle == ProxyLifecycle.live))) return;

    doRebuild();
  }

  @mustCallSuper
  void doRebuild() {
    needsRebuild = false;
  }

  // ---

  @override
  T? dependOnAncestor<T extends Widget>() {
    if (_dependencies.containsKey(T)) {
      return _dependencies[T]?.widget as T?;
    }

    var ancestor = _parent;
    while (ancestor != null) {
      if (ancestor is InheritedProxy && ancestor.widget.runtimeType == T) {
        _dependencies[T] = ancestor..addDependent(this);
        return ancestor.widget as T;
      }

      ancestor = ancestor.parent;
    }

    return null;
  }

  void notifyDependenciesChanged() {
    markNeedsRebuild();
  }

  // ---

  @override
  void visitChildren(WidgetProxyVisitor visitor);

  /// Set a callback to be invoked whenever the first instance associated
  /// with this branch of the proxy tree changes.
  ///
  /// The provided callback is invoked immediately with the current instance
  /// and potentially later during the lifetime of this branch if a descendant
  /// rebuilds to a different instance
  set instanceCallback(InstanceCallback callback);

  // ---

  @override
  int compareTo(WidgetProxy other) => NodeWithDepth.compare(this, other);

  @override
  String toString() => '$runtimeType (${_widget.runtimeType})';
}

/// Storage and visiting facilities for all proxies which
/// manage a single child (mainly [ComposedProxy], [SingleChildInstanceWidgetProxy]
/// and [OptionalChildInstanceWidgetProxy])
mixin SingleChildWidgetProxy on WidgetProxy {
  WidgetProxy? child;

  @override
  void visitChildren(WidgetProxyVisitor visitor) {
    if (child != null) {
      visitor(child!);
    }
  }
}

/// The opposite of an [InstanceWidgetProxy] - that is, a composed
/// proxy is never directly responsible for a [WidgetInstance]. Instead,
/// every composed proxy has a single child proxy and indirectly creates
/// an instance because a chain of composed proxies (in the descendants)
/// can only be terminated by an instance proxy
abstract class ComposedProxy extends WidgetProxy with SingleChildWidgetProxy {
  ComposedProxy(super.widget);

  WidgetInstance? _descendantInstance;
  void Function(WidgetInstance)? _instanceCallback;

  @override
  set instanceCallback(void Function(WidgetInstance<InstanceWidget> newAssociatedInstance) callback) {
    assert(
      _descendantInstance != null,
      'cannot set instance callback on a ComposedProxy before its '
      'descendant InstanceWidgetProxy has been mounted',
    );

    callback(_descendantInstance!);
    _instanceCallback = callback;
  }
}

/// A proxy which immediately spawns, owns and manages a [WidgetInstance]
/// in the instance tree. This instance can then have 0-n children (depending
/// on the type of instance) and thus ever leaf of the proxy tree must be
/// an instance proxy (ideally a [LeafInstanceWidgetProxy])
abstract class InstanceWidgetProxy extends WidgetProxy {
  /// The instance owned and managed by this proxy. Immediately
  /// initialized upon proxy instantiation and available throughout
  /// its entire lifetime
  WidgetInstance instance;
  List<InstanceCallback>? _queuedInstanceCallbacks;

  InstanceWidgetProxy(InstanceWidget super.widget) : instance = widget.instantiate();

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);

    while (parent is! InstanceWidgetProxy) {
      (parent as ComposedProxy)._descendantInstance = instance;
      if (parent._instanceCallback case InstanceCallback callback) {
        (_queuedInstanceCallbacks ??= []).add(callback);
      }

      parent = parent._parent!;
    }
  }

  @override
  void unmount() {
    super.unmount();
    instance.dispose();
  }

  @override
  void updateWidget(InstanceWidget newWidget) {
    super.updateWidget(newWidget);
    instance.widget = newWidget;
  }

  @override
  void doRebuild() {
    super.doRebuild();

    if (_queuedInstanceCallbacks != null) {
      for (final callback in _queuedInstanceCallbacks!) {
        callback(instance);
      }
    }
  }

  @override
  set instanceCallback(InstanceCallback callback) {
    // Since the instance associated with this proxy can never change,
    // it is sufficient to invoke the callback once here
    callback(instance);
  }
}

// ---

class InheritedProxy extends ComposedProxy with SingleChildWidgetProxy {
  final List<WidgetProxy> _dependents = [];

  InheritedProxy(InheritedWidget super.widget);

  void addDependent(WidgetProxy dependent) {
    _dependents.add(dependent);
  }

  void removeDependent(WidgetProxy dependent) {
    _dependents.remove(dependent);
  }

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    rebuild();
  }

  @override
  void updateWidget(covariant InheritedWidget newWidget) {
    final shouldUpdate = (widget as InheritedWidget).mustRebuildDependents(newWidget);

    super.updateWidget(newWidget);

    rebuild(force: true);
    if (shouldUpdate) {
      for (final dependent in _dependents) {
        dependent.notifyDependenciesChanged();
      }
    }
  }

  @override
  void doRebuild() {
    super.doRebuild();
    child = refreshChild(child, (widget as InheritedWidget).child);
  }
}

class StatelessProxy extends ComposedProxy {
  StatelessProxy(StatelessWidget super.widget);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    rebuild();
  }

  @override
  void updateWidget(covariant Widget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    final newWidget = (widget as StatelessWidget).build(this);
    super.doRebuild();

    child = refreshChild(child, newWidget);
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
    rebuild();
  }

  @override
  void unmount() {
    super.unmount();
    _state.dispose();
  }

  @override
  void updateWidget(StatefulWidget newWidget) {
    super.updateWidget(newWidget);

    final oldWidget = _state.widget;
    _state
      .._widget = newWidget
      ..didUpdateWidget(oldWidget);

    rebuild(force: true);
  }

  @override
  void doRebuild() {
    final newWidget = _state.build(this);
    super.doRebuild();

    child = refreshChild(child, newWidget);
  }
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

// ---

class SingleChildInstanceWidgetProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  SingleChildInstanceWidgetProxy(SingleChildInstanceWidget super.widget);

  @override
  SingleChildWidgetInstance get instance => (super.instance as SingleChildWidgetInstance);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    rebuild();
  }

  @override
  void updateWidget(SingleChildInstanceWidget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    child = refreshChild(child, (widget as SingleChildInstanceWidget).child);
    child!.instanceCallback = (childInstance) => instance.child = childInstance;

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
    rebuild();
  }

  @override
  void updateWidget(OptionalChildInstanceWidget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    child = refreshChild(child, (widget as OptionalChildInstanceWidget).child);
    child?.instanceCallback = (childInstance) => instance.child = childInstance;

    super.doRebuild();
  }
}

class LeafInstanceWidgetProxy extends InstanceWidgetProxy {
  LeafInstanceWidgetProxy(super.widget);

  @override
  void mount(WidgetProxy parent) {
    super.mount(parent);
    rebuild();
  }

  @override
  void visitChildren(WidgetProxyVisitor visitor) {}
}

import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

import '../widgets/basic.dart';
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

typedef AnimationCallback = void Function(Duration delta);

abstract interface class ProxyHost {
  void scheduleAnimationCallback(AnimationCallback callback);
  void schedulePostLayoutCallback(Callback callback);
}

class BuildScope {
  final List<WidgetProxy> _dirtyProxies = [];
  bool _resortProxies = true;

  final void Function()? _scheduleRebuild;
  BuildScope([this._scheduleRebuild]);

  /// Schedule a rebuild of [proxy] during the next (or current, if
  /// there is one) build pass of this scope
  void scheduleRebuild(WidgetProxy proxy) {
    _dirtyProxies.add(proxy);
    _resortProxies = true;

    _scheduleRebuild?.call();
  }

  /// Rebuild all dirty proxies in this scope
  ///
  /// The framework only ever invokes this on the root proxy's scope.
  /// Thus if any descendant proxies introduce a new build scope,
  /// it is their responsibility to build the proxies in that scope
  /// when appropriate
  bool rebuildDirtyProxies() {
    if (_dirtyProxies.isEmpty) return false;
    _dirtyProxies.sort();

    for (var idx = 0; idx < _dirtyProxies.length; idx = _nextDirtyindex(idx)) {
      _dirtyProxies[idx].rebuild();
    }

    _dirtyProxies.clear();
    return true;
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

sealed class WidgetProxy with NodeWithDepth implements BuildContext, Comparable<WidgetProxy> {
  WidgetProxy(this._widget);

  Widget _widget;
  Widget get widget => _widget;

  WidgetProxy? _parent;
  WidgetProxy? get parent => _parent;

  bool get mounted => _parent != null;

  BuildScope? _parentBuildScope;
  BuildScope get buildScope => _parentBuildScope!;

  Object? _slot;
  Object? get slot => _slot;

  ProxyHost? _host;
  ProxyHost? get host => _host;

  ProxyLifecycle lifecycle = ProxyLifecycle.initial;

  Map<Type, InheritedProxy>? _inheritedProxies;
  Set<InheritedProxy>? _dependencies;

  void mount(WidgetProxy parent, Object? slot) {
    assert(parent.mounted, 'parent proxy must be mounted before its children');

    assert(lifecycle == ProxyLifecycle.initial, 'proxy must be in "initial" lifecycle state when mount() is called');
    lifecycle = ProxyLifecycle.live;

    _inheritedProxies = parent._inheritedProxies;

    _parent = parent;
    _parentBuildScope = parent.buildScope;
    depth = parent.depth + 1;
    _slot = slot;
    _host = parent._host;
  }

  @mustCallSuper
  void updateSlot(Object? newSlot) {
    _slot = newSlot;
  }

  static void _unmountChild(WidgetProxy child) => child.unmount();
  void unmount() {
    assert(lifecycle == ProxyLifecycle.live, 'proxy must be in "live" lifecycle state when unmount() is called');
    lifecycle = ProxyLifecycle.dead;

    if (_dependencies != null) {
      for (final dependency in _dependencies!) {
        dependency.removeDependent(this);
      }
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

  WidgetProxy? refreshChild(WidgetProxy? child, Widget? newWidget, Object? newSlot) {
    if (newWidget == null) {
      if (child != null) child.unmount();
      return null;
    }

    if (child != null && Widget.canUpdate(child.widget, newWidget)) {
      if (child.slot != newSlot) {
        child.updateSlot(newSlot);
      }

      if (!identical(child.widget, newWidget)) {
        child.updateWidget(newWidget);
      }

      return child;
    } else {
      if (child != null) {
        child.unmount();
      }

      return newWidget.proxy()..mount(this, newSlot);
    }
  }

  /// Update the configuration of this proxy, called by the framework when
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
  T? getAncestor<T extends InheritedWidget>() => _inheritedProxies?[T]?.widget as T?;

  @override
  T? dependOnAncestor<T extends InheritedWidget>([Object? dependency]) {
    final ancestor = _inheritedProxies?[T];
    if (ancestor != null) {
      _dependencies ??= HashSet();
      _dependencies!.add(ancestor..addDependency(this, dependency));
    }

    return ancestor?.widget as T?;
  }

  void notifyDependenciesChanged() {
    markNeedsRebuild();
  }

  // ---

  @override
  void visitChildren(WidgetProxyVisitor visitor);

  @override
  WidgetInstance? get instance;

  void notifyDescendantInstance(WidgetInstance? instance, covariant Object? slot);

  // ---

  @override
  int compareTo(WidgetProxy other) => NodeWithDepth.compare(this, other);

  @override
  String toString() => '$runtimeType (${_widget.runtimeType})';
}

mixin RootProxyMixin on WidgetProxy {
  set host(ProxyHost? value) => _host = value;
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

  @override
  void updateSlot(Object? newSlot) {
    super.updateSlot(newSlot);
    child?.updateSlot(newSlot);
  }

  WidgetInstance? _descendantInstance;
  @override
  WidgetInstance? get instance => _descendantInstance;

  @override
  @mustCallSuper
  void notifyDescendantInstance(WidgetInstance? instance, covariant Object? slot) {
    _descendantInstance = instance;
  }
}

/// A proxy which immediately spawns, owns and manages a [WidgetInstance]
/// in the instance tree. This instance can then have 0-n children (depending
/// on the type of instance) and thus every leaf of the proxy tree must be
/// an instance proxy (ideally a [LeafInstanceWidgetProxy])
abstract class InstanceWidgetProxy extends WidgetProxy {
  /// The instance owned and managed by this proxy. Immediately
  /// initialized upon proxy instantiation and available throughout
  /// its entire lifetime
  @override
  WidgetInstance instance;

  final List<WidgetProxy> _ancestorsUntilNextInstanceProxy = [];

  InstanceWidgetProxy(InstanceWidget super.widget) : instance = widget.instantiate();

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);

    var ancestor = parent;
    while (ancestor is! InstanceWidgetProxy) {
      _ancestorsUntilNextInstanceProxy.add(ancestor);
      ancestor = ancestor._parent!;
    }

    _ancestorsUntilNextInstanceProxy.add(ancestor);

    rebuild();
    _notifyAncestors();
  }

  @override
  void updateSlot(Object? newSlot) {
    super.updateSlot(newSlot);
    _notifyAncestors();
  }

  @override
  void unmount() {
    super.unmount();
    instance.dispose();
    _ancestorsUntilNextInstanceProxy.clear();
  }

  @override
  void updateWidget(InstanceWidget newWidget) {
    super.updateWidget(newWidget);
    instance.widget = newWidget;
  }

  void _notifyAncestors() {
    for (final ancestor in _ancestorsUntilNextInstanceProxy) {
      ancestor.notifyDescendantInstance(instance, slot);
    }
  }
}

// ---

class InheritedProxy extends ComposedProxy {
  final Set<WidgetProxy> _dependents = {};

  InheritedProxy(InheritedWidget super.widget);

  @mustCallSuper
  void addDependency(WidgetProxy dependent, Object? dependency) {
    _dependents.add(dependent);
  }

  @mustCallSuper
  void removeDependent(WidgetProxy dependent) {
    _dependents.remove(dependent);
  }

  @protected
  bool mustRebuildDependent(WidgetProxy dependent) {
    return true;
  }

  @mustCallSuper
  void notifyDependent(WidgetProxy dependent) {
    dependent.notifyDependenciesChanged();
  }

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
    _inheritedProxies = (_inheritedProxies != null ? Map.of(_inheritedProxies!) : HashMap())
      ..[widget.runtimeType] = this;

    rebuild();
  }

  @override
  void updateWidget(covariant InheritedWidget newWidget) {
    final shouldUpdate = (widget as InheritedWidget).mustRebuildDependents(newWidget);

    super.updateWidget(newWidget);

    rebuild(force: true);
    if (shouldUpdate) {
      for (final dependent in _dependents) {
        if (!mustRebuildDependent(dependent)) continue;
        notifyDependent(dependent);
      }
    }
  }

  @override
  void doRebuild() {
    super.doRebuild();
    child = refreshChild(child, (widget as InheritedWidget).child, slot);
  }
}

class StatelessProxy extends ComposedProxy {
  StatelessProxy(StatelessWidget super.widget);

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
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

    child = refreshChild(child, newWidget, slot);
  }
}

class StatefulProxy extends ComposedProxy {
  final WidgetState _state;
  WidgetState get state => _state;

  StatefulProxy(StatefulWidget super.widget) : _state = widget.createState() {
    _state
      .._widget = (widget as StatefulWidget)
      .._owner = this;
  }

  @override
  void mount(WidgetProxy parent, Object? slot) {
    super.mount(parent, slot);
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
  void notifyDependenciesChanged() {
    super.notifyDependenciesChanged();
    _state.didChangeDependencies();
  }

  @override
  void doRebuild() {
    final newWidget = _state.build(this);
    super.doRebuild();
    child = refreshChild(child, newWidget, slot);
  }
}

abstract class WidgetState<T extends StatefulWidget> {
  Widget build(BuildContext context);

  T? _widget;
  T get widget => _widget!;

  BuildContext get context => _owner!;

  void init() {}
  void didUpdateWidget(T oldWidget) {}
  void didChangeDependencies() {}
  void dispose() {}

  StatefulProxy? _owner;

  @nonVirtual
  void setState(void Function() fn) {
    assert(_owner != null, "setState invoked on WidgetState before it was mounted");

    fn();
    _owner!.markNeedsRebuild();
  }

  // TODO: this is not really the ideal way of doing this
  @nonVirtual
  void scheduleAnimationCallback(AnimationCallback callback) => _owner!.host!.scheduleAnimationCallback(callback);

  @nonVirtual
  void schedulePostLayoutCallback(Callback callback) => _owner!.host!.schedulePostLayoutCallback(callback);
}

// ---

class SingleChildInstanceWidgetProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  SingleChildInstanceWidgetProxy(SingleChildInstanceWidget super.widget);

  @override
  SingleChildWidgetInstance get instance => (super.instance as SingleChildWidgetInstance);

  @override
  void updateWidget(SingleChildInstanceWidget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    super.doRebuild();
    child = refreshChild(child, (widget as SingleChildInstanceWidget).child, null);
  }

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, covariant Object? slot) {
    this.instance.child = instance!;
  }
}

class OptionalChildInstanceWidgetProxy extends InstanceWidgetProxy with SingleChildWidgetProxy {
  OptionalChildInstanceWidgetProxy(OptionalChildInstanceWidget super.widget);

  @override
  OptionalChildWidgetInstance get instance => (super.instance as OptionalChildWidgetInstance);

  @override
  void updateWidget(OptionalChildInstanceWidget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    super.doRebuild();
    child = refreshChild(child, (widget as OptionalChildInstanceWidget).child, null);

    // TODO: this should very likely be done by the descendant
    // when it unmounts
    if ((widget as OptionalChildInstanceWidget).child == null) {
      instance.child = null;
    }
  }

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, covariant Object? slot) {
    this.instance.child = instance;
  }
}

class MultiChildInstanceWidgetProxy extends InstanceWidgetProxy {
  List<WidgetProxy> children = [];
  List<WidgetInstance?> childInstances = [];

  MultiChildInstanceWidgetProxy(super.widget);

  @override
  MultiChildWidgetInstance get instance => (super.instance as MultiChildWidgetInstance);

  @override
  void visitChildren(WidgetProxyVisitor visitor) {
    for (final child in children) {
      visitor(child);
    }
  }

  @override
  void updateWidget(MultiChildInstanceWidget newWidget) {
    super.updateWidget(newWidget);
    rebuild(force: true);
  }

  @override
  void doRebuild() {
    super.doRebuild();

    final newWidgets = (widget as MultiChildInstanceWidget).children;

    var newChildrenTop = 0;
    var oldChildrenTop = 0;
    var newChildrenBottom = newWidgets.length - 1;
    var oldChildrenBottom = children.length - 1;

    final newChildren = List<WidgetProxy?>.filled(newWidgets.length, null);

    // we already set up the new child instance list, so that any
    // notifyDescendantInstance invocations caused by the below
    // refreshChild calls always index into the correct list
    childInstances = List<WidgetInstance?>.filled(newChildren.length, null);
    List.copyRange(childInstances, 0, instance.children, 0, min(childInstances.length, instance.children.length));

    if (childInstances.length < instance.children.length) {
      instance.markNeedsLayout();
    }

    instance.children = childInstances.cast();

    // sync from the top
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      if (!Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget, newChildrenTop);
      assert(childInstances[newChildrenTop] != null);

      oldChildrenTop++;
      newChildrenTop++;
    }

    // scan from the bottom
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      if (!Widget.canUpdate(oldChild.widget, newWidget)) {
        break;
      }

      oldChildrenTop++;
      newChildrenTop++;
    }

    // scan middle, store keyed and disposed un-keyed

    final hasOldChildren = oldChildrenTop <= oldChildrenBottom;
    Map<Key, WidgetProxy>? keyedOldChildren;

    if (hasOldChildren) {
      keyedOldChildren = HashMap();
      while (oldChildrenTop <= oldChildrenBottom) {
        final oldChild = children[oldChildrenTop];
        final key = oldChild.widget.key;

        if (key != null) {
          keyedOldChildren[key!] = oldChild;
        } else {
          oldChild.unmount();
        }

        oldChildrenTop++;
      }
    }

    // sync middle, updating keyed

    while (newChildrenTop <= newChildrenBottom) {
      WidgetProxy? oldChild;
      final newWidget = newWidgets[newChildrenTop];

      if (hasOldChildren) {
        final key = newWidget.key;
        if (key != null) {
          oldChild = keyedOldChildren![key];
          if (oldChild != null) {
            if (Widget.canUpdate(oldChild.widget, newWidget)) {
              keyedOldChildren.remove(key);
            } else {
              oldChild = null;
            }
          }
        }
      }

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget, newChildrenTop);
      assert(childInstances[newChildrenTop] != null);

      newChildrenTop++;
    }

    newChildrenBottom = newWidgets.length - 1;
    oldChildrenBottom = children.length - 1;

    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final oldChild = children[oldChildrenTop];
      final newWidget = newWidgets[newChildrenTop];

      newChildren[newChildrenTop] = refreshChild(oldChild, newWidget, newChildrenTop);
      assert(childInstances[newChildrenTop] != null);

      oldChildrenTop++;
      newChildrenTop++;
    }

    // dispose keyed proxies that were not reused
    if (hasOldChildren && keyedOldChildren!.isNotEmpty) {
      for (final proxy in keyedOldChildren.values) {
        proxy.unmount();
      }
    }

    // finally, install new children
    children = newChildren.cast();
  }

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, int slot) {
    this.instance.insertChild(slot, instance!);
  }
}

class LeafInstanceWidgetProxy extends InstanceWidgetProxy {
  LeafInstanceWidgetProxy(LeafInstanceWidget super.widget);

  @override
  void visitChildren(WidgetProxyVisitor visitor) {}

  @override
  void notifyDescendantInstance(WidgetInstance<InstanceWidget>? instance, covariant Object? slot) {
    assert(false, 'a leaf proxy cannot have descendant instances');
  }
}

// --- proxy tree debugging

void dumpProxiesGraphviz(WidgetProxy widget, [IOSink? out]) {
  out ??= stdout;

  if (widget._parent != null) {
    out.writeln('  ${_formatWidget(widget._parent!)} -> ${_formatWidget(widget)};');
  }
  widget.visitChildren((child) {
    dumpProxiesGraphviz(child, out);
  });
}

String _formatWidget(WidgetProxy widget) {
  return '"${widget.widget.runtimeType}\\n${widget.runtimeType}\\n${widget.hashCode.toRadixString(16)}\\nslot: ${widget.slot}"';
}

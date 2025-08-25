import 'package:collection/collection.dart';

import '../core/constraints.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'shared_state.dart';
import 'stack.dart';

typedef Route = ({Widget widget, bool overlay});

class _NavigationState extends ShareableState {
  _NavigationState(Widget? initialRoute)
    : routes = initialRoute != null ? [(widget: initialRoute, overlay: false)] : [] {
    _updateDisplayedRoutes();
  }

  final List<Route> routes;
  List<Route> _displayedRoutes = const [];

  List<Route> get displayedRoutes => _displayedRoutes;

  void push(Widget route, bool overlay) {
    routes.add((widget: route, overlay: overlay));
    _updateDisplayedRoutes();
  }

  void pop() {
    routes.removeLast();
    _updateDisplayedRoutes();
  }

  void _updateDisplayedRoutes() {
    int idx;
    for (idx = routes.length - 1; idx >= 0; idx--) {
      if (!routes[idx].overlay) {
        break;
      }
    }

    _displayedRoutes = routes.sublist(idx, routes.length).toList();
  }
}

class Navigator extends StatelessWidget {
  final Widget? initialRoute;
  final Widget Function(Route route) routeBuilder;

  const Navigator({super.key, this.initialRoute, this.routeBuilder = buildRouteDefault});

  @override
  Widget build(BuildContext context) {
    return SharedState(
      initState: () => _NavigationState(initialRoute),
      child: Builder(
        builder: (context) {
          final state = SharedState.get<_NavigationState>(context);
          return Stack(children: state.displayedRoutes.map(routeBuilder).toList());
        },
      ),
    );
  }

  // ---

  static Widget buildRouteDefault(Route route) => Overlay(child: route.widget);

  // ---

  static void push(BuildContext context, Widget route) =>
      SharedState.set<_NavigationState>(context, (state) => state.push(route, false));

  static void pushOverlay(BuildContext context, Widget route) =>
      SharedState.set<_NavigationState>(context, (state) => state.push(route, true));

  static void pop(BuildContext context) => SharedState.set<_NavigationState>(context, (state) => state.pop());
}

// ---

class OverlayEntry {
  OverlayEntry._({
    required OverlayState owner,
    required Widget widget,
    required void Function() onRemove,
    required this.dismissOnOverlayClick,
    required this.occludeHitTest,
    required this.x,
    required this.y,
  }) : _onRemove = onRemove,
       _widget = widget,
       _owner = owner;

  final OverlayState _owner;
  final Widget _widget;
  final void Function() _onRemove;

  bool dismissOnOverlayClick;
  bool occludeHitTest;

  double x;
  double y;

  // ---

  void remove() => _owner.setState(() {
    _onRemove();
    _owner._entries.remove(this);
  });
}

class Overlay extends StatefulWidget {
  final Widget child;
  const Overlay({super.key, required this.child});

  @override
  WidgetState<Overlay> createState() => OverlayState();

  // ---

  static OverlayState? maybeOf(BuildContext context) => context.getAncestor<_OverlayProvider>()?.state;
  static OverlayState of(BuildContext context) => maybeOf(context)!;
}

extension type RelativePosition._(({BuildContext context, double x, double y}) _value) {
  RelativePosition({required BuildContext context, required double x, required double y})
    : _value = (context: context, x: x, y: y);

  (double x, double y) convertTo(BuildContext ancestor) {
    final contextInstance = _value.context.instance!;
    final ancestorInstance = ancestor.instance!;

    // we might consider allowing this and just figure out the correct
    // direction for computing the transform by looking at the instance
    // depths
    assert(
      contextInstance.ancestors.contains(ancestorInstance),
      'a RelativePosition can only be converted to the coordinate system of an ancestor',
    );

    return (contextInstance.computeTransformFrom(ancestor: ancestorInstance)..invert()).transform2(_value.x, _value.y);
  }
}

class OverlayState extends WidgetState<Overlay> {
  OverlayEntry add(
    Widget widget, {
    RelativePosition? position,
    void Function() onRemove = _doNothing,
    bool dismissOnOverlayClick = false,
    bool occludeHitTest = false,
  }) {
    final (entryX, entryY) = position != null ? position.convertTo(context) : const (0.0, 0.0);

    final entry = OverlayEntry._(
      owner: this,
      widget: widget,
      onRemove: onRemove,
      dismissOnOverlayClick: dismissOnOverlayClick,
      occludeHitTest: occludeHitTest,
      x: entryX,
      y: entryY,
    );

    setState(() {
      _entries.add(entry);
    });

    return entry;
  }

  // ---

  final List<OverlayEntry> _entries = [];

  @override
  Widget build(BuildContext context) {
    return _OverlayProvider(
      state: this,
      child: Stack(
        children: [
          widget.child,
          HitTestTrap(
            occludeHitTest: _entries.any((element) => element.occludeHitTest),
            child: MouseArea(
              clickCallback: (x, y, button) {
                if (_entries.none((entry) => entry.dismissOnOverlayClick)) return false;

                for (final entry in _entries.where((entry) => entry.dismissOnOverlayClick)) {
                  entry._onRemove();
                }

                setState(() {
                  _entries.removeWhere((entry) => entry.dismissOnOverlayClick);
                });

                return false;
              },
              child: const EmptyWidget(),
            ),
          ),
          RawOverlay(
            children: [for (final entry in _entries) RawOverlayElement(x: entry.x, y: entry.y, child: entry._widget)],
          ),
        ],
      ),
    );
  }

  static void _doNothing() {}
}

class _OverlayProvider extends InheritedWidget {
  final OverlayState state;
  _OverlayProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant InheritedWidget newWidget) => false;
}

class RawOverlayElement extends VisitorWidget {
  final double x, y;
  const RawOverlayElement({super.key, required this.x, required this.y, required super.child});

  static void _visitor(RawOverlayElement widget, WidgetInstance instance) {
    if (instance.parentData case OverlayParentData data) {
      data.x = widget.x;
      data.y = widget.y;
    } else {
      instance.parentData = OverlayParentData(x: widget.x, y: widget.y);
    }

    instance.markNeedsLayout();
  }

  @override
  VisitorProxy<RawOverlayElement> proxy() => VisitorProxy(this, _visitor);
}

class RawOverlay extends MultiChildInstanceWidget {
  const RawOverlay({super.key, required super.children});

  @override
  MultiChildWidgetInstance<RawOverlay> instantiate() => _RawOverlayInstance(widget: this);
}

class OverlayParentData {
  double x, y;
  OverlayParentData({required this.x, required this.y});
}

class _RawOverlayInstance extends MultiChildWidgetInstance<RawOverlay> {
  _RawOverlayInstance({required super.widget});

  @override
  W adopt<W extends WidgetInstance?>(W child) {
    if (child?.parentData is! OverlayParentData) {
      child?.parentData = OverlayParentData(x: 0, y: 0);
    }

    return super.adopt<W>(child);
  }

  @override
  void doLayout(Constraints constraints) {
    for (final child in children) {
      child.layout(const Constraints.only());

      final parentData = child.parentData as OverlayParentData;
      child.transform.x = parentData.x;
      child.transform.y = parentData.y;
    }

    transform.setSize(constraints.maxSize);
  }

  @override
  double measureIntrinsicWidth(double height) => 0;

  @override
  double measureIntrinsicHeight(double width) => 0;

  @override
  double? measureBaselineOffset() => null;
}

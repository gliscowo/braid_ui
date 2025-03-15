import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'constraints.dart';
import 'math.dart';

// class Overlay extends WidgetInstance {
//   @override
//   void doLayout(Constraints constraints) => transform.setSize(constraints.minSize);

//   @override
//   void draw(DrawContext ctx) {}
// }

// class Overlay extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   late MouseArea _mouseArea;

//   Overlay({
//     bool barrierDismissable = false,
//     required WidgetInstance Function(Overlay overlay) contentBuilder,
//   }) : super.lateChild() {
//     initChild(HitTestOccluder(
//       child: _mouseArea = MouseArea(
//         clickCallback: barrierDismissable ? close : null,
//         child: PanelInstance(
//           color: Color.black.copyWith(a: .75),
//           cornerRadius: 0,
//           child: CenterInstance(
//             child: HitTestOccluder(
//               child: contentBuilder(this),
//             ),
//           ),
//         ),
//       ),
//     ));
//   }

//   static void open({
//     bool barrierDismissable = false,
//     required WidgetInstance context,
//     required WidgetInstance Function(Overlay overlay) contentBuilder,
//   }) {
//     final scaffold = context.ancestorOfType<AppScaffold>();
//     if (scaffold == null) {
//       throw 'missing scaffold to mount overlay';
//     }

//     scaffold.addOverlay(Overlay(
//       barrierDismissable: barrierDismissable,
//       contentBuilder: contentBuilder,
//     ));
//   }

//   void close() => ancestorOfType<AppScaffold>()!.removeOverlay(this);

//   bool get barrierDismissable => _mouseArea.clickCallback != null;
//   set barrierDismissable(bool value) {
//     _mouseArea.clickCallback = value ? close : null;
//   }
// }

class AppScaffold extends SingleChildInstanceWidget {
  final BuildScope scope;

  AppScaffold({
    required Widget app,
    required this.scope,
  }) : super(child: app);

  @override
  AppScaffoldProxy proxy() => AppScaffoldProxy(this);

  @override
  AppRoot instantiate() => AppRoot(widget: this);
}

class AppScaffoldProxy extends SingleChildInstanceWidgetProxy {
  AppScaffoldProxy(super.widget);

  @override
  bool mounted = false;

  void setup() {
    mounted = true;

    child = refreshChild(child, (widget as SingleChildInstanceWidget).child);
    instance.child = child!.associatedInstance;

    depth = 0;
  }

  @override
  BuildScope get buildScope => (widget as AppScaffold).scope;
}

class AppRoot extends WidgetInstance<SingleChildInstanceWidget>
    with ChildRenderer, ChildListRenderer
    implements SingleChildWidgetInstance {
  late WidgetInstance _root;
  // final List<Overlay> _overlays = [];

  AppRoot({
    required super.widget,
  });

  WidgetInstance get root => _root;
  set root(WidgetInstance value) {
    if (_root == value) return;

    _root.dispose();
    _root = value;
  }

  @override
  void doLayout(Constraints constraints) {
    var selfSize = Size.zero;
    visitChildren((child) {
      selfSize = Size.max(selfSize, child.layout(constraints));
    });

    transform.setSize(selfSize.constrained(constraints));
  }

  // void addOverlay(Overlay overlay) {
  //   _overlays.add(overlay..parent = this);
  //   markNeedsLayout();
  // }

  // void removeOverlay(Overlay overlay) {
  //   _overlays.remove(overlay);
  //   overlay.dispose();
  //   markNeedsLayout();
  // }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    if (hasParent) return;

    if (constraints case Constraints constraints) {
      layout(constraints);
    }
  }

  @override
  WidgetInstance<InstanceWidget>? get _child => _root;

  @override
  WidgetInstance<InstanceWidget> get child => _root;

  @override
  set _child(WidgetInstance<InstanceWidget>? __child) => _root = __child!;

  @override
  set child(WidgetInstance<InstanceWidget> value) => _root = value;

  @override
  void visitChildren(WidgetInstanceVisitor visitor) {
    visitor(_root);
  }
}

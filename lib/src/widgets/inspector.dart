import 'dart:async';

import 'package:diamond_gl/diamond_gl.dart' hide Window;

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'button.dart';
import 'collapsible.dart';
import 'drag_arena.dart';
import 'flex.dart';
import 'icon.dart';
import 'scroll.dart';
import 'stack.dart';
import 'text.dart';
import 'theme.dart';
import 'window.dart';

class BraidInspector {
  final StreamController<()> _triggerStream = StreamController.broadcast(sync: true);
  final StreamController<()> _refreshStream = StreamController.broadcast(sync: true);

  WidgetProxy? rootProxy;
  WidgetInstance? rootInstance;

  void activate() {
    _triggerStream.add(const ());
  }

  void refresh() {
    _refreshStream.add(const ());
  }

  Stream<()> get triggerEvents => _triggerStream.stream;
  Stream<()> get refreshEvents => _refreshStream.stream;
}

class InspectableTree extends StatefulWidget {
  final BraidInspector inspector;
  final Widget tree;

  const InspectableTree({super.key, required this.inspector, required this.tree});

  @override
  WidgetState<InspectableTree> createState() => _InspectableTreeState();
}

enum _Tree { proxy, instance }

class _InspectableTreeState extends WidgetState<InspectableTree> {
  late List<StreamSubscription> subscriptions;
  bool active = false;

  _Tree tree = _Tree.instance;

  @override
  void init() {
    super.init();
    subscriptions = [
      widget.inspector.triggerEvents.listen((_) => setState(() => active = true)),
      widget.inspector.refreshEvents.listen((_) => setState(() {})),
    ];
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.tree,
        if (active)
          BraidTheme(
            // textStyle: TextStyle(color: Color.white, fontSize: 16.0, bold: false, italic: false),
            child: DragArena(
              children: [
                Window(
                  title: 'braid inspector',
                  onClose: () => setState(() => active = false),
                  content: Column(
                    children: [
                      Flexible(
                        child: Column(
                          key: Key(tree.name),
                          children: [
                            Text(
                              tree == _Tree.proxy
                                  ? 'proxies: ${_countProxies(widget.inspector.rootProxy!)}'
                                  : 'instances: ${_countInstances(widget.inspector.rootInstance!)}',
                            ),
                            Flexible(
                              child: Padding(
                                insets: const Insets(bottom: 10),
                                child: ScrollWithSlider(
                                  content:
                                      tree == _Tree.proxy
                                          ? _constructProxyTree(widget.inspector.rootProxy!)
                                          : _constructInstanceTree(widget.inspector.rootInstance!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Button(
                              onClick: tree != _Tree.instance ? () => setState(() => tree = _Tree.instance) : null,
                              child: Text('instances'),
                            ),
                          ),
                          Flexible(
                            child: Button(
                              onClick: tree != _Tree.proxy ? () => setState(() => tree = _Tree.proxy) : null,
                              child: Text('proxies'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _constructProxyTree(WidgetProxy from) {
    final title = Text(from.toString(), softWrap: false);

    final children = <WidgetProxy>[];
    from.visitChildren(children.add);

    return children.isNotEmpty
        ? CollapsibleEntry(title: title, content: Column(children: children.map(_constructProxyTree).toList()))
        : Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Icon(icon: Icons.fiber_manual_record, size: 18), title],
        );
  }

  Widget _constructInstanceTree(WidgetInstance from) {
    final title = InstanceTitle(instance: from);

    final children = <WidgetInstance>[];
    from.visitChildren(children.add);

    return children.isNotEmpty
        ? CollapsibleEntry(title: title, content: Column(children: children.map(_constructInstanceTree).toList()))
        : Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Icon(icon: Icons.fiber_manual_record, size: 18), title],
        );
  }

  int _countProxies(WidgetProxy proxy) {
    var count = 0;
    proxy.visitChildren((child) {
      count++;
      count += _countProxies(child);
    });

    return count;
  }

  int _countInstances(WidgetInstance instance) {
    var count = 0;
    instance.visitChildren((child) {
      count++;
      count += _countInstances(child);
    });

    return count;
  }
}

class CollapsibleEntry extends StatefulWidget {
  final Widget title;
  final Widget content;

  const CollapsibleEntry({super.key, required this.title, required this.content});

  @override
  WidgetState<CollapsibleEntry> createState() => _CollapsibleEntryState();
}

class _CollapsibleEntryState extends WidgetState<CollapsibleEntry> {
  bool collapsed = true;

  @override
  void init() {
    super.init();
    collapsed = widget.content is! Column || (widget.content as Column).children.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    return Collapsible(
      collapsed: collapsed,
      onToggled:
          (nowCollapsed) => setState(() {
            collapsed = nowCollapsed;
          }),
      title: widget.title,
      content: widget.content,
    );
  }
}

class InstanceTitle extends StatefulWidget {
  final WidgetInstance instance;
  const InstanceTitle({super.key, required this.instance});

  @override
  WidgetState<InstanceTitle> createState() => _InstanceTitleState();
}

class _InstanceTitleState extends WidgetState<InstanceTitle> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        Text(widget.instance.runtimeType.toString(), softWrap: false, style: TextStyle(bold: hovered)),
        if (widget.instance.isRelayoutBoundary)
          Padding(
            insets: const Insets(left: 5),
            child: Icon(icon: Icons.border_outer, size: 20, color: const Color.rgb(0x6DE1D2)),
          ),
      ],
    );

    return MouseArea(
      enterCallback:
          () => setState(() {
            widget.instance.debugHighlighted = true;
            hovered = true;
          }),
      exitCallback:
          () => setState(() {
            widget.instance.debugHighlighted = false;
            hovered = false;
          }),
      cursorStyle: CursorStyle.crosshair,
      child: title,
    );
  }
}

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'flex.dart';
import 'icon.dart';

class Collapsible extends StatelessWidget {
  final bool collapsed;
  final void Function(bool nowCollapsed) onToggled;
  final Widget title;
  final Widget content;

  const Collapsible({
    super.key,
    required this.collapsed,
    required this.onToggled,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Actions.click(
              cursorStyle: CursorStyle.hand,
              onClick: () => onToggled(!collapsed),
              child: Icon(icon: collapsed ? Icons.arrow_right : Icons.arrow_drop_down, size: 20),
            ),
            Sized(height: 24, child: title),
          ],
        ),
        Visibility(
          visible: !collapsed,
          child: Padding(insets: const Insets(left: 20), child: content),
        ),
      ],
    );
  }
}

class LazyCollapsible extends StatefulWidget {
  final bool collapsed;
  final void Function(bool nowCollapsed) onToggled;
  final Widget title;
  final Widget content;

  LazyCollapsible({
    super.key,
    required this.collapsed,
    required this.onToggled,
    required this.title,
    required this.content,
  });

  @override
  WidgetState<LazyCollapsible> createState() => _LazyCollapsibleState();
}

class _LazyCollapsibleState extends WidgetState<LazyCollapsible> {
  bool expandedOnce = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsed && !expandedOnce) {
      expandedOnce = true;
    }

    return Collapsible(
      collapsed: widget.collapsed,
      onToggled: widget.onToggled,
      title: widget.title,
      content: expandedOnce ? widget.content : const Padding(insets: Insets()),
    );
  }
}

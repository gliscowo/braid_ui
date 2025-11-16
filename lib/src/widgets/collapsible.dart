import '../animation/easings.dart';
import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'basic.dart';
import 'flex.dart';
import 'icon.dart';
import 'stack.dart';
import 'theme.dart';

class Collapsible extends StatefulWidget {
  final bool showVerticalRule;

  final bool collapsed;
  final void Function(bool nowCollapsed) onToggled;

  final Widget title;
  final Widget content;

  const Collapsible({
    super.key,
    this.showVerticalRule = false,
    required this.collapsed,
    required this.onToggled,
    required this.title,
    required this.content,
  });

  @override
  WidgetState<Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends WidgetState<Collapsible> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MouseArea(
          enterCallback: widget.showVerticalRule
              ? () => setState(() {
                  hovered = true;
                })
              : null,
          exitCallback: widget.showVerticalRule
              ? () => setState(() {
                  hovered = false;
                })
              : null,
          child: Row(
            crossAxisAlignment: .center,
            children: [
              Actions.click(
                cursorStyle: CursorStyle.hand,
                onClick: () => widget.onToggled(!widget.collapsed),
                child: Icon(icon: widget.collapsed ? Icons.arrow_right : Icons.arrow_drop_down, size: 20),
              ),
              Sized(height: 24, child: widget.title),
            ],
          ),
        ),
        Visibility(
          visible: !widget.collapsed,
          child: Stack(
            children: [
              if (widget.showVerticalRule)
                Align(
                  alignment: Alignment.left,
                  child: Padding(
                    insets: const Insets(left: 9),
                    child: Sized(
                      width: 2,
                      height: double.infinity,
                      child: AnimatedPanel(
                        duration: const Duration(milliseconds: 125),
                        easing: Easing.inOutExpo,
                        color: hovered ? BraidTheme.of(context).elementColor : BraidTheme.of(context).elevatedColor,
                      ),
                    ),
                  ),
                ),
              StackBase(
                child: Padding(insets: const Insets(left: 20), child: widget.content),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LazyCollapsible extends StatefulWidget {
  final bool showVerticalRule;

  final bool collapsed;
  final void Function(bool nowCollapsed) onToggled;

  final Widget title;
  final Widget content;

  LazyCollapsible({
    super.key,
    this.showVerticalRule = false,
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
      showVerticalRule: widget.showVerticalRule,
      collapsed: widget.collapsed,
      onToggled: widget.onToggled,
      title: widget.title,
      content: expandedOnce ? widget.content : const Padding(insets: Insets()),
    );
  }
}

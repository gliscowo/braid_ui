import '../core/cursors.dart';
import '../core/math.dart';
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
              child: Icon(icon: collapsed ? Icons.arrow_right : Icons.arrow_drop_down, size: 24),
            ),
            Sized(height: 24, child: title),
          ],
        ),
        Visibility(visible: !collapsed, child: Padding(insets: const Insets(left: 24), child: content)),
      ],
    );
  }
}

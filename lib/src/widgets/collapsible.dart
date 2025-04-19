import '../../braid_ui.dart';
import '../baked_assets.g.dart';
import '../framework/widget.dart';
import 'basic.dart';
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
            MouseArea(
              clickCallback: (_, _) => onToggled(!collapsed),
              cursorStyle: CursorStyle.hand,
              child: Icon(icon: collapsed ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 24),
            ),
            Sized(height: 24, child: title),
          ],
        ),
        Visibility(visible: !collapsed, child: Padding(insets: const Insets(left: 24), child: content)),
      ],
    );
  }
}

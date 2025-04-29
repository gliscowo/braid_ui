import 'package:diamond_gl/diamond_gl.dart';

import '../../braid_ui.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'basic.dart';
import 'container.dart';
import 'stack.dart';

class NotificationData {
  final String message;
  const NotificationData({required this.message});
}

class NotificationArea extends StatefulWidget {
  final Alignment notificationAlignment;
  final Widget child;

  const NotificationArea({super.key, this.notificationAlignment = Alignment.bottomRight, required this.child});

  @override
  WidgetState<StatefulWidget> createState() => _NotificationAreaState();

  static void send(BuildContext context, NotificationData notification) {
    final provider = context.dependOnAncestor<_NotificationStateProvider>();
    if (provider == null) return;

    provider.state.addNotification(notification);
  }
}

class _NotificationStateProvider extends InheritedWidget {
  final _NotificationAreaState state;
  _NotificationStateProvider({required this.state, required super.child});

  @override
  bool mustRebuildDependents(covariant _NotificationStateProvider newWidget) {
    return state != newWidget.state;
  }
}

class _NotificationState {
  final NotificationData data;
  bool visible = true;

  _NotificationState(this.data);
}

class _NotificationAreaState extends WidgetState<NotificationArea> {
  final List<_NotificationState> _activeNotifications = [];

  @override
  Widget build(BuildContext context) {
    return _NotificationStateProvider(
      state: this,
      child: Stack(
        children: [
          widget.child,
          Align(
            alignment: widget.notificationAlignment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final state in _activeNotifications)
                  AnimatedSized(
                    easing: Easing.inOutCubic,
                    duration: Duration(milliseconds: 750),
                    width: state.visible ? 150 : 0,
                    height: state.visible ? 50 : 0,
                    child: Notification(data: state.data),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void addNotification(NotificationData notification) async {
    final state = _NotificationState(notification);
    setState(() {
      _activeNotifications.add(state);
    });

    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      state.visible = false;
    });

    await Future.delayed(const Duration(milliseconds: 750));
    setState(() {
      _activeNotifications.remove(state);
    });
  }
}

class Notification extends StatelessWidget {
  final NotificationData data;
  Notification({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const Insets.all(5),
      margin: const Insets.all(5),
      color: Color.blue,
      cornerRadius: const CornerRadius.all(10),
      child: Clip(child: Text(data.message, softWrap: false)),
    );
  }
}

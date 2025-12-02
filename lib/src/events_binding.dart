import 'dart:async';

import 'package:clawclip/clawclip.dart';
import 'package:clawclip/glfw.dart';
import 'package:meta/meta.dart';

import 'core/key_modifiers.dart';

@immutable
sealed class UserEvent {
  const UserEvent();
}

final class MouseMoveEvent extends UserEvent {
  final double x;
  final double y;
  final double deltaX;
  final double deltaY;
  MouseMoveEvent(this.x, this.y, this.deltaX, this.deltaY);
}

final class MouseButtonPressEvent extends UserEvent {
  final int button;
  final KeyModifiers modifiers;
  MouseButtonPressEvent(this.button, this.modifiers);
}

final class MouseButtonReleaseEvent extends UserEvent {
  final int button;
  MouseButtonReleaseEvent(this.button);
}

final class MouseScrollEvent extends UserEvent {
  final double xOffset;
  final double yOffset;
  MouseScrollEvent(this.xOffset, this.yOffset);
}

final class KeyPressEvent extends UserEvent {
  final int glfwKeycode;
  final int scancode;
  final KeyModifiers modifiers;
  final bool repeat;
  KeyPressEvent(this.glfwKeycode, this.scancode, this.modifiers, this.repeat);
}

final class KeyReleaseEvent extends UserEvent {
  final int glfwKeycode;
  final int scancode;
  final KeyModifiers modifiers;
  KeyReleaseEvent(this.glfwKeycode, this.scancode, this.modifiers);
}

final class CharInputEvent extends UserEvent {
  final int codepoint;
  final KeyModifiers modifiers;
  CharInputEvent(this.codepoint, this.modifiers);
}

final class FilesDroppedEvent extends UserEvent {
  final List<String> paths;
  FilesDroppedEvent(this.paths);
}

final class CloseEvent extends UserEvent {
  const CloseEvent();
}

abstract interface class EventsBinding {
  List<UserEvent> poll();
  bool isKeyPressed(int glfwKeyCode);

  void dispose();
}

class WindowEventsBinding extends EventsBinding {
  final Window window;

  final List<UserEvent> _bufferedEvents = [];
  final List<StreamSubscription> _subscriptions = [];

  WindowEventsBinding({required this.window}) {
    _subscriptions.addAll([
      window.onMouseMove.listen((event) => _bufferedEvents.add(MouseMoveEvent(event.x, event.y, event.dx, event.dy))),
      window.onMouseButton.listen(
        (event) => _bufferedEvents.add(switch (event.action) {
          glfwPress => MouseButtonPressEvent(event.button, KeyModifiers(event.mods)),
          glfwRelease => MouseButtonReleaseEvent(event.button),
          // TODO: proper error type
          _ => throw 'incompatible glfw event type',
        }),
      ),
      window.onMouseScroll.listen((event) => _bufferedEvents.add(MouseScrollEvent(event.xOffset, event.yOffset))),
      window.onKey.listen(
        (event) => _bufferedEvents.add(switch (event.action) {
          glfwPress ||
          glfwRepeat => KeyPressEvent(event.key, event.scancode, KeyModifiers(event.mods), event.action == glfwRepeat),
          glfwRelease => KeyReleaseEvent(event.key, event.scancode, KeyModifiers(event.mods)),
          // TODO: proper error type
          _ => throw 'incompatible glfw event type',
        }),
      ),
      window.onCharMods.listen(
        (event) => _bufferedEvents.add(CharInputEvent(event.codepoint, KeyModifiers(event.mods))),
      ),
      window.onFilesDropped.listen((event) => _bufferedEvents.add(FilesDroppedEvent(event.paths))),
      window.onClose.listen((event) => _bufferedEvents.add(const CloseEvent())),
    ]);
  }

  @override
  List<UserEvent> poll() {
    final events = List.of(_bufferedEvents);
    _bufferedEvents.clear();

    return events;
  }

  @override
  bool isKeyPressed(int glfwKeyCode) => glfwGetKey(window.handle, glfwKeyCode) == glfwPress;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _subscriptions.clear();
  }
}

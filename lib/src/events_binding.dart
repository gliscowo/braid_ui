import 'dart:async';
import 'dart:ffi';

import 'package:clawclip/clawclip.dart';
import 'package:clawclip/sdl.dart';
import 'package:meta/meta.dart';

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
  final int sdlKey;
  final SDLScancode scancode;
  final KeyModifiers modifiers;
  final bool repeat;
  KeyPressEvent(this.sdlKey, this.scancode, this.modifiers, this.repeat);
}

final class KeyReleaseEvent extends UserEvent {
  final int sdlKey;
  final SDLScancode scancode;
  final KeyModifiers modifiers;
  KeyReleaseEvent(this.sdlKey, this.scancode, this.modifiers);
}

final class TextInputEvent extends UserEvent {
  final String text;
  TextInputEvent(this.text);
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
  bool isKeyPressed(int sdlKey);
  KeyModifiers get currentModifiers;

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
        (event) => _bufferedEvents.add(switch (event.down) {
          true => MouseButtonPressEvent(event.button, event.mods),
          false => MouseButtonReleaseEvent(event.button),
        }),
      ),
      window.onMouseScroll.listen((event) => _bufferedEvents.add(MouseScrollEvent(event.xOffset, event.yOffset))),
      window.onKey.listen(
        (event) => _bufferedEvents.add(switch (event.action) {
          .press || .repeat => KeyPressEvent(event.key, event.scancode, event.mods, event.action == .repeat),
          .release => KeyReleaseEvent(event.key, event.scancode, event.mods),
        }),
      ),
      window.onTextInput.listen((event) => _bufferedEvents.add(TextInputEvent(event.text))),
      window.onFilesDropped.listen((event) => _bufferedEvents.add(FilesDroppedEvent(event.paths))),
      window.onClose.listen((event) => _bufferedEvents.add(const CloseEvent())),
    ]);
  }

  Pointer<Bool> _currentKeyboardState = nullptr;

  @override
  List<UserEvent> poll() {
    _currentKeyboardState = sdlGetKeyboardState(nullptr);

    final events = List.of(_bufferedEvents);
    _bufferedEvents.clear();

    return events;
  }

  @override
  bool isKeyPressed(int sdlKey) => _currentKeyboardState[sdlGetScancodeFromKey(sdlKey, nullptr).value];

  @override
  KeyModifiers get currentModifiers => KeyModifiers(sdlGetModState());

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    _subscriptions.clear();
  }
}

import 'dart:ffi';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';

enum CursorStyle {
  none(0),
  pointer(glfwArrowCursor),
  text(glfwIbeamCursor),
  hand(glfwHandCursor),
  move(glfwResizeAllCursor);

  final int glfw;
  const CursorStyle(this.glfw);
}

class CursorController {
  static const List<CursorStyle> activeStyles = [
    CursorStyle.pointer,
    CursorStyle.text,
    CursorStyle.hand,
    CursorStyle.move
  ];

  final Map<CursorStyle, Pointer<GLFWcursor>> _cursors = {};
  final Window _window;

  CursorStyle _lastCursorStyle = CursorStyle.pointer;
  bool _disposed = false;

  CursorController.ofWindow(this._window) {
    for (final style in activeStyles) {
      _cursors[style] = glfw.createStandardCursor(style.glfw);
    }
  }

  set style(CursorStyle style) {
    if (_disposed || _lastCursorStyle == style) return;

    if (style == CursorStyle.none) {
      glfw.setCursor(_window.handle, nullptr);
    } else {
      glfw.setCursor(_window.handle, _cursors[style]!);
    }

    _lastCursorStyle = style;
  }

  void dispose() {
    if (_disposed) return;

    for (final ptr in _cursors.values) {
      if (ptr == nullptr) continue;
      glfw.destroyCursor(ptr);
    }
    _disposed = true;
  }
}

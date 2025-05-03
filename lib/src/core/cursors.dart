import 'dart:ffi';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';

sealed class CursorStyle {
  static const none = _SystemCursorStyle(0);
  static const pointer = _SystemCursorStyle(glfwArrowCursor);
  static const text = _SystemCursorStyle(glfwIbeamCursor);
  static const hand = _SystemCursorStyle(glfwHandCursor);
  static const move = _SystemCursorStyle(glfwResizeAllCursor);
  static const crosshair = _SystemCursorStyle(glfwCrosshairCursor);
  static const horizontalResize = _SystemCursorStyle(glfwHresizeCursor);
  static const verticalResize = _SystemCursorStyle(glfwVresizeCursor);
  static const nwseResize = _SystemCursorStyle(glfwResizeNwseCursor);
  static const neswResize = _SystemCursorStyle(glfwResizeNeswCursor);
  static const notAllowed = _SystemCursorStyle(glfwNotAllowedCursor);

  factory CursorStyle.custom(Image image, int hotspotX, int hotspotY) = _CustomCursorStyle.new;

  Pointer<GLFWcursor> allocate();
}

final class _SystemCursorStyle implements CursorStyle {
  final int glfwId;
  const _SystemCursorStyle(this.glfwId);

  @override
  Pointer<GLFWcursor> allocate() {
    return glfw.createStandardCursor(glfwId);
  }
}

final class _CustomCursorStyle implements CursorStyle {
  final Image image;
  final int hotspotX;
  final int hotspotY;

  _CustomCursorStyle(this.image, this.hotspotX, this.hotspotY);

  @override
  Pointer<GLFWcursor> allocate() {
    var glfwImage = malloc<GLFWimage>();
    glfwImage.ref.width = image.width;
    glfwImage.ref.height = image.height;

    final convertedIcon = image.convert(format: Format.uint8, numChannels: 4, alpha: 255);

    final bufferSize = convertedIcon.width * convertedIcon.height * convertedIcon.numChannels;
    final glfwBuffer = malloc<Uint8>(bufferSize);

    glfwBuffer.asTypedList(bufferSize).setRange(0, bufferSize, convertedIcon.data!.buffer.asUint8List());
    glfwImage.ref.pixels = glfwBuffer.cast();

    final cursor = glfw.createCursor(glfwImage, hotspotX, hotspotY);
    malloc.free(glfwBuffer);
    malloc.free(glfwImage);

    return cursor;
  }
}

class CursorController {
  final Map<CursorStyle, Pointer<GLFWcursor>> _cursors = {};
  final Window _window;

  CursorStyle _lastCursorStyle = CursorStyle.none;
  bool _disposed = false;

  CursorController.ofWindow(this._window);

  set style(CursorStyle style) {
    if (_disposed || _lastCursorStyle == style) return;

    if (style == CursorStyle.none) {
      glfw.setCursor(_window.handle, nullptr);
    } else {
      if (!_cursors.containsKey(style)) {
        _cursors[style] = style.allocate();
      }

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

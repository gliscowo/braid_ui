import 'dart:ffi';

import 'package:clawclip/sdl.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';

sealed class CursorStyle {
  static const none = _SystemCursorStyle(.systemCursorDefault);
  static const pointer = _SystemCursorStyle(.systemCursorDefault);
  static const text = _SystemCursorStyle(.systemCursorText);
  static const hand = _SystemCursorStyle(.systemCursorPointer);
  static const move = _SystemCursorStyle(.systemCursorMove);
  static const crosshair = _SystemCursorStyle(.systemCursorCrosshair);
  static const horizontalResize = _SystemCursorStyle(.systemCursorEwResize);
  static const verticalResize = _SystemCursorStyle(.systemCursorNsResize);
  static const nwseResize = _SystemCursorStyle(.systemCursorNwseResize);
  static const neswResize = _SystemCursorStyle(.systemCursorNeswResize);
  static const notAllowed = _SystemCursorStyle(.systemCursorNotAllowed);

  factory CursorStyle.custom(Image image, int hotspotX, int hotspotY) = _CustomCursorStyle.new;

  Pointer<SDLCursor> allocate();
}

final class _SystemCursorStyle implements CursorStyle {
  final SDLSystemCursor sdlId;
  const _SystemCursorStyle(this.sdlId);

  @override
  Pointer<SDLCursor> allocate() {
    return sdlCreateSystemCursor(sdlId);
  }
}

final class _CustomCursorStyle implements CursorStyle {
  final Image image;
  final int hotspotX;
  final int hotspotY;

  _CustomCursorStyle(this.image, this.hotspotX, this.hotspotY);

  @override
  Pointer<SDLCursor> allocate() {
    final convertedIcon = image.convert(format: Format.uint8, numChannels: 4, alpha: 255);

    final bufferSize = convertedIcon.width * convertedIcon.height * convertedIcon.numChannels;
    final pixelBuffer = malloc<Uint8>(bufferSize);

    pixelBuffer.asTypedList(bufferSize).setRange(0, bufferSize, convertedIcon.data!.buffer.asUint8List());
    final surface = sdlCreateSurfaceFrom(
      image.width,
      image.height,
      .pixelformatRgba32,
      pixelBuffer.cast(),
      image.rowStride,
    );

    final cursor = sdlCreateColorCursor(surface, hotspotX, hotspotY);
    malloc.free(pixelBuffer);
    sdlDestroySurface(surface);

    return cursor;
  }
}

class CursorController {
  final Map<CursorStyle, Pointer<SDLCursor>> _cursors = {};

  CursorStyle _lastCursorStyle = CursorStyle.none;
  bool _disposed = false;

  CursorStyle get style => _lastCursorStyle;
  set style(CursorStyle style) {
    if (_disposed || _lastCursorStyle == style) return;

    if (style == CursorStyle.none) {
      sdlSetCursor(sdlGetDefaultCursor());
    } else {
      if (!_cursors.containsKey(style)) {
        _cursors[style] = style.allocate();
      }

      sdlSetCursor(_cursors[style]!);
    }

    _lastCursorStyle = style;
  }

  void dispose() {
    if (_disposed) return;

    for (final ptr in _cursors.values) {
      if (ptr == nullptr) continue;
      sdlDestroyCursor(ptr);
    }
    _disposed = true;
  }
}

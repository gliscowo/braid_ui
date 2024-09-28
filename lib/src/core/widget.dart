import 'package:diamond_gl/diamond_gl.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../text/text.dart';

class Widget {
  final _transform = Matrix4.identity();
  final _inverseTransform = Matrix4.identity();

  double _width, _height;
  double _x, _y;
  double _rotation, _scale;

  Widget(this._x, this._y, this._width, this._height, {double rotation = 0, double scale = 1})
      : _rotation = rotation,
        _scale = scale {
    _updateTransform(() {});
  }

  set x(double value) => _updateTransform(() => _x = value);
  set y(double value) => _updateTransform(() => _y = value);
  set rotation(double value) => _updateTransform(() => _rotation = value);
  set scale(double value) => _updateTransform(() => _scale = value);

  void draw(DrawContext ctx, bool hovered) {
    ctx.primitives.roundedRect(
        _width, _height, 7.5, hovered ? Color.ofRgb(0x4752c4) : Color.ofRgb(0x5865f2), ctx.transform, ctx.projection);

    ctx.transform.translate(5.0, 5.0);
    ctx.textRenderer.drawText(Text.string("widget :)"), 16, ctx.transform, ctx.projection);
  }

  bool hitTest(double screenX, double screenY) {
    final (x, y) = screenToWidgetSpace(screenX, screenY);
    return x >= 0 && x <= _width && y >= 0 && y <= _height;
  }

  (double, double) widgetToScreenSpace(double x, double y) {
    final vec = Vector4(x, y, 0, 1);
    _transform.transform(vec);
    return (vec.x, vec.y);
  }

  (double, double) screenToWidgetSpace(double x, double y) {
    final vec = Vector4(x, y, 0, 1);
    _inverseTransform.transform(vec);
    return (vec.x, vec.y);
  }

  Matrix4 get transform => _transform;

  void _updateTransform(void Function() action) {
    action();

    _transform
      ..setTranslation(Vector3(_x, _y, 0))
      ..scale(_scale)
      ..translate(_width / 2, _height / 2, 0)
      ..rotateZ(_rotation)
      ..translate(-_width / 2, -_height / 2, 0);

    _inverseTransform.copyInverse(_transform);
  }
}

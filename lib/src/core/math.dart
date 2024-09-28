import 'dart:collection';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

class Size {
  static const Size zero = Size(0, 0);

  final double width, height;
  const Size(this.width, this.height);

  Size copy({double? width, double? height}) => Size(width ?? this.width, height ?? this.height);

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) => other is Size && other.width == width && other.height == height;
}

class Matrix4Stack extends Matrix4 {
  final Queue<Float32List> _stack = Queue();

  Matrix4Stack.identity() : super.zero() {
    setIdentity();
  }

  void scopeWith(Matrix4 transform, void Function(Matrix4 mat4) action) => scope((mat4) {
        mat4.multiply(transform);
        action(mat4);
      });

  void scope(void Function(Matrix4 mat4) action) {
    push();
    action(this);
    pop();
  }

  void push([Matrix4? transform]) {
    _stack.add(Float32List.fromList(storage));

    if (transform != null) {
      multiply(transform);
    }
  }

  void pop() {
    storage.setAll(0, _stack.removeLast());
  }
}

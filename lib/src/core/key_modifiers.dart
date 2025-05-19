import 'package:diamond_gl/glfw.dart';

extension type const KeyModifiers(int bitMask) {
  bool get shift => (bitMask & glfwModShift) != 0;
  bool get ctrl => (bitMask & glfwModControl) != 0;
  bool get alt => (bitMask & glfwModAlt) != 0;
  bool get meta => (bitMask & glfwModSuper) != 0;
  bool get capsLock => (bitMask & glfwModCapsLock) != 0;
  bool get numLock => (bitMask & glfwModNumLock) != 0;

  static const KeyModifiers none = KeyModifiers(0);

  static bool isModifier(int keyCode) => _modifierKeys.contains(keyCode);
  static const _modifierKeys = {
    glfwKeyLeftShift,
    glfwKeyRightShift,
    glfwKeyLeftAlt,
    glfwKeyRightAlt,
    glfwKeyLeftSuper,
    glfwKeyRightSuper,
  };
}

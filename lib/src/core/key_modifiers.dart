import 'package:dart_glfw/dart_glfw.dart';

extension type KeyModifiers(int bitMask) {
  bool get shift => (bitMask & glfwModShift) != 0;
  bool get ctrl => (bitMask & glfwModControl) != 0;
  bool get alt => (bitMask & glfwModAlt) != 0;
  bool get meta => (bitMask & glfwModSuper) != 0;
  bool get capsLock => (bitMask & glfwModCapsLock) != 0;
  bool get numLock => (bitMask & glfwModNumLock) != 0;
}

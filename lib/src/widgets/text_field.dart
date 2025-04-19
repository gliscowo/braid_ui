import 'dart:math';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'basic.dart';
import 'container.dart';
import 'stack.dart';
import 'text.dart';

class TextFieldController {
  int cursorPosition;
  String text;

  TextFieldController({this.cursorPosition = 0, this.text = ''});

  void insert(String insertion) {
    final runes = text.runes.toList();
    runes.insertAll(cursorPosition, insertion.runes);

    text = String.fromCharCodes(runes);
    cursorPosition += insertion.runes.length;
  }
}

class RawTextField extends StatefulWidget {
  final TextFieldController? controller;
  const RawTextField({super.key, this.controller});

  @override
  WidgetState<RawTextField> createState() => RawTextFieldState();
}

class RawTextFieldState extends WidgetState<RawTextField> {
  late TextFieldController controller;
  late BuildContext _lastContext;

  @override
  void init() {
    super.init();
    controller = widget.controller ?? TextFieldController();
  }

  @override
  void didUpdateWidget(RawTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null) {
      controller = widget.controller!;
    }
  }

  @override
  Widget build(BuildContext context) {
    _lastContext = context;
    return MouseArea(
      cursorStyle: CursorStyle.text,
      child: KeyboardInput(
        keyDownCallback: _handleKeypress,
        charCallback: (charCode, modifiers) => setState(() => controller.insert(String.fromCharCode(charCode))),
        child: Container(
          color: const Color.rgb(0x161616),
          cornerRadius: const CornerRadius.all(5),
          padding: const Insets.all(5),
          child: Stack(
            children: [
              Text(text: controller.text, style: const TextStyle(alignment: Alignment.topLeft)),
              Align(
                alignment: Alignment.left,
                child: Padding(
                  insets: const Insets(left: 0),
                  child: Sized(height: 20, width: 1, child: const Panel(color: Color.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeypress(int keyCode, int modifiers) {
    if (keyCode == glfwKeyBackspace) {
      if (controller.text.isEmpty) return;

      final runes = controller.text.runes.toList();
      runes.removeAt(controller.cursorPosition - 1);

      setState(() {
        controller.cursorPosition--;
        controller.text = String.fromCharCodes(runes);
      });
    } else if (keyCode == glfwKeyDelete) {
      if (controller.text.isEmpty) return;

      final runes = controller.text.runes.toList();
      runes.removeAt(controller.cursorPosition);

      setState(() {
        controller.text = String.fromCharCodes(runes);
      });
    } else if (keyCode == glfwKeyV && (modifiers & glfwModControl) != 0) {
      setState(() {
        controller.insert(glfw.getClipboardString(_lastContext.window.handle).cast<Utf8>().toDartString());
      });
    } else if (keyCode == glfwKeyLeft) {
      setState(() {
        controller.cursorPosition = max(0, controller.cursorPosition - 1);
      });
    } else if (keyCode == glfwKeyRight) {
      setState(() {
        controller.cursorPosition = min(controller.text.runes.length, controller.cursorPosition + 1);
      });
    } else if (keyCode == glfwKeyHome) {
      setState(() {
        controller.cursorPosition = 0;
      });
    } else if (keyCode == glfwKeyEnd) {
      setState(() {
        controller.cursorPosition = controller.text.runes.length;
      });
    }
  }
}

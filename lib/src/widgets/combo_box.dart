import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;

import '../core/cursors.dart';
import '../core/listenable.dart';
import '../core/math.dart';
import '../framework/proxy.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'app_stack.dart';
import 'basic.dart';
import 'button.dart';
import 'flex.dart';
import 'icon.dart';
import 'text.dart';
import 'text_input.dart';

class ComboBoxStyle {
  final Color? borderColor;
  final Color? borderHighlightColor;
  final Color? backgroundColor;
  final double? borderThickness;
  final CornerRadius? cornerRadius;
  final TextStyle? textStyle;
  final ButtonStyle? optionButtonStyle;

  const ComboBoxStyle({
    this.borderColor,
    this.borderHighlightColor,
    this.backgroundColor,
    this.borderThickness,
    this.cornerRadius,
    this.textStyle,
    this.optionButtonStyle,
  });

  ComboBoxStyle copy({
    Color? borderColor,
    Color? borderHighlightColor,
    Color? backgroundColor,
    double? borderThickness,
    CornerRadius? cornerRadius,
    TextStyle? textStyle,
    ButtonStyle? optionButtonStyle,
  }) => ComboBoxStyle(
    borderColor: borderColor ?? this.borderColor,
    borderHighlightColor: borderHighlightColor ?? this.borderHighlightColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    borderThickness: borderThickness ?? this.borderThickness,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    textStyle: textStyle ?? this.textStyle,
    optionButtonStyle: optionButtonStyle ?? this.optionButtonStyle,
  );

  ComboBoxStyle overriding(ComboBoxStyle other) {
    var textStyle = this.textStyle;
    if (textStyle != null && other.textStyle != null) {
      textStyle = textStyle.overriding(other.textStyle!);
    }
    textStyle ??= other.textStyle;

    var optionButtonStyle = this.optionButtonStyle;
    if (optionButtonStyle != null && other.optionButtonStyle != null) {
      optionButtonStyle = optionButtonStyle.overriding(other.optionButtonStyle!);
    }
    optionButtonStyle ??= other.optionButtonStyle;

    return ComboBoxStyle(
      borderColor: borderColor ?? other.borderColor,
      borderHighlightColor: borderHighlightColor ?? other.borderHighlightColor,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      borderThickness: borderThickness ?? other.borderThickness,
      cornerRadius: cornerRadius ?? other.cornerRadius,
      textStyle: textStyle,
      optionButtonStyle: optionButtonStyle,
    );
  }

  dynamic get _props =>
      (borderColor, borderHighlightColor, backgroundColor, borderThickness, cornerRadius, optionButtonStyle, textStyle);

  @override
  int get hashCode => _props.hashCode;

  @override
  bool operator ==(Object other) => other is ComboBoxStyle && other._props == _props;
}

class DefaultComboBoxStyle extends InheritedWidget {
  final ComboBoxStyle style;

  DefaultComboBoxStyle({super.key, required this.style, required super.child});

  static Widget merge({required ComboBoxStyle style, required Widget child}) {
    return Builder(
      builder: (context) {
        return DefaultComboBoxStyle(style: style.overriding(of(context)), child: child);
      },
    );
  }

  @override
  bool mustRebuildDependents(covariant DefaultComboBoxStyle newWidget) => newWidget.style != style;

  // ---

  static ComboBoxStyle of(BuildContext context) {
    final widget = context.dependOnAncestor<DefaultComboBoxStyle>();
    assert(widget != null, 'expected an ambient DefaultComboBoxStyle');

    return widget!.style;
  }
}

// ---

class ComboBox<T> extends StatefulWidget {
  final ComboBoxStyle? style;
  final String Function(T option)? optionToString;

  final List<T> options;
  final T? selectedOption;
  final void Function(T option) onSelect;

  ComboBox({
    super.key,
    this.style,
    this.optionToString,
    required this.options,
    required this.selectedOption,
    required this.onSelect,
  });

  @override
  WidgetState<ComboBox<T>> createState() => _ComboBoxState<T>();

  // ---

  Iterable<String> get optionStrings => options.map(stringify);

  String stringify(T? option) => option != null
      ? optionToString != null
            ? optionToString!(option)
            : option.toString()
      : '';
}

class _ComboBoxState<T> extends WidgetState<ComboBox<T>> {
  late TextEditingController controller;
  late String lastText;

  OverlayEntry? currentOverlay;
  ListenableValue<_ComboBoxButtonsState<T>>? buttonsState;

  ComboBoxStyle get computedStyle {
    final contextStyle = DefaultComboBoxStyle.of(context);
    return widget.style?.overriding(contextStyle) ?? contextStyle;
  }

  bool get isOpen => currentOverlay != null;

  @override
  void init() {
    controller = TextEditingController(text: widget.stringify(widget.selectedOption))..addListener(textListener);
    lastText = controller.text;
  }

  @override
  void didUpdateWidget(ComboBox oldWidget) {
    if (widget.selectedOption != oldWidget.selectedOption) {
      resetTextInput();
    }
  }

  @override
  void dispose() {
    controller.removeListener(textListener);
    currentOverlay?.remove();
  }

  void textListener() {
    if (controller.text == lastText) return;
    lastText = controller.text;

    if (widget.optionStrings.contains(controller.text)) {
      return;
    }

    if (!isOpen) {
      open();
    }

    buttonsState!.value = (
      options: controller.text.isNotEmpty
          ? fuzzy
                .extractTop(
                  query: controller.text,
                  choices: widget.options,
                  getter: widget.stringify,
                  limit: 5,
                  cutoff: 50,
                )
                .map((e) => e.choice)
                .toList()
          : widget.options,
      highlightedOptionIdx: null,
    );
  }

  void resetTextInput() {
    controller.text = widget.stringify(widget.selectedOption);
    controller.selection = TextSelection.collapsed(controller.text.length);
  }

  void select(T option) {
    widget.onSelect(option);
    resetTextInput();

    currentOverlay?.remove();
  }

  void trySelectHighlightedValue() {
    final state = buttonsState?.value;
    if (state == null || state.highlightedOptionIdx == null && state.options.isEmpty) {
      return;
    }

    select(state.highlightedOptionIdx != null ? state.options[state.highlightedOptionIdx!] : state.options.first);
  }

  void cycle(int offset) {
    if (isOpen) {
      final state = buttonsState!.value;

      final currentOptionIdx = state.highlightedOptionIdx ?? (offset > 0 ? -1 : 0);
      final nextOptionIdx = (currentOptionIdx + offset) % state.options.length;

      buttonsState!.value = (options: state.options, highlightedOptionIdx: nextOptionIdx);
    } else {
      final currentOptionIdx = widget.selectedOption != null
          ? widget.options.indexOf(widget.selectedOption!)
          : -offset.sign;
      final nextOptionIdx = (currentOptionIdx + offset) % widget.options.length;

      select(widget.options[nextOptionIdx]);
    }
  }

  void open() => setState(() {
    buttonsState = ListenableValue((options: widget.options, highlightedOptionIdx: null));
    currentOverlay = Overlay.of(context).add(
      widget: _ComboBoxButtons<T>(
        state: buttonsState!,
        width: context.instance!.transform.width,
        style: computedStyle,
        optionToString: widget.stringify,
        onSelect: select,
      ),
      position: RelativePosition(context: context, x: 0, y: context.instance!.transform.height),
      dismissOnOverlayClick: true,
      onRemove: () => setState(() {
        currentOverlay = null;
        buttonsState = null;
      }),
    );
  });

  void close() => currentOverlay?.remove();

  @override
  Widget build(BuildContext context) {
    final style = computedStyle;
    final expanded = isOpen;

    var textStyle = style.textStyle!.overriding(DefaultTextStyle.of(context));
    if (!widget.optionStrings.contains(controller.text)) {
      textStyle = textStyle.copy(bold: false);
    }

    return Actions(
      focusLostCallback: resetTextInput,
      skipTraversal: true,
      actions: {
        _previousOptionTrigger: () => cycle(-1),
        _nextOptionTrigger: () => cycle(1),
        _selectHighlightedOptionTrigger: trySelectHighlightedValue,
        const [ActionTrigger.click]: () => expanded ? close() : open(),
      },
      cursorStyle: CursorStyle.hand,
      child: HoverableBuilder(
        builder: (context, hovered, child) {
          return AnimatedPanel(
            duration: const Duration(milliseconds: 100),
            color: (hovered || expanded) ? style.borderHighlightColor! : style.borderColor!,
            cornerRadius: expanded ? const CornerRadius.top(5) : const CornerRadius.all(5),
            child: child,
          );
        },
        child: Padding(
          insets: Insets.all(style.borderThickness!),
          child: Panel(
            color: style.backgroundColor!,
            cornerRadius: expanded ? style.cornerRadius!.copy(bottomLeft: 0, bottomRight: 0) : style.cornerRadius!,
            child: Padding(
              insets: const Insets(top: 3, bottom: 3, left: 5),
              child: Row(
                crossAxisAlignment: .center,
                children: [
                  Flexible(
                    child: EditableText(
                      controller: controller,
                      softWrap: false,
                      allowMultipleLines: false,
                      style: textStyle.toSpanStyle(),
                    ),
                  ),
                  const Padding(
                    insets: Insets.axis(horizontal: 3),
                    child: Icon(icon: Icons.arrow_drop_down, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---

  static const _previousOptionTrigger = [
    ActionTrigger(keyCodes: {glfwKeyUp}),
  ];
  static const _nextOptionTrigger = [
    ActionTrigger(keyCodes: {glfwKeyDown}),
  ];
  static const _selectHighlightedOptionTrigger = [
    ActionTrigger(keyCodes: {glfwKeyEnter, glfwKeyKpEnter}),
  ];
}

typedef _ComboBoxButtonsState<T> = ({List<T> options, int? highlightedOptionIdx});

class _ComboBoxButtons<T> extends StatelessWidget {
  final ListenableValue<_ComboBoxButtonsState<T>> state;
  final double width;
  final ComboBoxStyle style;
  final String Function(T? option) optionToString;
  final void Function(T option) onSelect;

  _ComboBoxButtons({
    required this.state,
    required this.width,
    required this.style,
    required this.optionToString,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = style.optionButtonStyle!.copy(textStyle: style.textStyle!);
    final highlightedButtonStyle = buttonStyle.copy(color: DefaultButtonStyle.of(context).color);

    final cornerRadius = style.cornerRadius!.copy(topLeft: 0, topRight: 0);

    return Sized(
      width: width,
      child: Panel(
        color: style.borderHighlightColor!,
        cornerRadius: cornerRadius,
        child: Padding(
          insets: Insets.all(style.borderThickness!),
          child: Panel(
            color: style.backgroundColor!,
            cornerRadius: cornerRadius,
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                return Column(
                  children: [
                    for (final (idx, option) in state.value.options.indexed)
                      Button(
                        style: idx == state.value.highlightedOptionIdx ? highlightedButtonStyle : buttonStyle,
                        onClick: () => onSelect(option),
                        child: Text(optionToString(option), style: const TextStyle(alignment: Alignment.left)),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../../braid_ui.dart';

abstract interface class BuildContext {}

final class RootBuildContext implements BuildContext {
  const RootBuildContext();
}

@immutable
abstract class Widget {
  final Key? key;

  const Widget({
    this.key,
  });

  InstanceWidget assemble(BuildContext context);
}

// ---

abstract class InstanceWidget extends Widget {
  const InstanceWidget({
    super.key,
  });

  @factory
  WidgetInstance instantiate();

  @mustCallSuper
  void updateInstance(covariant WidgetInstance instance) => instance.widget = this;

  bool canUpdate(InstanceWidget oldWidget) {
    return (oldWidget.runtimeType == runtimeType) && oldWidget.key == key;
  }

  // ---

  @override
  InstanceWidget assemble(BuildContext context) => this;
}

class Flexible extends Widget {
  final Widget child;
  final double flexFactor;

  const Flexible({
    super.key,
    this.flexFactor = 1.0,
    required this.child,
  });

  @override
  InstanceWidget assemble(BuildContext context) {
    return _VisitorWidget(
      key: key,
      instanceWidget: child.assemble(context),
      visitor: (instance) {
        if (instance.parentData case FlexParentData data) {
          data.flexFactor = flexFactor;
        } else {
          instance.parentData = FlexParentData(flexFactor);
        }
      },
    );
  }
}

typedef _InstanceVisitor = void Function(WidgetInstance instance);

class _VisitorWidget extends InstanceWidget {
  final InstanceWidget _instanceWidget;
  final _InstanceVisitor _visitor;

  _VisitorWidget({
    required super.key,
    required InstanceWidget instanceWidget,
    required _InstanceVisitor visitor,
  })  : _instanceWidget = instanceWidget,
        _visitor = visitor;

  @override
  WidgetInstance instantiate() {
    final instance = _instanceWidget.instantiate();
    _visitor(instance);

    return instance;
  }

  @override
  // ignore: must_call_super
  void updateInstance(covariant WidgetInstance instance) {
    _instanceWidget.updateInstance(instance);
    _visitor(instance);
  }

  @override
  bool canUpdate(InstanceWidget oldWidget) {
    return (oldWidget.runtimeType == _instanceWidget.runtimeType) && oldWidget.key == key;
  }
}

abstract class SingleChildWidget extends InstanceWidget {
  const SingleChildWidget({
    super.key,
  });

  Widget get child;

  @mustCallSuper
  @override
  void updateInstance(covariant SingleChildWidgetInstance instance) {
    super.updateInstance(instance);

    final newWidget = child.assemble(instance);
    if (newWidget.canUpdate(instance.child.widget)) {
      newWidget.updateInstance(instance.child);
    } else {
      instance.child = newWidget.instantiate();
    }
  }
}

abstract class OptionalChildWidget extends InstanceWidget {
  const OptionalChildWidget({
    super.key,
  });

  Widget? get child;

  @mustCallSuper
  @override
  void updateInstance(covariant OptionalChildWidgetInstance instance) {
    super.updateInstance(instance);

    final newWidget = child?.assemble(instance);
    if (newWidget != null) {
      if (instance.child != null && newWidget.canUpdate(instance.child!.widget)) {
        newWidget.updateInstance(instance.child!);
      } else {
        instance.child = newWidget.instantiate();
      }
    } else {
      instance.child = null;
    }
  }
}

class Padding extends OptionalChildWidget {
  final Insets insets;
  @override
  final Widget? child;

  const Padding({
    super.key,
    required this.insets,
    this.child,
  });

  @override
  PaddingInstance instantiate() => PaddingInstance(
        widget: this,
        childWidget: child,
      );
}

class Constrained extends SingleChildWidget {
  final Constraints constraints;
  @override
  final Widget child;

  Constrained({
    super.key,
    required this.constraints,
    required this.child,
  });

  @override
  ConstrainedInstance instantiate() => ConstrainedInstance(
        widget: this,
        childWidget: child,
      );
}

class Center extends SingleChildWidget {
  final double? widthFactor, heightFactor;
  @override
  final Widget child;

  const Center({
    super.key,
    this.widthFactor,
    this.heightFactor,
    required this.child,
  });

  @override
  CenterInstance instantiate() => CenterInstance(
        widget: this,
        childWidget: child,
      );
}

class Panel extends OptionalChildWidget {
  final Color color;
  final double cornerRadius;
  @override
  final Widget? child;

  Panel({
    super.key,
    required this.color,
    this.cornerRadius = 10.0,
    this.child,
  });

  @override
  PanelInstance instantiate() => PanelInstance(
        widget: this,
        childWidget: child,
      );
}

class Label extends InstanceWidget {
  final Text text;
  final LabelStyle style;

  Label({
    super.key,
    required String text,
    this.style = LabelStyle.empty,
  }) : text = Text.string(text);

  Label.text({
    super.key,
    required this.text,
    this.style = LabelStyle.empty,
  });

  @override
  LabelInstance instantiate() => LabelInstance(widget: this);
}

class MouseArea extends SingleChildWidget {
  final void Function()? clickCallback;
  final void Function()? enterCallback;
  final void Function()? exitCallback;
  final void Function(double horizontal, double vertical)? scrollCallback;
  final CursorStyle? cursorStyle;

  @override
  final Widget child;

  const MouseArea({
    super.key,
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.scrollCallback,
    this.cursorStyle,
    required this.child,
  });

  @override
  MouseAreaInstance instantiate() => MouseAreaInstance(
        widget: this,
        childWidget: child,
      );
}

class KeyboardInput extends SingleChildWidget {
  final void Function(int keyCode, int modifiers)? keyDownCallback;
  final void Function(int keyCode, int modifiers)? keyUpCallback;
  final void Function(int charCode, int modifiers)? charCallback;
  final void Function()? focusGainedCallback;
  final void Function()? focusLostCallback;

  @override
  final Widget child;

  const KeyboardInput({
    super.key,
    this.keyDownCallback,
    this.keyUpCallback,
    this.charCallback,
    this.focusGainedCallback,
    this.focusLostCallback,
    required this.child,
  });

  @override
  KeyboardInputInstance instantiate() => KeyboardInputInstance(
        widget: this,
        childWidget: child,
      );
}

class HitTestOccluder extends Widget {
  final Widget child;

  const HitTestOccluder({
    super.key,
    required this.child,
  });

  @override
  InstanceWidget assemble(BuildContext context) {
    return _VisitorWidget(
      key: key,
      instanceWidget: child.assemble(context),
      visitor: (instance) => instance.flags |= InstanceFlags.hitTestBoundary,
    );
  }
}

// ---

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build(BuildContext context);

  // ---

  @override
  InstanceWidget assemble(BuildContext context) => build(context).assemble(context);
}

// ---

abstract class StatefulWidget extends InstanceWidget {
  const StatefulWidget({super.key});

  WidgetState createState();

  // ---

  @override
  StatefulWidgetInstance instantiate() => StatefulWidgetInstance(widget: this);
}

abstract class WidgetState<T extends StatefulWidget> {
  Widget build(BuildContext context);

  T? _widget;
  T get widget => _widget!;

  void init() {}
  void dispose() {}

  StatefulWidgetInstance? _owner;

  void setState(void Function() fn) {
    assert(_owner != null, "setState invoked on WidgetState before it was mounted");

    fn();
    rebuild();
  }

  void didUpdateWidget(covariant T oldWidget) {}

  @internal
  void rebuild() {
    final newWidget = build(_owner!).assemble(_owner!);
    if (newWidget.canUpdate(_owner!.child.widget)) {
      newWidget.updateInstance(_owner!.child);
    } else {
      _owner!.child = newWidget.instantiate();
    }
  }
}

class StatefulWidgetInstance<T extends StatefulWidget> extends SingleChildWidgetInstance<T> with ShrinkWrapLayout {
  late WidgetState _state;

  StatefulWidgetInstance({
    required super.widget,
  }) {
    _state = widget.createState()
      .._widget = widget
      .._owner = this
      ..init();

    child = _state.build(this).assemble(this).instantiate();
  }

  @override
  set widget(T value) {
    final oldWidget = widget;
    super.widget = value;

    _state._widget = value;
    _state.didUpdateWidget(oldWidget);

    _state.rebuild();
  }

  @override
  void dispose() {
    super.dispose();
    _state.dispose();
  }
}

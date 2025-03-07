import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../core/cursors.dart';
import '../core/math.dart';
import '../core/widget.dart';
import '../core/widget_base.dart';
import '../text/text.dart';
import '../widgets/label.dart';

@immutable
abstract class Widget {
  final Key? key;

  @literal
  const Widget({
    this.key,
  });

  DirectWidget assemble();

  // ---

  static bool canUpdate(DirectWidget oldWidget, DirectWidget newWidget) {
    return (oldWidget.runtimeType == newWidget.runtimeType) && oldWidget.key == newWidget.key;
  }
}

// ---

abstract class DirectWidget extends Widget {
  const DirectWidget({
    super.key,
  });

  @factory
  WidgetInstance instantiate();

  @mustCallSuper
  void updateInstance(covariant WidgetInstance instance) => instance.widget = this;

  // ---

  @override
  DirectWidget assemble() => this;
}

abstract class SingleChildWidget extends DirectWidget {
  const SingleChildWidget({
    super.key,
  });

  Widget get child;

  @mustCallSuper
  @override
  void updateInstance(covariant SingleChildWidgetInstance instance) {
    super.updateInstance(instance);

    final newWidget = child.assemble();
    if (Widget.canUpdate(instance.child.widget, newWidget)) {
      newWidget.updateInstance(instance.child);
    } else {
      instance.child = newWidget.instantiate();
    }
  }
}

abstract class OptionalChildWidget extends DirectWidget {
  const OptionalChildWidget({
    super.key,
  });

  Widget? get child;

  @mustCallSuper
  @override
  void updateInstance(covariant OptionalChildWidgetInstance instance) {
    super.updateInstance(instance);

    final newWidget = child?.assemble();
    if (newWidget != null) {
      if (instance.child != null && Widget.canUpdate(instance.child!.widget, newWidget)) {
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

  @literal
  const Padding({
    required this.insets,
    this.child,
    super.key,
  });

  @override
  WidgetInstance instantiate() => PaddingInstance(
        widget: this,
        child: child?.assemble().instantiate(),
      );
}

class Center extends SingleChildWidget {
  final double? widthFactor, heightFactor;
  @override
  final Widget child;

  @literal
  const Center({
    this.widthFactor,
    this.heightFactor,
    required this.child,
    super.key,
  });

  @override
  WidgetInstance instantiate() => CenterInstance(
        widget: this,
        child: child.assemble().instantiate(),
      );
}

class Panel extends OptionalChildWidget {
  final Color color;
  final double cornerRadius;
  @override
  final Widget? child;

  Panel({
    required this.color,
    this.cornerRadius = 10.0,
    this.child,
    super.key,
  });

  @override
  WidgetInstance instantiate() => PanelInstance(
        widget: this,
        child: child?.assemble().instantiate(),
      );
}

class Label extends DirectWidget {
  final Text text;
  final LabelStyle style;

  Label({
    required String text,
    this.style = LabelStyle.empty,
  }) : text = Text.string(text);

  Label.text({
    required this.text,
    this.style = LabelStyle.empty,
    super.key,
  });

  @override
  WidgetInstance instantiate() => LabelInstance(widget: this);
}

class MouseArea extends SingleChildWidget {
  final void Function()? clickCallback;
  final void Function()? enterCallback;
  final void Function()? exitCallback;
  final void Function(double horizontal, double vertical)? scrollCallback;
  final CursorStyle? cursorStyle;

  @override
  final Widget child;

  MouseArea({
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.scrollCallback,
    this.cursorStyle,
    required this.child,
  });

  @override
  WidgetInstance instantiate() => MouseAreaInstance(
        widget: this,
        child: child.assemble().instantiate(),
      );
}

// ---

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});

  Widget build();

  // ---

  @override
  DirectWidget assemble() => build().assemble();
}

// ---

abstract class StatefulWidget extends DirectWidget {
  const StatefulWidget({super.key});

  WidgetState createState();

  // ---

  @override
  WidgetInstance instantiate() => StatefulWidgetInstance(widget: this);

  @override
  void updateInstance(StatefulWidgetInstance instance) {
    super.updateInstance(instance);
    return instance._state!.rebuild();
  }
}

abstract class WidgetState {
  Widget build();

  void init() {}
  void dispose() {}

  StatefulWidgetInstance? _owner;

  void setState(void Function() fn) {
    assert(_owner != null, "setState invoked on WidgetState before it was mounted");

    fn();
    rebuild();
  }

  @internal
  void rebuild() {
    final newWidget = build().assemble();
    if (Widget.canUpdate(_owner!.child.widget, newWidget)) {
      newWidget.updateInstance(_owner!.child);
    } else {
      _owner!.child = newWidget.instantiate();
    }
  }
}

class StatefulWidgetInstance extends SingleChildWidgetInstance with ShrinkWrapLayout {
  @override
  final StatefulWidget widget;

  WidgetState? _state;

  StatefulWidgetInstance({
    required this.widget,
  }) : super.lateChild() {
    _state = widget.createState()
      .._owner = this
      ..init();

    initChild(_state!.build().assemble().instantiate());
  }

  @override
  void dispose() {
    super.dispose();
    _state!.dispose();
  }
}

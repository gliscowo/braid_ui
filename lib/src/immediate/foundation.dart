import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';

import '../../braid_ui.dart';

@immutable
abstract class Widget {
  final Key? key;

  @literal
  const Widget({
    this.key,
  });

  InstanceWidget assemble();
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
  InstanceWidget assemble() => this;
}

class Flexible extends Widget {
  final Widget child;
  final double flexFactor;

  const Flexible({
    super.key,
    required this.child,
    this.flexFactor = 1.0,
  });

  @override
  InstanceWidget assemble() {
    return _VisitorWidget(
      key: key,
      instanceWidget: child.assemble(),
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

    final newWidget = child.assemble();
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

    final newWidget = child?.assemble();
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
  WidgetInstance instantiate() => ConstrainedInstance(
        widget: this,
        child: child.assemble().instantiate(),
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

class Label extends InstanceWidget {
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
  InstanceWidget assemble() => build().assemble();
}

// ---

abstract class StatefulWidget extends InstanceWidget {
  const StatefulWidget({super.key});

  WidgetState createState();

  // ---

  @override
  WidgetInstance instantiate() => StatefulWidgetInstance(widget: this);
}

abstract class WidgetState<T extends StatefulWidget> {
  Widget build();

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
    final newWidget = build().assemble();
    if (newWidget.canUpdate(_owner!.child.widget)) {
      newWidget.updateInstance(_owner!.child);
    } else {
      _owner!.child = newWidget.instantiate();
    }
  }
}

class StatefulWidgetInstance<T extends StatefulWidget> extends SingleChildWidgetInstance with ShrinkWrapLayout {
  T _widget;

  late WidgetState _state;

  StatefulWidgetInstance({
    required T widget,
  })  : _widget = widget,
        super.lateChild() {
    _state = widget.createState()
      .._widget = widget
      .._owner = this
      ..init();

    initChild(_state.build().assemble().instantiate());
  }

  @override
  T get widget => _widget;
  @override
  set widget(T value) {
    final oldWidget = _widget;
    _widget = value;

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

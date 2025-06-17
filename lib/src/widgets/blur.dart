import '../../braid_ui.dart';

class Blur extends SingleChildInstanceWidget {
  final double radius;

  const Blur({super.key, this.radius = 10, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _BlurInstance(widget: this);
}

class _BlurInstance extends SingleChildWidgetInstance<Blur> with ShrinkWrapLayout {
  _BlurInstance({required super.widget});

  @override
  void draw(DrawContext ctx) {
    if (widget.radius >= 1.5) {
      ctx.primitives.blur(transform.width, transform.height, widget.radius, ctx.transform, ctx.projection);
    }

    super.draw(ctx);
  }
}

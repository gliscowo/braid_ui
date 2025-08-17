import '../../braid_ui.dart';

class Blur extends SingleChildInstanceWidget {
  final double radius;
  final bool blurChild;

  const Blur({super.key, this.radius = 10, this.blurChild = false, required super.child});

  @override
  SingleChildWidgetInstance<InstanceWidget> instantiate() => _BlurInstance(widget: this);
}

class _BlurInstance extends SingleChildWidgetInstance<Blur> with ShrinkWrapLayout {
  _BlurInstance({required super.widget});

  @override
  void draw(DrawContext ctx) {
    if (!widget.blurChild) {
      _applyBlur(ctx);
    }

    super.draw(ctx);

    if (widget.blurChild) {
      _applyBlur(ctx);
    }
  }

  void _applyBlur(DrawContext ctx) {
    if (widget.radius >= 1.5) {
      ctx.primitives.blur(transform.width, transform.height, widget.radius, ctx.transform, ctx.projection);
    }
  }
}

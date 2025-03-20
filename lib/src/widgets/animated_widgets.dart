import 'package:diamond_gl/diamond_gl.dart';

import '../animation/automatic_animation.dart';
import '../animation/lerp.dart';
import '../core/math.dart';
import '../framework/widget.dart';
import 'basic.dart';

class AnimatedPadding extends AutomaticallyAnimatedWidget {
  final Insets insets;
  final Widget? child;

  const AnimatedPadding({super.key, super.easing, required super.duration, required this.insets, this.child});

  @override
  AutomaticallyAnimatedWidgetState<AnimatedPadding> createState() => _AnimatedPaddingState();
}

class _AnimatedPaddingState extends AutomaticallyAnimatedWidgetState<AnimatedPadding> {
  InsetsLerp? _insets;

  @override
  void updateLerps() {
    _insets = visitLerp(_insets, widget.insets, InsetsLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(insets: _insets!.compute(animationValue), child: widget.child);
  }
}

// ---

class AnimatedPanel extends AutomaticallyAnimatedWidget {
  final Color color;
  final double cornerRadius;
  final double? outlineThickness;
  final Widget? child;

  const AnimatedPanel({
    super.key,
    super.easing,
    required super.duration,
    required this.color,
    this.cornerRadius = 0,
    this.outlineThickness,
    this.child,
  });

  @override
  AutomaticallyAnimatedWidgetState<AutomaticallyAnimatedWidget> createState() => _AnimatedPanelState();
}

class _AnimatedPanelState extends AutomaticallyAnimatedWidgetState<AnimatedPanel> {
  ColorLerp? _color;
  DoubleLerp? _cornerRadius;

  @override
  void updateLerps() {
    _color = visitLerp(_color, widget.color, ColorLerp.new);
    _cornerRadius = visitLerp(_cornerRadius, widget.cornerRadius, DoubleLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: _color!.compute(animationValue),
      cornerRadius: _cornerRadius!.compute(animationValue),
      outlineThickness: widget.outlineThickness,
      child: widget.child,
    );
  }
}

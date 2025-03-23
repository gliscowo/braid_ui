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
  final CornerRadius cornerRadius;
  final double? outlineThickness;
  final Widget? child;

  const AnimatedPanel({
    super.key,
    super.easing,
    required super.duration,
    required this.color,
    this.cornerRadius = CornerRadius.zero,
    this.outlineThickness,
    this.child,
  });

  @override
  AutomaticallyAnimatedWidgetState<AutomaticallyAnimatedWidget> createState() => _AnimatedPanelState();
}

class _AnimatedPanelState extends AutomaticallyAnimatedWidgetState<AnimatedPanel> {
  ColorLerp? _color;
  CornerRadiusLerp? _cornerRadius;

  @override
  void updateLerps() {
    _color = visitLerp(_color, widget.color, ColorLerp.new);
    _cornerRadius = visitLerp(_cornerRadius, widget.cornerRadius, CornerRadiusLerp.new);
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

// ---

class AnimatedSized extends AutomaticallyAnimatedWidget {
  final double? width;
  final double? height;
  final Widget child;

  AnimatedSized({super.key, super.easing, required super.duration, this.width, this.height, required this.child});

  @override
  AutomaticallyAnimatedWidgetState<AnimatedSized> createState() => _AnimatedSizedState();
}

class _AnimatedSizedState extends AutomaticallyAnimatedWidgetState<AnimatedSized> {
  Lerp<double?>? _width;
  Lerp<double?>? _height;

  @override
  void updateLerps() {
    _width = visitNullableLerp(_width, widget.width, DoubleLerp.new);
    _height = visitNullableLerp(_height, widget.height, DoubleLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Sized(width: _width!.compute(animationValue), height: _height!.compute(animationValue), child: widget.child);
  }
}

// ---

class AnimatedAlign extends AutomaticallyAnimatedWidget {
  final Alignment alignment;
  final double? widthFactor;
  final double? heightFactor;
  final Widget child;

  AnimatedAlign({
    super.key,
    super.easing,
    required super.duration,
    this.widthFactor,
    this.heightFactor,
    required this.alignment,
    required this.child,
  });

  @override
  AutomaticallyAnimatedWidgetState<AnimatedAlign> createState() => _AnimatedAlignState();
}

class _AnimatedAlignState extends AutomaticallyAnimatedWidgetState<AnimatedAlign> {
  Lerp<double?>? _widthFactor;
  Lerp<double?>? _heightFactor;
  AlignmentLerp? _alignment;

  @override
  void updateLerps() {
    _widthFactor = visitNullableLerp(_widthFactor, widget.widthFactor, DoubleLerp.new);
    _heightFactor = visitNullableLerp(_heightFactor, widget.heightFactor, DoubleLerp.new);
    _alignment = visitLerp(_alignment, widget.alignment, AlignmentLerp.new);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: _widthFactor!.compute(animationValue),
      heightFactor: _heightFactor!.compute(animationValue),
      alignment: _alignment!.compute(animationValue),
      child: widget.child,
    );
  }
}

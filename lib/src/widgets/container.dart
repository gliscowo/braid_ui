import 'package:diamond_gl/diamond_gl.dart';

import '../animation/easings.dart';
import '../core/math.dart';
import '../framework/widget.dart';
import 'animated_widgets.dart';
import 'basic.dart';

class Container extends StatelessWidget {
  final Insets? padding;
  final Insets? margin;
  final Color? color;
  final CornerRadius? cornerRadius;
  final Widget child;

  Container({super.key, this.padding, this.margin, this.color, this.cornerRadius, required this.child});

  @override
  Widget build(BuildContext context) {
    var result = child;

    if (padding != null) {
      result = Padding(insets: padding!, child: result);
    }

    if (color != null) {
      result = Panel(color: color!, cornerRadius: cornerRadius ?? const CornerRadius(), child: result);
    }

    if (margin != null) {
      result = Padding(insets: margin!, child: result);
    }

    return result;
  }
}

class AnimatedContainer extends StatelessWidget {
  final Insets? padding;
  final Insets? margin;
  final Color? color;
  final CornerRadius? cornerRadius;
  final Duration duration;
  final Easing easing;
  final Widget child;

  AnimatedContainer({
    super.key,
    this.padding,
    this.margin,
    this.color,
    this.cornerRadius,
    this.easing = Easing.linear,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    var result = child;

    if (padding != null) {
      result = AnimatedPadding(easing: easing, duration: duration, insets: padding!, child: result);
    }

    if (color != null) {
      result = AnimatedPanel(
        easing: easing,
        duration: duration,
        color: color!,
        cornerRadius: cornerRadius ?? const CornerRadius(),
        child: result,
      );
    }

    if (margin != null) {
      result = AnimatedPadding(easing: easing, duration: duration, insets: margin!, child: result);
    }

    return result;
  }
}

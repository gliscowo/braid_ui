import 'dart:math';

import 'package:braid_ui/braid_ui.dart';
import 'package:braid_ui/src/core/cursors.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../text/text.dart';
import 'constraints.dart';
import 'math.dart';
import 'widget_base.dart';

class Padding extends SingleChildWidget {
  final Insets insets;

  Padding({
    required super.child,
    required this.insets,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final childConstraints = Constraints(
      max(0, constraints.minWidth - insets.horizontal),
      max(0, constraints.minHeight - insets.vertical),
      max(0, constraints.maxWidth - insets.horizontal),
      max(0, constraints.maxHeight - insets.vertical),
    );

    final size = child.layout(ctx, childConstraints).withInsets(insets);
    transform.setSize(size);

    child.transform.x = insets.left;
    child.transform.y = insets.top;
  }
}

abstract class SingleChildWidget extends Widget with SingleChildProvider, ChildRenderer, SingleChildRenderer {
  late Widget? _child;

  @override
  Widget get child => _child!;
  set child(Widget widget) => _child = widget..parent = this;

  SingleChildWidget({
    required Widget child,
  }) : _child = child {
    child.parent = this;
  }

  SingleChildWidget.lateChild();

  @nonVirtual
  @protected
  void initChild(Widget widget) {
    _child = widget..parent = this;
  }
}

class Center extends SingleChildWidget {
  final double? widthFactor, heightFactor;

  Center({
    this.widthFactor,
    this.heightFactor,
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final childSize = child.layout(ctx, constraints.asLoose());
    final selfSize = Size(
            widthFactor != null || !constraints.hasBoundedWidth
                ? childSize.width * (widthFactor ?? 1)
                : constraints.maxWidth,
            heightFactor != null || !constraints.hasBoundedHeight
                ? childSize.height * (heightFactor ?? 1)
                : constraints.maxHeight)
        .constrained(constraints);

    child.transform.x = (selfSize.width - childSize.width) / 2;
    child.transform.y = (selfSize.height - childSize.height) / 2;

    transform.setSize(selfSize);
  }
}

class Panel extends SingleChildWidget with ShrinkWrapLayout {
  Color color;

  Panel({
    required this.color,
    required super.child,
  });

  @override
  void draw(DrawContext ctx) {
    ctx.primitives.roundedRect(transform.width, transform.height, 10, color, ctx.transform, ctx.projection);
    super.draw(ctx);
  }
}

class Column extends Widget with ChildRenderer, ChildListRenderer {
  @override
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  Column({
    this.crossAxisAlignment = CrossAxisAlignment.start,
    required this.children,
  }) {
    for (final child in children) {
      child.parent = this;
    }
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final childConstraints = Constraints(
      crossAxisAlignment == CrossAxisAlignment.stretch ? constraints.maxWidth : constraints.minWidth,
      0,
      constraints.maxWidth,
      double.infinity,
    );

    final childSizes = children.map((e) => e.layout(ctx, childConstraints)).toList();

    final size = childSizes
        .fold(
          Size.zero,
          (previousValue, element) => Size(
            max(previousValue.width, element.width),
            previousValue.height + element.height,
          ),
        )
        .constrained(constraints);

    transform.width = size.width;
    transform.height = size.height;

    var yOffset = 0.0;
    for (final child in children) {
      child.transform.x = crossAxisAlignment._computeChildOffset(size.width - child.transform.width);
      child.transform.y = yOffset;

      yOffset += child.transform.height;
    }
  }
}

enum CrossAxisAlignment {
  start,
  end,
  center,
  stretch;

  double _computeChildOffset(double freeSpace) {
    return switch (this) {
      CrossAxisAlignment.stretch => 0,
      CrossAxisAlignment.start => 0,
      CrossAxisAlignment.center => freeSpace / 2,
      CrossAxisAlignment.end => freeSpace,
    };
  }
}

class Label extends Widget {
  Text _text;
  final double fontSize;

  Label({
    required Text text,
    this.fontSize = 24,
  }) : _text = text;

  Label.string({
    required String text,
    this.fontSize = 24,
  }) : _text = Text.string(text);

  @override
  void draw(DrawContext ctx) {
    final textSize = ctx.textRenderer.sizeOf(text, fontSize);
    final xOffset = (transform.width - textSize.width) / 2, yOffset = (transform.height - textSize.height) / 2;

    ctx.transform.scope((mat4) {
      mat4.translate(xOffset, yOffset);
      ctx.textRenderer.drawText(text, fontSize, mat4, ctx.projection);
    });
  }

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = ctx.textRenderer.sizeOf(text, fontSize).constrained(constraints);
    transform.setSize(size);
  }

  Text get text => _text;
  set text(Text value) {
    _text = value;
    markNeedsLayout();
  }
}

class MouseArea extends SingleChildWidget with ShrinkWrapLayout, MouseListener {
  void Function()? clickCallback;
  void Function()? enterCallback;
  void Function()? exitCallback;
  CursorStyle? cursorStyle;

  MouseArea({
    this.clickCallback,
    this.enterCallback,
    this.exitCallback,
    this.cursorStyle,
    required super.child,
  });

  @override
  void onMouseDown() => clickCallback?.call();

  @override
  void onMouseEnter() => enterCallback?.call();

  @override
  void onMouseExit() => exitCallback?.call();
}

class Button extends SingleChildWidget with ShrinkWrapLayout {
  late Label _label;
  late Panel _panel;

  void Function(Button button) onClick;
  Color _color;
  Color _hoveredColor;

  Button({
    required Text text,
    required this.onClick,
    required Color color,
    required Color hoveredColor,
    Insets padding = const Insets.all(10),
  })  : _hoveredColor = hoveredColor,
        _color = color,
        super.lateChild() {
    initChild(MouseArea(
      child: _panel = Panel(
        color: color,
        child: Padding(
          insets: padding,
          child: _label = Label(text: text, fontSize: 20),
        ),
      ),
      clickCallback: () => onClick(this),
      enterCallback: () => _panel.color = _hoveredColor,
      exitCallback: () => _panel.color = _color,
      cursorStyle: CursorStyle.hand,
    ));
  }

  set color(Color value) => _panel.color = _color = value;
  set hoveredColor(Color value) => _panel.color = _hoveredColor = value;

  Text get text => _label.text;
  set text(Text value) => _label.text = value;
}

class HappyWidget extends Widget {
  final Size size;
  final double cornerRadius;
  HappyWidget(this.size, {this.cornerRadius = 10});

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final constrained = size.constrained(constraints);
    transform.setSize(constrained);
  }

  @override
  void draw(DrawContext ctx) {
    final (hitTestX, hitTestY) = transformCoords(
      ctx.renderContext.window.cursorX,
      ctx.renderContext.window.cursorY,
      Matrix4.inverted(ctx.transform),
    );

    final hovered = hitTestSelf(hitTestX, hitTestY);
    ctx.primitives.roundedRect(
      transform.width,
      transform.height,
      cornerRadius,
      hovered ? Color.red : Color.ofRgb(0x5865f2),
      ctx.transform,
      ctx.projection,
    );

    ctx.transform.translate(5.0, 5.0);
    ctx.textRenderer.drawText(Text.string('widget :)'), 16, ctx.transform, ctx.projection);
  }
}

class ConstrainedBox extends SingleChildWidget {
  final Constraints constraints;

  ConstrainedBox({
    required this.constraints,
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    final size = child.layout(ctx, this.constraints.respecting(constraints));
    transform.width = size.width;
    transform.height = size.height;
  }
}

class Transform extends SingleChildWidget with ShrinkWrapLayout {
  Transform({
    required Matrix4 matrix,
    required super.child,
  }) {
    (transform as CustomWidgetTransform).matrix = matrix;
  }

  Matrix4 get matrix => (transform as CustomWidgetTransform).matrix;
  set matrix(Matrix4 value) {
    (transform as CustomWidgetTransform).matrix = value;
    markNeedsLayout();
  }

  @override
  CustomWidgetTransform createTransform() => CustomWidgetTransform();
}

class LayoutAfterTransform extends SingleChildWidget {
  LayoutAfterTransform({
    required super.child,
  });

  @override
  void doLayout(LayoutContext ctx, Constraints constraints) {
    child.transform.x = 0;
    child.transform.y = 0;

    child.layout(ctx, constraints);

    final size = Size(
      child.transform.aabb.width,
      child.transform.aabb.height,
    ).constrained(constraints);

    child.transform.x = -child.transform.aabb.min.x;
    child.transform.y = -child.transform.aabb.min.y;

    transform.width = size.width;
    transform.height = size.height;
  }
}

class Clip extends SingleChildWidget with ShrinkWrapLayout {
  Clip({
    required super.child,
  });

  @override
  void draw(DrawContext ctx) {
    final scissorBox = Aabb3.copy(transform.aabb)..transform(ctx.transform);
    gl.scissor(
      scissorBox.min.x.toInt(),
      ctx.renderContext.window.height - scissorBox.min.y.toInt() - scissorBox.height.toInt(),
      scissorBox.width.toInt(),
      scissorBox.height.toInt(),
    );

    gl.enable(glScissorTest);
    super.draw(ctx);
    gl.disable(glScissorTest);
  }
}

class StencilClip extends SingleChildWidget with ShrinkWrapLayout {
  static final _framebufferByWindow = <Window, GlFramebuffer>{};
  static var stencilValue = 0;

  StencilClip({
    required super.child,
  });

  @override
  void draw(DrawContext ctx) {
    stencilValue++;

    final window = ctx.renderContext.window;
    final framebuffer = _framebufferByWindow[window] ??= (() {
      final buffer = GlFramebuffer.trackingWindow(window, stencil: true);
      frameEvents.listen((_) => buffer.clear(color: Color.ofArgb(0), depth: 0, stencil: 0));
      return buffer;
    })();

    framebuffer.bind();
    gl.enable(glStencilTest);

    gl.stencilFunc(glEqual, stencilValue - 1, 0xFF);
    gl.stencilOp(glKeep, glIncr, glIncr);
    ctx.primitives.rect(transform.width, transform.height, Color.ofArgb(0), ctx.transform, ctx.projection);

    gl.stencilFunc(glEqual, stencilValue, 0xFF);
    gl.stencilOp(glKeep, glKeep, glKeep);

    super.draw(ctx);

    gl.disable(glStencilTest);
    framebuffer.unbind();

    stencilValue--;
    if (stencilValue == 0) {
      ctx.primitives.blitFramebuffer(framebuffer);
    }
  }
}

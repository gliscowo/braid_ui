// class InfiniteVerticalSpace extends SingleChildWidgetInstance<InstanceWidget> {
//   double _verticalOverflow = 0.0;

//   InfiniteVerticalSpace({
//     required super.child,
//   });

//   @override
//   void doLayout(Constraints constraints) {
//     final size = child.layout(
//       ctx,
//       Constraints(
//         constraints.minWidth,
//         constraints.minHeight,
//         constraints.maxWidth,
//         double.infinity,
//       ),
//     );

//     transform.setSize(size.constrained(constraints));
//     _verticalOverflow = size.height - transform.height;
//   }

//   double get verticalOverflow => _verticalOverflow;
// }

// TODO: correct child setter
// class VerticalScroll extends SingleChildWidgetInstance with ShrinkWrapLayout {
//   late final Transform _transform;
//   late final InfiniteVerticalSpace _container;
//   final Matrix4 _matrix = Matrix4.identity();

//   double scrollSpeed;
//   double scrollSmoothness;

//   double _offset = 0;
//   double _displayOffset = 0;

//   VerticalScroll({
//     required WidgetInstance child,
//     this.scrollSpeed = 1,
//     this.scrollSmoothness = 1,
//   }) : super.lateChild() {
//     initChild(MouseAreaInstance(
//       scrollCallback: (horizontal, vertical) => offset += vertical * -50.0 * scrollSpeed,
//       child: Clip(
//         child: _transform = Transform(
//           matrix: _matrix,
//           child: _container = InfiniteVerticalSpace(
//             child: child,
//           ),
//         ),
//       ),
//     ));
//   }

//   @override
//   void update(double delta) {
//     super.update(delta);

//     if (scrollSmoothness != 0) {
//       final smoothness = scrollSmoothness < 1 ? sqrt(scrollSmoothness) : scrollSmoothness;
//       _displayOffset += computeDelta(_displayOffset, offset, delta * (15 / smoothness));
//     } else {
//       _displayOffset = offset;
//     }

//     _matrix.setTranslationRaw(0.0, -_displayOffset, 0.0);
//     _transform.transform.recompute();
//   }

//   @override
//   void doLayout(Constraints constraints) {
//     super.doLayout(ctx, constraints);
//     offset = offset;
//   }

//   double get offset => _offset;
//   set offset(double value) {
//     _offset = value.clamp(0, _container._verticalOverflow);
//   }
// }

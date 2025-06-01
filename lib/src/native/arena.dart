import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

extension ArenaWithAllocator on Allocator {
  /// Run [computation] with an arena backed by this allocator.
  /// All allocations made on will be freed immediately after
  /// [computation] returns
  R arena<R>(R Function(ffi.Arena arena) computation) => ffi.using(computation, this);
}

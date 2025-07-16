final class BraidInitializationException implements Exception {
  final String message;
  final Object? cause;
  BraidInitializationException(this.message, {this.cause});

  @override
  String toString() => cause != null
      ? '''
error during braid initialization: $message
cause: $cause
'''
      : 'error during braid initialization: $message';
}

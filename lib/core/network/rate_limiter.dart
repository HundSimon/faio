import 'dart:async';

/// Simple async rate limiter that enforces a minimum delay between operations.
class RateLimiter {
  RateLimiter(this.minDelay);

  final Duration minDelay;
  DateTime? _lastInvocation;
  Future<void>? _pending;

  Future<void> acquire() {
    final completer = Completer<void>();

    _pending = (_pending ?? Future<void>.value()).then((_) async {
      final now = DateTime.now();
      if (_lastInvocation != null) {
        final elapsed = now.difference(_lastInvocation!);
        if (elapsed < minDelay) {
          await Future<void>.delayed(minDelay - elapsed);
        }
      }
      _lastInvocation = DateTime.now();
      completer.complete();
    }).catchError(completer.completeError);

    return completer.future;
  }
}

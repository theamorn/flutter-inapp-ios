/// Turns the host page's scroll velocity into the badge tile's pseudo-force.
///
/// The host reports `velocity`: how fast the page's content offset changes,
/// positive while scrolling toward the end of the page. The tile then moves
/// up the screen, so when that velocity grows the tile accelerates upward and
/// the badge inside it lags, as if pushed down (+y in tile coordinates). The
/// push is therefore `+d(velocity)/dt`.
///
/// Pure Dart, like the rest of the promo physics, so it is unit-testable.
library;

class ScrollPush {
  ScrollPush({
    this.maxAcceleration = 6000,
    this.holdSeconds = 0.08,
    this.gapSeconds = 0.1,
    this.smoothing = 0.5,
    this.minSampleSeconds = 0.004,
  });

  /// Clamp for a violent flick, in logical px/s².
  final double maxAcceleration;

  /// How long the last push lasts without a new sample. Hosts only report
  /// while the page moves, so silence means the scroll has stopped.
  final double holdSeconds;

  /// A sample this long after the previous one starts a new scroll instead
  /// of being differenced against a stale velocity.
  final double gapSeconds;

  /// Weight of each new sample in the running average; hosts sample at the
  /// display rate, and raw differences between frames are jittery.
  final double smoothing;

  /// Samples closer together than this are skipped: a host that reports
  /// twice in one frame would otherwise divide by almost nothing.
  final double minSampleSeconds;

  double? _lastVelocity;
  double _lastSeconds = 0;
  double _acceleration = 0;

  void addSample(double velocity, double atSeconds) {
    final previous = _lastVelocity;
    final elapsed = atSeconds - _lastSeconds;
    if (previous != null && elapsed < minSampleSeconds) return;
    _lastVelocity = velocity;
    _lastSeconds = atSeconds;

    if (previous == null || elapsed > gapSeconds) {
      _acceleration = 0;
      return;
    }
    final raw = ((velocity - previous) / elapsed).clamp(
      -maxAcceleration,
      maxAcceleration,
    );
    _acceleration += (raw - _acceleration) * smoothing;
  }

  double accelerationAt(double nowSeconds) {
    if (_lastVelocity == null || nowSeconds - _lastSeconds > holdSeconds) {
      return 0;
    }
    return _acceleration;
  }
}

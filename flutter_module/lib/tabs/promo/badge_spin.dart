/// The badge's spin around its strap: a twisted lanyard winds up when the
/// badge is flicked sideways, then unwinds it back to where it rests.
///
/// One angle, simulated apart from [LanyardWorld]'s in-plane physics because
/// the tile is 2D; the spin is what the renderer turns into 3D. Pure Dart so
/// the feel is pinned down by unit tests.
library;

import 'dart:math' as math;

class BadgeSpin {
  BadgeSpin({
    this.twistStiffness = 4,
    this.damping = 1.6,
    this.maxSpeed = 40,
    this.flipSpeed = 9,
  });

  /// Pull of the twisted strap back toward the rest angle, per radian.
  final double twistStiffness;
  final double damping;

  /// Cap in radians per second, so a wild throw stays readable.
  final double maxSpeed;

  /// Kick given by [flip], so turning over reads as a deliberate spin.
  final double flipSpeed;

  static const _substep = 1 / 240;
  static const _maxFrame = 1 / 30;

  double _yaw = 0;
  double _speed = 0;
  double _restYaw = 0;

  /// Radians around the strap; 0 shows the front.
  double get yaw => _yaw;
  double get speed => _speed;

  /// Whether the badge settles showing its back.
  bool get showsBack => _restYaw != 0;

  /// Whether the back is toward the viewer right now.
  bool get isBackFacing => math.cos(_yaw) < 0;

  /// Adds spin, e.g. from a sideways release velocity.
  void flick(double radiansPerSecond) {
    _speed = (_speed + radiansPerSecond).clamp(-maxSpeed, maxSpeed);
  }

  /// Turns the badge over, and keeps it that way until flipped again.
  void flip() {
    _restYaw = showsBack ? 0 : math.pi;
    flick(showsBack ? flipSpeed : -flipSpeed);
  }

  void step(double dt) {
    var remaining = dt.clamp(0.0, _maxFrame);
    while (remaining > 0) {
      final h = math.min(_substep, remaining);
      final acceleration =
          -twistStiffness * (_yaw - _restYaw) - damping * _speed;
      _speed += acceleration * h;
      _yaw += _speed * h;
      remaining -= h;
    }
  }
}

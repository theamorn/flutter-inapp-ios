/// Where the player's footprints go: one per stride, alternating feet a hand's
/// width either side of the path, at most [FootprintTrail.capacity] at once
/// (each is a flutter_scene 0.24 DecalNode, so the pool bounds the draws).
library;

import 'dart:math' as math;

class Footprint {
  Footprint(this.x, this.z, this.heading, {required this.left, required this.lifetime});

  final double x, z, heading;
  final bool left;
  final double lifetime;
  double age = 0;

  /// 1 when fresh, easing to 0 at the end of its life.
  double get fade => (1 - age / lifetime).clamp(0.0, 1.0);
}

class FootprintTrail {
  FootprintTrail({this.capacity = 12, this.stride = 0.55, this.lifetime = 8.0});

  final int capacity;
  final double stride;
  final double lifetime;

  /// Half the gap between the two feet, in metres.
  static const double footOffset = 0.09;

  /// How far the player must step from where tracking began before the first
  /// print lands, so stepping off leaves a mark but standing still does not.
  static const double firstStep = 0.03;

  final List<Footprint> _prints = <Footprint>[];
  double? _lastX, _lastZ;
  bool _left = true;
  bool _laidAny = false;

  /// Oldest first.
  List<Footprint> get prints => List.unmodifiable(_prints);

  void update(double dt, double x, double z, double headingRadians) {
    for (final p in _prints) {
      p.age += dt;
    }
    _prints.removeWhere((p) => p.age >= p.lifetime);

    final lx = _lastX, lz = _lastZ;
    if (lx == null || lz == null) {
      _lastX = x;
      _lastZ = z;
      return;
    }
    final dx = x - lx, dz = z - lz;
    final need = _laidAny ? stride : firstStep;
    if (dx * dx + dz * dz < need * need) return;
    _laidAny = true;

    // Heading 0 faces +Z; the foot sits to its side.
    final side = _left ? -1.0 : 1.0;
    final px = x + math.cos(headingRadians) * footOffset * side;
    final pz = z - math.sin(headingRadians) * footOffset * side;
    _prints.add(Footprint(px, pz, headingRadians, left: _left, lifetime: lifetime));
    if (_prints.length > capacity) _prints.removeAt(0);
    _left = !_left;
    _lastX = x;
    _lastZ = z;
  }
}

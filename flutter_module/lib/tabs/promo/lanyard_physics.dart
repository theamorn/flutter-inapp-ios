/// Verlet physics for the promo badge: a strap hanging from a clip, with a
/// rigid card on its end that the user can grab, throw, and slam into walls.
///
/// Deliberately free of Flame and `dart:ui` imports, like `ball_physics.dart`,
/// so the feel can be pinned down by unit tests on any host machine.
///
/// Coordinates are the tile's logical pixels: origin top-left, y down.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// Tuning for [LanyardWorld]. Lengths are logical pixels, time is seconds,
/// masses are in units of one strap particle.
class LanyardConfig {
  const LanyardConfig({
    this.anchorInset = 18,
    this.ropeSegments = 12,
    this.ropeLength = 110,
    this.cardWidth = 196,
    this.cardHeight = 124,
    this.holeInset = 12,
    this.cardMass = 25,
    this.gravity = 1400,
    this.airDrag = 0.8,
    this.iterations = 8,
    this.substepSeconds = 1 / 240,
    this.maxFrameSeconds = 1 / 30,
    this.restitution = 0.35,
    this.impactSpeed = 600,
    this.grabStiffness = 0.5,
  });

  /// Distance of the clip below the tile's top edge.
  final double anchorInset;
  final int ropeSegments;
  final double ropeLength;
  final double cardWidth;
  final double cardHeight;

  /// Distance of the strap's hole below the card's top edge.
  final double holeInset;
  final double cardMass;
  final double gravity;

  /// Fraction of velocity lost per second, applied continuously.
  final double airDrag;
  final int iterations;
  final double substepSeconds;

  /// Longer frames (a resume, a hitch) are truncated rather than simulated.
  final double maxFrameSeconds;
  final double restitution;

  /// Minimum speed into a wall that counts as an [Impact].
  final double impactSpeed;

  /// Fraction of the finger offset corrected per solver iteration. Below 1 so
  /// the strap and walls win a tug-of-war against an out-of-reach finger.
  final double grabStiffness;
}

/// A card point hitting a tile wall at [speed] logical px/s.
class Impact {
  const Impact(this.position, this.speed);

  final vm.Vector2 position;
  final double speed;

  @override
  String toString() => 'Impact($position, ${speed.toStringAsFixed(0)})';
}

/// The card's rigid pose after a step.
class CardPose {
  CardPose({
    required this.center,
    required this.angle,
    required this.angularVelocity,
    required this.hole,
    required this.corners,
  });

  final vm.Vector2 center;

  /// In-plane rotation in radians; 0 is upright.
  final double angle;
  final double angularVelocity;
  final vm.Vector2 hole;

  /// Top-left, top-right, bottom-right, bottom-left.
  final List<vm.Vector2> corners;

  /// Converts a tile point into card space: origin at the card center, unrotated.
  vm.Vector2 toLocal(vm.Vector2 point) {
    final offset = point - center;
    final c = math.cos(angle);
    final s = math.sin(angle);
    return vm.Vector2(
      offset.x * c + offset.y * s,
      -offset.x * s + offset.y * c,
    );
  }

  vm.Vector2 toWorld(vm.Vector2 local) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return vm.Vector2(
      center.x + local.x * c - local.y * s,
      center.y + local.x * s + local.y * c,
    );
  }
}

/// A strap of verlet particles and a rigid card.
///
/// The card is five particles (hole, then four corners) that only ever move
/// together: every correction to a card point goes through [_pushCard], a
/// rigid-body position correction that splits the move into translation and
/// rotation by the card's mass and inertia. That is what lets the strap hold
/// the card *at the hole*, so a tilted card swings back upright, and what
/// lets a corner hitting a wall spin the card.
class LanyardWorld {
  LanyardWorld({
    required this._width,
    required this._height,
    this.config = const LanyardConfig(),
  }) : _segment = config.ropeLength / config.ropeSegments {
    _build();
  }

  final LanyardConfig config;
  final double _segment;

  double _width;
  double _height;
  double get width => _width;
  double get height => _height;

  final List<vm.Vector2> _position = [];
  final List<vm.Vector2> _previous = [];

  /// Walls each particle was pushed out of during the current substep.
  final List<int> _touching = [];

  /// The card's upright shape (hole, then corners) around its centroid.
  final List<vm.Vector2> _cardRest = [];
  late final double _cardInertia;

  late CardPose _pose;
  vm.Vector2 _cardVelocity = vm.Vector2.zero();
  double _accumulator = 0;

  /// Bilinear weights of the grabbed point over the four corners, or null.
  List<double>? _grabWeights;
  final vm.Vector2 _grabTarget = vm.Vector2.zero();
  final vm.Vector2 _grabPoint = vm.Vector2.zero();

  /// Farthest the grabbed point can be from the clip with the strap taut.
  double _grabReach = 0;

  int get _holeIndex => config.ropeSegments;
  int get _firstCorner => _holeIndex + 1;
  int get _cardEnd => _firstCorner + 4;

  vm.Vector2 get anchor => _position[0];
  CardPose get pose => _pose;
  vm.Vector2 get cardVelocity => _cardVelocity;
  bool get isGrabbed => _grabWeights != null;

  /// Clip, strap particles, and hole, in order: the strap's polyline.
  List<vm.Vector2> get ropePoints =>
      List.unmodifiable(_position.sublist(0, _holeIndex + 1));

  /// Current strap length from clip to hole, including any stretch.
  double get ropeLength {
    var length = 0.0;
    for (var i = 0; i < _holeIndex; i++) {
      length += _position[i].distanceTo(_position[i + 1]);
    }
    return length;
  }

  vm.Aabb2 get cardBounds {
    final min = _pose.corners.first.clone();
    final max = _pose.corners.first.clone();
    for (final corner in _pose.corners.skip(1)) {
      vm.Vector2.min(min, corner, min);
      vm.Vector2.max(max, corner, max);
    }
    return vm.Aabb2.minMax(min, max);
  }

  void _build() {
    final anchor = vm.Vector2(_width / 2, config.anchorInset);
    for (var i = 0; i <= config.ropeSegments; i++) {
      _addParticle(anchor + vm.Vector2(0, _segment * i));
    }

    final center =
        _position[_holeIndex] +
        vm.Vector2(0, config.cardHeight / 2 - config.holeInset);
    final halfWidth = config.cardWidth / 2;
    final halfHeight = config.cardHeight / 2;
    for (final local in [
      vm.Vector2(-halfWidth, -halfHeight),
      vm.Vector2(halfWidth, -halfHeight),
      vm.Vector2(halfWidth, halfHeight),
      vm.Vector2(-halfWidth, halfHeight),
    ]) {
      _addParticle(center + local);
    }

    final centroid = _cardCentroid();
    var inertia = 0.0;
    for (var j = _holeIndex; j < _cardEnd; j++) {
      final rest = _position[j] - centroid;
      _cardRest.add(rest);
      inertia += rest.length2;
    }
    _cardInertia = inertia * config.cardMass / 5;
    _updatePose(0);
  }

  void _addParticle(vm.Vector2 position) {
    _position.add(position.clone());
    _previous.add(position.clone());
    _touching.add(0);
  }

  /// Advances by a display frame of [dt] seconds, in fixed substeps.
  ///
  /// [externalAcceleration] is the tile's pseudo-force: the host scroll's
  /// acceleration, applied to every particle alongside gravity.
  List<Impact> step(double dt, {vm.Vector2? externalAcceleration}) {
    final frame = dt.clamp(0.0, config.maxFrameSeconds);
    final h = config.substepSeconds;
    _accumulator += frame;
    final substeps = (_accumulator / h).floor();
    _accumulator -= substeps * h;

    final impacts = <Impact>[];
    if (substeps == 0) return impacts;

    final acceleration = vm.Vector2(0, config.gravity);
    if (externalAcceleration != null) acceleration.add(externalAcceleration);
    final grabFrom = _grabPoint.clone();
    final reported = <int>{};

    for (var k = 1; k <= substeps; k++) {
      // Spread the finger's frame motion across substeps so a 60 Hz drag
      // event does not arrive as a single 240 Hz teleport.
      vm.Vector2.mix(grabFrom, _grabTarget, k / substeps, _grabPoint);
      _integrate(acceleration, h);
      _matchCardShape();
      _touching.fillRange(0, _touching.length, 0);
      for (var i = 0; i < config.iterations; i++) {
        _applyGrab();
        _solveStrap();
        _applyTethers();
        _collideWalls();
      }
      _bounceOffWalls(h, impacts, reported);
    }

    _updatePose(substeps * h);
    return impacts;
  }

  void _integrate(vm.Vector2 acceleration, double h) {
    final retain = math.exp(-config.airDrag * h);
    final accelerationStep = acceleration * (h * h);
    for (var i = 1; i < _position.length; i++) {
      final position = _position[i];
      final velocity = (position - _previous[i])..scale(retain);
      _previous[i].setFrom(position);
      position
        ..add(velocity)
        ..add(accelerationStep);
    }
  }

  vm.Vector2 _cardCentroid() {
    final centroid = vm.Vector2.zero();
    for (var j = _holeIndex; j < _cardEnd; j++) {
      centroid.add(_position[j]);
    }
    return centroid..scale(1 / 5);
  }

  /// Snaps the card particles onto the best-fit rigid placement of the rest
  /// shape (2D shape matching). Integration moves each particle in a straight
  /// line, which slightly shears a spinning card; this removes the shear.
  void _matchCardShape() {
    final centroid = _cardCentroid();
    var dot = 0.0;
    var cross = 0.0;
    for (var k = 0; k < 5; k++) {
      final rest = _cardRest[k];
      final current = _position[_holeIndex + k] - centroid;
      dot += rest.x * current.x + rest.y * current.y;
      cross += rest.x * current.y - rest.y * current.x;
    }
    final angle = math.atan2(cross, dot);
    final c = math.cos(angle);
    final s = math.sin(angle);
    for (var k = 0; k < 5; k++) {
      final rest = _cardRest[k];
      _position[_holeIndex + k].setValues(
        centroid.x + rest.x * c - rest.y * s,
        centroid.y + rest.x * s + rest.y * c,
      );
    }
  }

  /// The card's inverse mass as felt at [point] when pushed along [normal]:
  /// translation plus the rotation that push would cause.
  double _cardInverseMassAt(vm.Vector2 point, vm.Vector2 normal) {
    final arm = point - _cardCentroid();
    final torqueArm = arm.x * normal.y - arm.y * normal.x;
    return 1 / config.cardMass + torqueArm * torqueArm / _cardInertia;
  }

  /// Moves the card rigidly so that its material [point] moves by [correction].
  void _pushCard(vm.Vector2 point, vm.Vector2 correction) {
    final distance = correction.length;
    if (distance < 1e-9) return;
    final normal = correction / distance;
    final centroid = _cardCentroid();
    final arm = point - centroid;
    final torqueArm = arm.x * normal.y - arm.y * normal.x;
    final impulse = distance / _cardInverseMassAt(point, normal);
    final translation = normal * (impulse / config.cardMass);
    final rotation = torqueArm * impulse / _cardInertia;
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    for (var j = _holeIndex; j < _cardEnd; j++) {
      final offset = _position[j] - centroid;
      _position[j].setValues(
        centroid.x + translation.x + offset.x * c - offset.y * s,
        centroid.y + translation.y + offset.x * s + offset.y * c,
      );
    }
  }

  /// Pulls the grabbed material point toward the finger. The point is the
  /// bilinear blend of the corners, which is exact for a rigid rectangle.
  void _applyGrab() {
    final weights = _grabWeights;
    if (weights == null) return;
    final point = vm.Vector2.zero();
    for (var i = 0; i < 4; i++) {
      point.addScaled(_position[_firstCorner + i], weights[i]);
    }
    _pushCard(point, (_grabPoint - point)..scale(config.grabStiffness));
  }

  /// Keeps every strap segment at its rest length. The last segment joins a
  /// strap particle to the card's hole, weighted by the card's inverse mass
  /// at the hole so the strap's pull turns the card as well as moving it.
  void _solveStrap() {
    for (var i = 0; i < _holeIndex; i++) {
      final a = _position[i];
      final b = _position[i + 1];
      final delta = b - a;
      final distance = delta.length;
      if (distance < 1e-9) continue;
      final normal = delta / distance;
      final stretch = distance - _segment;

      final wa = i == 0 ? 0.0 : 1.0;
      final isCard = i + 1 == _holeIndex;
      final wb = isCard ? _cardInverseMassAt(b, normal) : 1.0;
      final totalWeight = wa + wb;
      a.addScaled(normal, stretch * wa / totalWeight);
      final move = normal * (-stretch * wb / totalWeight);
      if (isCard) {
        _pushCard(b.clone(), move);
      } else {
        b.add(move);
      }
    }
  }

  /// Long-range tethers: no strap point may be farther from the clip than
  /// the strap length up to it. A plain chain converges too slowly to stay
  /// inextensible under a heavy card, and a visibly stretching strap reads as
  /// rubber.
  void _applyTethers() {
    final anchor = _position[0];
    for (var i = 1; i <= _holeIndex; i++) {
      final offset = _position[i] - anchor;
      final distance = offset.length;
      final limit = _segment * i;
      if (distance <= limit) continue;
      final correction = offset..scale((limit - distance) / distance);
      if (i < _holeIndex) {
        _position[i].add(correction);
      } else {
        _pushCard(_position[i].clone(), correction);
      }
    }
  }

  static const _left = 1;
  static const _right = 2;
  static const _top = 4;
  static const _bottom = 8;

  void _collideWalls() {
    for (var i = 1; i < _position.length; i++) {
      final position = _position[i];
      var walls = 0;
      if (position.x < 0) walls |= _left;
      if (position.x > _width) walls |= _right;
      if (position.y < 0) walls |= _top;
      if (position.y > _height) walls |= _bottom;
      if (walls == 0) continue;

      _touching[i] |= walls;
      final inside = vm.Vector2(
        position.x.clamp(0.0, _width),
        position.y.clamp(0.0, _height),
      );
      if (i < _holeIndex) {
        position.setFrom(inside);
      } else {
        _pushCard(position.clone(), inside - position);
      }
    }
  }

  /// Reflects the velocity of every particle pushed out of a wall this
  /// substep, and reports card points that just arrived there fast enough to
  /// be an [Impact].
  void _bounceOffWalls(double h, List<Impact> impacts, Set<int> reported) {
    for (var i = 1; i < _position.length; i++) {
      final touching = _touching[i];
      final position = _position[i];
      final previous = _previous[i];
      final velocity = position - previous;
      var speed = 0.0;

      void bounce(int wall, double into, void Function() reflect) {
        if (touching & wall == 0 || into <= 0) return;
        speed = math.max(speed, into / h);
        reflect();
      }

      bounce(
        _left,
        -velocity.x,
        () => previous.x = position.x + velocity.x * config.restitution,
      );
      bounce(
        _right,
        velocity.x,
        () => previous.x = position.x + velocity.x * config.restitution,
      );
      bounce(
        _top,
        -velocity.y,
        () => previous.y = position.y + velocity.y * config.restitution,
      );
      bounce(
        _bottom,
        velocity.y,
        () => previous.y = position.y + velocity.y * config.restitution,
      );

      final isCard = i >= _holeIndex;
      if (isCard && speed > config.impactSpeed && reported.add(i)) {
        impacts.add(Impact(position.clone(), speed));
      }
    }
  }

  void _updatePose(double elapsed) {
    final corners = [
      for (var i = 0; i < 4; i++) _position[_firstCorner + i].clone(),
    ];
    final center = vm.Vector2.zero();
    for (final corner in corners) {
      center.add(corner);
    }
    center.scale(0.25);
    final top = corners[1] - corners[0];
    final angle = math.atan2(top.y, top.x);

    var angularVelocity = 0.0;
    if (elapsed > 0) {
      final velocity = vm.Vector2.zero();
      for (var i = 0; i < 4; i++) {
        velocity.add(_position[_firstCorner + i] - _previous[_firstCorner + i]);
      }
      _cardVelocity = velocity..scale(0.25 / config.substepSeconds);
      angularVelocity = _wrap(angle - _pose.angle) / elapsed;
    }

    _pose = CardPose(
      center: center,
      angle: angle,
      angularVelocity: angularVelocity,
      hole: _position[_holeIndex].clone(),
      corners: corners,
    );
  }

  static double _wrap(double radians) =>
      math.atan2(math.sin(radians), math.cos(radians));

  bool hitTest(vm.Vector2 point) {
    final local = _pose.toLocal(point);
    return local.x.abs() <= config.cardWidth / 2 &&
        local.y.abs() <= config.cardHeight / 2;
  }

  /// Takes hold of the card at [point] if it lies on the card.
  bool grab(vm.Vector2 point) {
    if (isGrabbed || !hitTest(point)) return false;
    final local = _pose.toLocal(point);
    final u = (local.x / config.cardWidth + 0.5).clamp(0.0, 1.0);
    final v = (local.y / config.cardHeight + 0.5).clamp(0.0, 1.0);
    _grabWeights = [(1 - u) * (1 - v), u * (1 - v), u * v, (1 - u) * v];
    _grabPoint.setFrom(point);
    _grabTarget.setFrom(point);
    _grabReach = config.ropeLength + point.distanceTo(_position[_holeIndex]);
    return true;
  }

  /// Moves the grab toward [point]; it arrives over the next [step].
  ///
  /// A finger beyond the strap's reach holds the card at full stretch instead
  /// of stretching the strap, the way a real lanyard stops your hand.
  void dragTo(vm.Vector2 point) {
    if (!isGrabbed) return;
    final offset = point - anchor;
    final distance = offset.length;
    if (distance > _grabReach) offset.scale(_grabReach / distance);
    _grabTarget.setFrom(anchor + offset);
  }

  /// Lets go. The card keeps the velocity the drag gave it.
  void release() => _grabWeights = null;

  /// Adapts to a new tile size, keeping the clip centered and the badge on it.
  void resize(double width, double height) {
    final shift = vm.Vector2(width / 2, config.anchorInset) - anchor;
    _width = width;
    _height = height;
    for (var i = 0; i < _position.length; i++) {
      _position[i].add(shift);
      _previous[i].add(shift);
    }
    _grabPoint.add(shift);
    _grabTarget.add(shift);
    _updatePose(0);
  }
}

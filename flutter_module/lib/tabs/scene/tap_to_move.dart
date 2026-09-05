/// Tap-to-move maths for tab 5 (`06-island-scene.md`).
///
/// Deliberately free of `flutter_scene` and `flutter:ui` imports: everything
/// here is plain vector maths so it can be exercised by `flutter test` on a
/// machine with no GPU. The scene-graph side that consumes it lives in
/// `island_scene.dart`.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// Where [ray] crosses the horizontal plane `y == planeY`.
///
/// Returns null when the ray is parallel to the plane, or when the crossing is
/// behind the ray's origin — i.e. when the tap landed on the sky rather than on
/// the ground.
///
/// The ray is expected to come from [Camera.screenPointToRay], which already
/// works in the view's *logical* pixels. That is the whole defence against the
/// classic unprojection bug: no device-pixel-ratio factor is applied here, and
/// none should be applied by the caller — see `06-island-scene.md`.
vm.Vector3? intersectGroundPlane(vm.Ray ray, {double planeY = 0.0}) {
  final direction = ray.direction;
  if (direction.y.abs() < 1e-9) {
    return null;
  }
  final t = (planeY - ray.origin.y) / direction.y;
  if (!t.isFinite || t <= 0) {
    return null;
  }
  return ray.origin + direction * t;
}

/// Pulls [point] inside a circle of [radius] centred on the world origin, in
/// the XZ plane, so the character can never walk into the sea.
vm.Vector3 clampToIsland(vm.Vector3 point, {required double radius}) {
  final distance = math.sqrt(point.x * point.x + point.z * point.z);
  if (distance <= radius || distance == 0) {
    return point.clone();
  }
  final scale = radius / distance;
  return vm.Vector3(point.x * scale, point.y, point.z * scale);
}

/// The walkable point a tap selects, or null if the tap missed the ground.
vm.Vector3? pickIslandPoint(
  vm.Ray ray, {
  required double radius,
  double planeY = 0.0,
}) {
  final hit = intersectGroundPlane(ray, planeY: planeY);
  if (hit == null) {
    return null;
  }
  return clampToIsland(hit, radius: radius);
}

/// Signed shortest angular distance from [from] to [to], in radians,
/// always within `(-pi, pi]`.
double shortestAngleDelta(double from, double to) {
  var delta = (to - from) % (2 * math.pi);
  if (delta > math.pi) {
    delta -= 2 * math.pi;
  } else if (delta <= -math.pi) {
    delta += 2 * math.pi;
  }
  return delta;
}

/// The character's walk: a position, a heading, and a target it eases toward.
///
/// Pure state, advanced by [advance]. `island_scene.dart` wraps one of these in
/// a `flutter_scene` component that writes the node transform and cross-fades
/// the walk/idle animation clips.
class WalkerMotion {
  WalkerMotion({
    vm.Vector3? position,
    this.yaw = 0.0,
    this.speed = 1.9,
    this.turnRate = 9.0,
    this.arriveRadius = 0.06,
  }) : position = position?.clone() ?? vm.Vector3.zero();

  /// Current world position. `y` is left untouched by [advance]; the island's
  /// walkable surface is flat.
  vm.Vector3 position;

  /// Heading in radians about world +Y. Zero looks along +Z.
  double yaw;

  /// Walk speed in world units per second.
  double speed;

  /// Radians per second the character turns toward its heading.
  double turnRate;

  /// How close counts as arrived.
  double arriveRadius;

  vm.Vector3? _target;

  /// The point being walked to, or null when standing still.
  vm.Vector3? get target => _target?.clone();

  /// Whether the character is currently walking.
  bool get isMoving => _target != null;

  /// How far there is left to walk, in world units. Zero when standing still.
  double get remainingDistance {
    final target = _target;
    if (target == null) {
      return 0;
    }
    final dx = target.x - position.x;
    final dz = target.z - position.z;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// Starts walking to [target]. A target already within [arriveRadius] is
  /// ignored, so a stray tap on the character's own feet does not twitch it.
  void moveTo(vm.Vector3 target) {
    final dx = target.x - position.x;
    final dz = target.z - position.z;
    if (math.sqrt(dx * dx + dz * dz) <= arriveRadius) {
      return;
    }
    _target = vm.Vector3(target.x, position.y, target.z);
  }

  /// Stops where it stands.
  void stop() => _target = null;

  /// Advances the walk by [deltaSeconds].
  ///
  /// The heading eases toward the direction of travel rather than snapping, so
  /// the character visibly turns before it sets off.
  void advance(double deltaSeconds) {
    if (deltaSeconds <= 0) {
      return;
    }
    // A long stall (a backgrounded tab, a paused render loop) must not
    // teleport the character across the island when it resumes.
    final dt = math.min(deltaSeconds, 0.1);

    final target = _target;
    if (target == null) {
      return;
    }

    final dx = target.x - position.x;
    final dz = target.z - position.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    if (distance <= arriveRadius) {
      position = vm.Vector3(target.x, position.y, target.z);
      _target = null;
      return;
    }

    final desiredYaw = math.atan2(dx, dz);
    final turn = shortestAngleDelta(yaw, desiredYaw);
    final maxTurn = turnRate * dt;
    yaw += turn.abs() <= maxTurn ? turn : maxTurn * turn.sign;

    final step = math.min(speed * dt, distance);
    position = vm.Vector3(
      position.x + dx / distance * step,
      position.y,
      position.z + dz / distance * step,
    );
  }
}

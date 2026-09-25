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

/// Picks a random walkable point on the island disc, staying clear of [avoid]
/// (typically the campfire). Uses uniform-disc sampling so destinations do not
/// clump at the origin.
vm.Vector3 pickWanderTarget({
  required math.Random random,
  required double walkableRadius,
  required vm.Vector3 avoid,
  required double avoidRadius,
  double groundY = 0.0,
  int maxAttempts = 24,
}) {
  final avoidRadiusSq = avoidRadius * avoidRadius;
  for (var i = 0; i < maxAttempts; i++) {
    final angle = random.nextDouble() * math.pi * 2.0;
    final radius = math.sqrt(random.nextDouble()) * walkableRadius;
    final x = math.cos(angle) * radius;
    final z = math.sin(angle) * radius;
    final dx = x - avoid.x;
    final dz = z - avoid.z;
    if (dx * dx + dz * dz >= avoidRadiusSq) {
      return vm.Vector3(x, groundY, z);
    }
  }
  return clampToIsland(
    vm.Vector3(avoid.x + walkableRadius, groundY, avoid.z),
    radius: walkableRadius,
  );
}

/// Filters Poisson-disc samples (in a square of side `2 * rectOrigin`) down to
/// extra foliage points that sit on the island, miss the campfire, and miss
/// already-placed props.
List<vm.Vector2> filterIslandScatterPoints({
  required List<vm.Vector2> samples,
  required double rectOrigin,
  required double walkableRadius,
  required vm.Vector2 campfire,
  required double campfireAvoidRadius,
  required List<vm.Vector2> occupied,
  required double occupiedRadius,
  required int maxCount,
  double innerClearRadius = 0.0,
}) {
  final walkableSq = walkableRadius * walkableRadius;
  final campfireSq = campfireAvoidRadius * campfireAvoidRadius;
  final occupiedSq = occupiedRadius * occupiedRadius;
  final innerSq = innerClearRadius * innerClearRadius;
  final kept = <vm.Vector2>[];
  for (final sample in samples) {
    if (kept.length >= maxCount) {
      break;
    }
    final world = vm.Vector2(sample.x - rectOrigin, sample.y - rectOrigin);
    if (world.length2 > walkableSq) {
      continue;
    }
    if (innerSq > 0.0 && world.length2 < innerSq) {
      continue;
    }
    final toFireX = world.x - campfire.x;
    final toFireY = world.y - campfire.y;
    if (toFireX * toFireX + toFireY * toFireY < campfireSq) {
      continue;
    }
    var blocked = false;
    for (final other in occupied) {
      final dx = world.x - other.x;
      final dy = world.y - other.y;
      if (dx * dx + dy * dy < occupiedSq) {
        blocked = true;
        break;
      }
    }
    if (blocked) {
      continue;
    }
    kept.add(world);
  }
  return kept;
}

/// Clamps [vector] to length [max].
vm.Vector3 truncateSteering(vm.Vector3 vector, double max) {
  if (vector.length2 > max * max) {
    return vector.normalized() * max;
  }
  return vector;
}

/// Kit `Steering.arrive` — GPU-free copy so NPC motion can be unit-tested.
vm.Vector3 steeringArrive(
  vm.Vector3 currentPos,
  vm.Vector3 currentVel,
  vm.Vector3 targetPos, {
  double slowingRadius = 3.0,
  double maxSpeed = 5.0,
  double maxForce = 10.0,
}) {
  final toTarget = targetPos - currentPos;
  final distance = toTarget.length;
  if (distance < 0.001) {
    return -currentVel;
  }
  final rampedSpeed = maxSpeed * (distance / slowingRadius);
  final targetSpeed = math.min(rampedSpeed, maxSpeed);
  final desiredVel = (toTarget / distance) * targetSpeed;
  return truncateSteering(desiredVel - currentVel, maxForce);
}

/// Kit `Steering.separation` — GPU-free copy so NPC motion can be unit-tested.
vm.Vector3 steeringSeparation(
  vm.Vector3 currentPos,
  vm.Vector3 currentVel,
  List<vm.Vector3> neighbors, {
  double desiredDistance = 2.0,
  double maxSpeed = 5.0,
  double maxForce = 10.0,
}) {
  var pushDir = vm.Vector3.zero();
  var count = 0;
  for (final other in neighbors) {
    final diff = currentPos - other;
    final dist = diff.length;
    if (dist > 0.001 && dist < desiredDistance) {
      pushDir += diff.normalized() / dist;
      count++;
    }
  }
  if (count == 0) {
    return vm.Vector3.zero();
  }
  pushDir /= count.toDouble();
  if (pushDir.length2 == 0) {
    return vm.Vector3.zero();
  }
  final desiredVel = pushDir.normalized() * maxSpeed;
  return truncateSteering(desiredVel - currentVel, maxForce);
}

/// Kit `Steering.seek`.
vm.Vector3 steeringSeek(
  vm.Vector3 currentPos,
  vm.Vector3 currentVel,
  vm.Vector3 targetPos, {
  double maxSpeed = 5.0,
  double maxForce = 10.0,
}) {
  final desired = targetPos - currentPos;
  if (desired.length2 == 0) {
    return vm.Vector3.zero();
  }
  final desiredVel = desired.normalized() * maxSpeed;
  return truncateSteering(desiredVel - currentVel, maxForce);
}

/// Kit `Steering.alignment`.
vm.Vector3 steeringAlignment(
  vm.Vector3 currentVel,
  List<vm.Vector3> neighborVelocities, {
  double maxSpeed = 5.0,
  double maxForce = 10.0,
}) {
  if (neighborVelocities.isEmpty) {
    return vm.Vector3.zero();
  }
  var avgVel = vm.Vector3.zero();
  for (final v in neighborVelocities) {
    avgVel += v;
  }
  avgVel /= neighborVelocities.length.toDouble();
  if (avgVel.length2 == 0) {
    return vm.Vector3.zero();
  }
  final desired = avgVel.normalized() * maxSpeed;
  return truncateSteering(desired - currentVel, maxForce);
}

/// Kit `Steering.cohesion`.
vm.Vector3 steeringCohesion(
  vm.Vector3 currentPos,
  vm.Vector3 currentVel,
  List<vm.Vector3> neighborPositions, {
  double maxSpeed = 5.0,
  double maxForce = 10.0,
}) {
  if (neighborPositions.isEmpty) {
    return vm.Vector3.zero();
  }
  var center = vm.Vector3.zero();
  for (final p in neighborPositions) {
    center += p;
  }
  center /= neighborPositions.length.toDouble();
  return steeringSeek(
    currentPos,
    currentVel,
    center,
    maxSpeed: maxSpeed,
    maxForce: maxForce,
  );
}

/// Velocity-based NPC walk used in Ultra: arrive at a wander target and keep
/// a little space from the player, without leaving the island or the campfire.
class NpcSteeringMotion {
  NpcSteeringMotion({
    vm.Vector3? position,
    this.yaw = 0.0,
    this.maxSpeed = 1.4,
    this.maxForce = 8.0,
    this.slowingRadius = 1.6,
    this.arriveRadius = 0.18,
    this.separationDistance = 1.8,
    this.groundY = 0.0,
  }) : position = position?.clone() ?? vm.Vector3(0, groundY, 0),
       velocity = vm.Vector3.zero();

  vm.Vector3 position;
  vm.Vector3 velocity;
  double yaw;
  double maxSpeed;
  double maxForce;
  double slowingRadius;
  double arriveRadius;
  double separationDistance;
  final double groundY;

  vm.Vector3? _target;

  vm.Vector3? get target => _target?.clone();

  bool get isMoving {
    final horizontal = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
    return _target != null || horizontal > 0.08;
  }

  void moveTo(vm.Vector3 target) {
    _target = vm.Vector3(target.x, groundY, target.z);
  }

  void stop() {
    _target = null;
    velocity.setZero();
  }

  void advance(
    double deltaSeconds, {
    required vm.Vector3 playerPosition,
    required double walkableRadius,
    required vm.Vector3 campfire,
    required double campfireAvoidRadius,
  }) {
    var force = vm.Vector3.zero();
    final target = _target;
    if (target != null) {
      force += steeringArrive(
        position,
        velocity,
        target,
        slowingRadius: slowingRadius,
        maxSpeed: maxSpeed,
        maxForce: maxForce,
      );
    }
    force += steeringSeparation(
      position,
      velocity,
      <vm.Vector3>[playerPosition],
      desiredDistance: separationDistance,
      maxSpeed: maxSpeed,
      maxForce: maxForce * 0.65,
    );
    integrate(
      force,
      deltaSeconds,
      walkableRadius: walkableRadius,
      campfire: campfire,
      campfireAvoidRadius: campfireAvoidRadius,
    );
  }

  /// Applies a kit (or GPU-free) steering [force] and keeps the NPC on the island.
  void integrate(
    vm.Vector3 force,
    double deltaSeconds, {
    required double walkableRadius,
    required vm.Vector3 campfire,
    required double campfireAvoidRadius,
  }) {
    if (deltaSeconds <= 0) {
      return;
    }
    final dt = math.min(deltaSeconds, 0.1);
    velocity += force * dt;
    velocity = truncateSteering(velocity, maxSpeed);
    position = vm.Vector3(
      position.x + velocity.x * dt,
      groundY,
      position.z + velocity.z * dt,
    );
    position = clampToIsland(position, radius: walkableRadius);

    final fireDx = position.x - campfire.x;
    final fireDz = position.z - campfire.z;
    final fireDist = math.sqrt(fireDx * fireDx + fireDz * fireDz);
    if (fireDist < campfireAvoidRadius) {
      final scale = fireDist < 1e-5
          ? campfireAvoidRadius
          : campfireAvoidRadius / fireDist;
      position = vm.Vector3(
        campfire.x + fireDx * scale,
        groundY,
        campfire.z + fireDz * scale,
      );
      position = clampToIsland(position, radius: walkableRadius);
      velocity.x += fireDx * 2.0;
      velocity.z += fireDz * 2.0;
      velocity = truncateSteering(velocity, maxSpeed);
    }

    final speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
    if (speed > 0.04) {
      yaw = math.atan2(velocity.x, velocity.z);
    }

    final target = _target;
    if (target != null) {
      final dx = target.x - position.x;
      final dz = target.z - position.z;
      if (math.sqrt(dx * dx + dz * dz) <= arriveRadius) {
        position = vm.Vector3(target.x, groundY, target.z);
        stop();
      }
    }
  }
}

/// Tiny ballistic chip flung by an Ultra punch; lives ~1.2s then despawns.
class DebrisChipMotion {
  DebrisChipMotion({
    required vm.Vector3 position,
    required vm.Vector3 velocity,
    this.lifetime = 1.2,
  }) : position = position.clone(),
       velocity = velocity.clone();

  vm.Vector3 position;
  vm.Vector3 velocity;
  double age = 0.0;
  final double lifetime;

  static const double gravity = -14.0;

  bool get isDead => age >= lifetime;

  void advance(double deltaSeconds, {required double groundY}) {
    if (deltaSeconds <= 0 || isDead) {
      return;
    }
    final dt = math.min(deltaSeconds, 0.1);
    age += dt;
    velocity.y += gravity * dt;
    position += velocity * dt;
    final floor = groundY + 0.04;
    if (position.y < floor) {
      position.y = floor;
      velocity.y *= -0.28;
      velocity.x *= 0.72;
      velocity.z *= 0.72;
    }
  }
}

/// A sky-path bird that orbits the island: seek a point ahead on a ring,
/// plus a light flocking mix so a group stays together without stacking.
class FlockBirdMotion {
  FlockBirdMotion({
    required vm.Vector3 position,
    vm.Vector3? velocity,
    this.maxSpeed = 7.0,
    this.maxForce = 14.0,
    this.orbitRadius = 12.0,
    this.cruiseHeight = 5.5,
    this.separationDistance = 2.2,
  }) : position = position.clone(),
       velocity = velocity?.clone() ?? vm.Vector3.zero();

  vm.Vector3 position;
  vm.Vector3 velocity;
  double yaw = 0.0;
  double pitch = 0.0;

  /// Roll about the bird's forward (+Z) axis, in radians: the bank of a
  /// coordinated turn, `atan(speed * turn rate / g)`, so the wing on the
  /// inside of the turn dips. Eased, so flocking jitter doesn't rock it.
  double roll = 0.0;
  double maxSpeed;
  double maxForce;
  double orbitRadius;
  double cruiseHeight;
  double separationDistance;

  void advance(
    double deltaSeconds, {
    required List<vm.Vector3> neighborPositions,
    required List<vm.Vector3> neighborVelocities,
  }) {
    if (deltaSeconds <= 0) {
      return;
    }
    final dt = math.min(deltaSeconds, 0.1);
    final angle = math.atan2(position.x, position.z);
    final ahead = angle + 0.55;
    final seekTarget = vm.Vector3(
      math.sin(ahead) * orbitRadius,
      cruiseHeight,
      math.cos(ahead) * orbitRadius,
    );
    var force = steeringSeek(
      position,
      velocity,
      seekTarget,
      maxSpeed: maxSpeed,
      maxForce: maxForce,
    );
    force += steeringSeparation(
      position,
      velocity,
      neighborPositions,
      desiredDistance: separationDistance,
      maxSpeed: maxSpeed,
      maxForce: maxForce * 0.8,
    );
    force += steeringAlignment(
      velocity,
      neighborVelocities,
      maxSpeed: maxSpeed,
      maxForce: maxForce * 0.35,
    );
    force += steeringCohesion(
      position,
      velocity,
      neighborPositions,
      maxSpeed: maxSpeed,
      maxForce: maxForce * 0.25,
    );

    velocity += force * dt;
    velocity = truncateSteering(velocity, maxSpeed);
    position += velocity * dt;
    position.y = position.y.clamp(3.4, 8.0);

    final xz = math.sqrt(position.x * position.x + position.z * position.z);
    if (xz < 9.0 && xz > 1e-5) {
      final scale = 9.0 / xz;
      position.x *= scale;
      position.z *= scale;
    } else if (xz > 16.5 && xz > 1e-5) {
      final scale = 16.5 / xz;
      position.x *= scale;
      position.z *= scale;
    }

    final speed = velocity.length;
    if (speed > 0.08) {
      final previousYaw = yaw;
      yaw = math.atan2(velocity.x, velocity.z);
      pitch = math.asin((velocity.y / speed).clamp(-1.0, 1.0));
      // Yaw grows as the heading swings toward the bird's left (+X in its
      // own frame), and a left bank is a negative roll about +Z.
      final turnRate = shortestAngleDelta(previousYaw, yaw) / dt;
      final bank = math.atan(speed * turnRate / 9.81).clamp(-0.7, 0.7);
      roll += (-bank - roll) * math.min(1.0, dt * 3.0);
    }
  }

  /// The body's orientation: heading, then climb, then bank. The model
  /// faces +Z with its wings along X.
  vm.Quaternion get attitude =>
      vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) *
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -pitch) *
      vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll);
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
    this.groundY = 0.0,
  }) : position = position?.clone() ?? vm.Vector3(0, groundY, 0);

  /// Current world position.
  vm.Vector3 position;

  /// Heading in radians about world +Y. Zero looks along +Z.
  double yaw;

  /// Walk speed in world units per second.
  double speed;

  /// Radians per second the character turns toward its heading.
  double turnRate;

  /// How close counts as arrived.
  double arriveRadius;

  /// Ground surface level.
  final double groundY;

  /// Current vertical velocity in world units per second.
  double verticalVelocity = 0.0;

  static const double jumpVelocity = 4.8;
  static const double gravity = -14.0;

  /// Whether the character is currently airborne.
  bool get isJumping => position.y > groundY + 1e-4 || verticalVelocity > 0;

  /// Initiates a jump if the character is grounded.
  bool jump({double launchVelocity = jumpVelocity}) {
    if (!isJumping) {
      verticalVelocity = launchVelocity;
      return true;
    }
    return false;
  }

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
    _target = vm.Vector3(target.x, groundY, target.z);
  }

  /// Stops where it stands.
  void stop() => _target = null;

  /// Advances the walk and jump by [deltaSeconds].
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

    // Ballistic vertical integration
    if (isJumping || verticalVelocity != 0.0) {
      verticalVelocity += gravity * dt;
      position.y += verticalVelocity * dt;
      if (position.y <= groundY) {
        position.y = groundY;
        verticalVelocity = 0.0;
      }
    }

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

/// Computes the camera eye and look-at target for an over-the-shoulder
/// (third-person chase) camera with tight, immersive Resident Evil 4 style framing.
class OtsCameraRig {
  const OtsCameraRig({
    this.followDistance = 2.0,
    this.camHeight = 1.15,
    this.shoulderOffset = 0.25,
    this.targetHeight = 0.65,
    this.lookAheadDistance = 4.0,
    this.minGroundClearance = 0.40,
  });

  /// Distance the camera trails behind the character along the negative forward vector.
  final double followDistance;

  /// Elevation of the camera above the character's feet.
  final double camHeight;

  /// Lateral offset along the character's right vector (placing the camera over the right shoulder).
  final double shoulderOffset;

  /// Height of the look-at target above the character's feet.
  final double targetHeight;

  /// How far in front of the character the look-at target is positioned.
  final double lookAheadDistance;

  /// Floor clamp ensuring the camera never dips below terrain or water.
  final double minGroundClearance;

  /// Computes `(eye, target)` vectors in world coordinates given the character's
  /// [characterPosition] and total camera [yaw] (which may include a user swipe offset).
  (vm.Vector3 eye, vm.Vector3 target) compute({
    required vm.Vector3 characterPosition,
    required double yaw,
    double pitchOffset = 0.0,
    double groundY = 0.0,
  }) {
    final forward = vm.Vector3(math.sin(yaw), 0.0, math.cos(yaw));
    final right = vm.Vector3(math.cos(yaw), 0.0, -math.sin(yaw));

    final height = camHeight + math.sin(pitchOffset) * 0.8;
    final eyeY = math.max(
      characterPosition.y + height,
      groundY + minGroundClearance,
    );

    final eye = vm.Vector3(
      characterPosition.x - forward.x * followDistance + right.x * shoulderOffset,
      eyeY,
      characterPosition.z - forward.z * followDistance + right.z * shoulderOffset,
    );

    final target = vm.Vector3(
      characterPosition.x +
          forward.x * lookAheadDistance +
          right.x * (shoulderOffset * 0.25),
      characterPosition.y + targetHeight,
      characterPosition.z +
          forward.z * lookAheadDistance +
          right.z * (shoulderOffset * 0.25),
    );

    return (eye, target);
  }
}

/// Performs view-frustum culling tests against spherical and bounding-box volumes.
///
/// Used to cull objects outside the camera's field of view in over-the-shoulder
/// mode so only what the camera actually sees is processed and rendered.
class FrustumCuller {
  const FrustumCuller();

  /// Tests whether a bounding sphere at [center] with [radius] intersects
  /// or is inside [frustum].
  bool isSphereVisible(vm.Frustum frustum, vm.Vector3 center, double radius) {
    return frustum.intersectsWithSphere(
      vm.Sphere.centerRadius(center, radius),
    );
  }

  /// Tests whether an axis-aligned bounding box [bounds] intersects [frustum].
  bool isAabbVisible(vm.Frustum frustum, vm.Aabb3 bounds) {
    return frustum.intersectsWithAabb3(bounds);
  }
}

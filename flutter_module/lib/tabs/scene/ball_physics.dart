/// 3D physics engine for bouncing, rolling, and colliding spheres on the island.
///
/// Deliberately free of `flutter_scene` and `dart:ui` imports so physics,
/// obstacle reflections, and character collisions can be thoroughly unit-tested
/// on any host machine without GPU or graphics context.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// A circular obstacle hull in the XZ plane representing a tree trunk, boulder,
/// or campfire that balls bounce off.
class IslandObstacle {
  const IslandObstacle({
    required this.name,
    required this.x,
    required this.z,
    required this.radius,
  });

  final String name;
  final double x;
  final double z;
  final double radius;

  /// Default obstacle layout matching the fixed prop placements in `island_scene.dart`.
  static List<IslandObstacle> defaultObstacles() {
    return const <IslandObstacle>[
      IslandObstacle(name: 'palm_1', x: 2.05, z: -1.25, radius: 0.35),
      IslandObstacle(name: 'palm_2', x: -2.25, z: 0.85, radius: 0.35),
      IslandObstacle(name: 'palm_3', x: 0.45, z: -2.45, radius: 0.35),
      IslandObstacle(name: 'pine_1', x: -1.55, z: -1.95, radius: 0.35),
      IslandObstacle(name: 'pine_2', x: -0.55, z: -2.55, radius: 0.35),
      IslandObstacle(name: 'pine_3', x: 2.35, z: 1.35, radius: 0.35),
      IslandObstacle(name: 'rock_large_1', x: 1.1, z: 1.95, radius: 0.65),
      IslandObstacle(name: 'rock_large_2', x: -2.6, z: -0.35, radius: 0.55),
      IslandObstacle(name: 'rock_small_1', x: 1.75, z: 0.55, radius: 0.40),
      IslandObstacle(name: 'rock_small_2', x: -1.15, z: 1.15, radius: 0.45),
      IslandObstacle(name: 'rock_small_3', x: 0.95, z: -0.75, radius: 0.40),
      IslandObstacle(name: 'campfire', x: 0.0, z: -0.15, radius: 0.55),
      IslandObstacle(name: 'bush_1', x: 1.35, z: 2.35, radius: 0.35),
      IslandObstacle(name: 'bush_2', x: -2.05, z: 1.85, radius: 0.35),
      IslandObstacle(name: 'bush_3', x: 2.75, z: -0.45, radius: 0.35),
      IslandObstacle(name: 'bush_4', x: -0.85, z: -1.05, radius: 0.35),
    ];
  }
}

/// A simulated 3D sphere with mass, restitution, rolling friction, and orientation.
class PhysicsBall {
  PhysicsBall({
    required vm.Vector3 position,
    vm.Vector3? velocity,
    vm.Quaternion? rotation,
    this.radius = 0.32,
    this.restitution = 0.72,
    this.groundFriction = 1.6,
    this.groundY = 0.0,
    this.colorLinearRgba = const <double>[1.0, 0.82, 0.12, 1.0],
  })  : position = position.clone(),
        velocity = velocity?.clone() ?? vm.Vector3.zero(),
        rotation = rotation?.clone() ?? vm.Quaternion.identity();

  /// 3D position of the sphere center in world units.
  vm.Vector3 position;

  /// Linear velocity in world units per second.
  vm.Vector3 velocity;

  /// Current 3D rolling orientation quaternion.
  vm.Quaternion rotation;

  /// Radius of the sphere.
  final double radius;

  /// Bounciness [0..1] where 1 is a perfectly elastic bounce.
  final double restitution;

  /// Rolling and sliding deceleration per second when in contact with the ground.
  final double groundFriction;

  /// Height of the walkable island plane.
  final double groundY;

  /// Linear RGBA color for the sphere material.
  final List<double> colorLinearRgba;

  /// True when the ball is resting on the ground plane.
  bool get isOnGround => (position.y - (groundY + radius)).abs() < 0.02;

  /// Applies an instantaneous impulse vector (adds directly to velocity).
  void applyImpulse(vm.Vector3 impulse) {
    velocity.add(impulse);
  }

  /// Advances ball physics by [deltaSeconds].
  void step({
    required double deltaSeconds,
    required double islandRimRadius,
    required List<IslandObstacle> obstacles,
    double gravity = -12.0,
  }) {
    if (deltaSeconds <= 0) {
      return;
    }
    // Prevent huge steps on stalls.
    final dt = math.min(deltaSeconds, 0.066);

    // Apply gravity
    velocity.y += gravity * dt;

    // Apply slight atmospheric air damping
    velocity.scale(math.max(0.0, 1.0 - 0.06 * dt));

    // Integrate position
    position.add(velocity * dt);

    // Ground collision
    final minY = groundY + radius;
    if (position.y <= minY) {
      position.y = minY;
      if (velocity.y < 0) {
        velocity.y = -velocity.y * restitution;
        if (velocity.y.abs() < 0.25) {
          velocity.y = 0.0;
        }
      }
      // Ground friction
      final frictionDamp = math.max(0.0, 1.0 - groundFriction * dt);
      velocity.x *= frictionDamp;
      velocity.z *= frictionDamp;
    }

    // Rolling rotation: roll along movement vector
    final horizontalSpeed = math.sqrt(
      velocity.x * velocity.x + velocity.z * velocity.z,
    );
    if (horizontalSpeed > 0.01) {
      final rollAngle = (horizontalSpeed / radius) * dt;
      // Axis of rotation is perpendicular to horizontal velocity in the XZ plane: (-vz, 0, vx)
      final rollAxis = vm.Vector3(
        -velocity.z / horizontalSpeed,
        0.0,
        velocity.x / horizontalSpeed,
      );
      final deltaRotation = vm.Quaternion.axisAngle(rollAxis, rollAngle);
      rotation = (deltaRotation * rotation)..normalize();
    }

    // Island rim boundary collision (elastic inward bounce)
    final distFromOrigin = math.sqrt(
      position.x * position.x + position.z * position.z,
    );
    final maxDist = islandRimRadius - radius;
    if (distFromOrigin > maxDist && distFromOrigin > 1e-6) {
      final nx = position.x / distFromOrigin;
      final nz = position.z / distFromOrigin;
      position.x = nx * maxDist;
      position.z = nz * maxDist;

      final normalDotVel = velocity.x * nx + velocity.z * nz;
      if (normalDotVel > 0) {
        final impulse = (1.0 + restitution) * normalDotVel;
        velocity.x -= impulse * nx;
        velocity.z -= impulse * nz;
      }
    }

    // Obstacle collisions
    for (final obstacle in obstacles) {
      final dx = position.x - obstacle.x;
      final dz = position.z - obstacle.z;
      final dist = math.sqrt(dx * dx + dz * dz);
      final minDist = obstacle.radius + radius;
      if (dist < minDist && dist > 1e-6) {
        final nx = dx / dist;
        final nz = dz / dist;
        // Separate
        position.x = obstacle.x + nx * minDist;
        position.z = obstacle.z + nz * minDist;

        // Reflect velocity
        final normalDotVel = velocity.x * nx + velocity.z * nz;
        if (normalDotVel < 0) {
          final impulse = (1.0 + restitution) * normalDotVel;
          velocity.x -= impulse * nx;
          velocity.z -= impulse * nz;
        }
      }
    }
  }
}

/// Manages multiple physics balls, obstacle collisions, ball-to-ball collisions,
/// and character interactions (kicking and punching).
class BallPhysicsWorld {
  BallPhysicsWorld({
    this.islandRimRadius = 3.3,
    this.groundY = 0.0,
    List<IslandObstacle>? obstacles,
  }) : obstacles = obstacles ?? IslandObstacle.defaultObstacles();

  final double islandRimRadius;
  final double groundY;
  final List<IslandObstacle> obstacles;
  final List<PhysicsBall> balls = <PhysicsBall>[];

  static const List<List<double>> ballPalettes = <List<double>>[
    <double>[1.0, 0.82, 0.12, 1.0], // Electric Gold
    <double>[0.95, 0.25, 0.22, 1.0], // Coral Red
    <double>[0.12, 0.85, 0.95, 1.0], // Neon Cyan
    <double>[0.72, 0.25, 0.95, 1.0], // Violet Amethyst
    <double>[0.20, 0.88, 0.42, 1.0], // Emerald Green
    <double>[0.95, 0.18, 0.65, 1.0], // Magenta Ruby
    <double>[1.0, 0.48, 0.12, 1.0], // Sunset Orange
    <double>[0.92, 0.96, 1.0, 1.0], // Pearl Frost
  ];

  static final List<vm.Vector3> spawnPositions = <vm.Vector3>[
    vm.Vector3(0.85, 0.6, 0.7),
    vm.Vector3(-0.95, 0.8, 0.65),
    vm.Vector3(1.2, 0.5, -0.9),
    vm.Vector3(-1.1, 0.7, -0.85),
    vm.Vector3(0.2, 0.9, 1.7),
    vm.Vector3(-0.35, 0.5, -1.75),
    vm.Vector3(1.75, 0.7, 0.2),
    vm.Vector3(-1.75, 0.4, 0.15),
  ];

  /// Configures the world with [count] balls (e.g. 1 in Normal mode, 8 in Ultra mode).
  void setupBalls(int count) {
    balls.clear();
    final clampedCount = count.clamp(1, spawnPositions.length);
    for (var i = 0; i < clampedCount; i++) {
      final color = ballPalettes[i % ballPalettes.length];
      final pos = spawnPositions[i].clone();
      // Initial playful upward pop and slight lateral drift
      final vel = vm.Vector3(
        math.sin(i * 1.3) * 0.8,
        1.5 + (i % 3) * 0.6,
        math.cos(i * 1.3) * 0.8,
      );
      balls.add(
        PhysicsBall(
          position: pos,
          velocity: vel,
          radius: 0.32,
          restitution: 0.75,
          groundY: groundY,
          colorLinearRgba: color,
        ),
      );
    }
  }

  /// Steps physics for all balls and resolves inter-ball collisions.
  void update(double deltaSeconds) {
    if (deltaSeconds <= 0) {
      return;
    }

    // Step individual balls
    for (final ball in balls) {
      ball.step(
        deltaSeconds: deltaSeconds,
        islandRimRadius: islandRimRadius,
        obstacles: obstacles,
      );
    }

    // Resolve ball-to-ball collisions if multiple balls exist
    if (balls.length > 1) {
      _resolveBallCollisions();
    }
  }

  void _resolveBallCollisions() {
    for (var i = 0; i < balls.length; i++) {
      for (var j = i + 1; j < balls.length; j++) {
        final b1 = balls[i];
        final b2 = balls[j];

        final dx = b2.position.x - b1.position.x;
        final dy = b2.position.y - b1.position.y;
        final dz = b2.position.z - b1.position.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        final minDist = b1.radius + b2.radius;

        if (dist < minDist && dist > 1e-6) {
          final nx = dx / dist;
          final ny = dy / dist;
          final nz = dz / dist;
          final overlap = minDist - dist;

          // Push apart equally
          final halfOverlap = overlap * 0.5;
          b1.position.x -= nx * halfOverlap;
          b1.position.y -= ny * halfOverlap;
          b1.position.z -= nz * halfOverlap;

          b2.position.x += nx * halfOverlap;
          b2.position.y += ny * halfOverlap;
          b2.position.z += nz * halfOverlap;

          // Relative velocity
          final rvx = b2.velocity.x - b1.velocity.x;
          final rvy = b2.velocity.y - b1.velocity.y;
          final rvz = b2.velocity.z - b1.velocity.z;

          final velAlongNormal = rvx * nx + rvy * ny + rvz * nz;
          if (velAlongNormal < 0) {
            final e = math.min(b1.restitution, b2.restitution);
            final impulseMag = -(1.0 + e) * velAlongNormal * 0.5;
            b1.velocity.x -= nx * impulseMag;
            b1.velocity.y -= ny * impulseMag;
            b1.velocity.z -= nz * impulseMag;

            b2.velocity.x += nx * impulseMag;
            b2.velocity.y += ny * impulseMag;
            b2.velocity.z += nz * impulseMag;
          }
        }
      }
    }
  }

  /// Interacts when the character walks into a ball (dribbling/kicking).
  void handleCharacterKick({
    required vm.Vector3 characterPosition,
    required double characterRadius,
    required double characterSpeed,
  }) {
    for (final ball in balls) {
      final dx = ball.position.x - characterPosition.x;
      final dz = ball.position.z - characterPosition.z;
      final dist = math.sqrt(dx * dx + dz * dz);
      final minDist = characterRadius + ball.radius;

      if (dist < minDist && dist > 1e-6) {
        final nx = dx / dist;
        final nz = dz / dist;

        // Push ball out of character hull
        ball.position.x = characterPosition.x + nx * minDist;
        ball.position.z = characterPosition.z + nz * minDist;

        // Give kick velocity
        final kickSpeed = math.max(characterSpeed * 2.2, 2.6);
        ball.velocity.x = nx * kickSpeed;
        ball.velocity.z = nz * kickSpeed;
        ball.velocity.y = math.max(ball.velocity.y, 1.4);
      }
    }
  }

  /// Launches any ball in front of the character when punched.
  ///
  /// Returns the number of balls hit.
  int handleCharacterPunch({
    required vm.Vector3 characterPosition,
    required double characterYaw,
    double punchRange = 1.7,
  }) {
    // Character facing forward direction in XZ plane
    final forwardX = math.sin(characterYaw);
    final forwardZ = math.cos(characterYaw);

    var hits = 0;
    for (final ball in balls) {
      final dx = ball.position.x - characterPosition.x;
      final dz = ball.position.z - characterPosition.z;
      final dist = math.sqrt(dx * dx + dz * dz);

      if (dist <= punchRange) {
        final toBallX = dist > 1e-6 ? dx / dist : forwardX;
        final toBallZ = dist > 1e-6 ? dz / dist : forwardZ;

        final dot = forwardX * toBallX + forwardZ * toBallZ;
        // Within ~75 degree cone in front of the character
        if (dot > 0.25) {
          // Launch forward and upward!
          final launchX = forwardX * 0.75 + toBallX * 0.25;
          final launchZ = forwardZ * 0.75 + toBallZ * 0.25;
          final launchNorm = math.sqrt(launchX * launchX + launchZ * launchZ);
          final normX = launchNorm > 1e-6 ? launchX / launchNorm : forwardX;
          final normZ = launchNorm > 1e-6 ? launchZ / launchNorm : forwardZ;

          ball.velocity = vm.Vector3(normX * 8.5, 4.8, normZ * 8.5);
          hits++;
        }
      }
    }
    return hits;
  }
}

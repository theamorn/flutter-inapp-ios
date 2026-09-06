import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/tabs/scene/ball_physics.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('PhysicsBall', () {
    test('falls under gravity and bounces off the ground', () {
      final ball = PhysicsBall(
        position: vm.Vector3(0, 1.0, 0),
        radius: 0.3,
        restitution: 0.7,
        groundY: 0.0,
      );

      // Step physics
      ball.step(
        deltaSeconds: 0.05,
        islandRimRadius: 3.0,
        obstacles: const <IslandObstacle>[],
      );

      expect(ball.position.y, lessThan(1.0));
      expect(ball.velocity.y, lessThan(0.0));

      // Step until it hits the ground
      for (var i = 0; i < 20; i++) {
        ball.step(
          deltaSeconds: 0.05,
          islandRimRadius: 3.0,
          obstacles: const <IslandObstacle>[],
        );
      }

      // Should be resting or bouncing at or above groundY + radius
      expect(ball.position.y, greaterThanOrEqualTo(0.3 - 1e-4));
    });

    test('ground friction dampens horizontal velocity over time', () {
      final ball = PhysicsBall(
        position: vm.Vector3(0, 0.3, 0),
        velocity: vm.Vector3(5.0, 0, 0),
        radius: 0.3,
        restitution: 0.5,
        groundFriction: 2.0,
        groundY: 0.0,
      );

      final initialSpeed = ball.velocity.x;
      for (var i = 0; i < 10; i++) {
        ball.step(
          deltaSeconds: 0.05,
          islandRimRadius: 3.0,
          obstacles: const <IslandObstacle>[],
        );
      }

      expect(ball.velocity.x, lessThan(initialSpeed));
    });

    test('rolling rotation changes when ball moves horizontally', () {
      final ball = PhysicsBall(
        position: vm.Vector3(0, 0.3, 0),
        velocity: vm.Vector3(3.0, 0, 0),
        radius: 0.3,
        groundY: 0.0,
      );

      final initialRot = ball.rotation.clone();
      ball.step(
        deltaSeconds: 0.05,
        islandRimRadius: 3.0,
        obstacles: const <IslandObstacle>[],
      );

      expect(ball.rotation, isNot(equals(initialRot)));
    });

    test('bounces off obstacle', () {
      final obstacle = const IslandObstacle(
        name: 'tree',
        x: 1.0,
        z: 0.0,
        radius: 0.5,
      );
      final ball = PhysicsBall(
        position: vm.Vector3(0.3, 0.3, 0),
        velocity: vm.Vector3(4.0, 0, 0),
        radius: 0.3,
        groundY: 0.0,
      );

      // Steps into obstacle (minDist = 0.5 + 0.3 = 0.8)
      ball.step(
        deltaSeconds: 0.05,
        islandRimRadius: 3.0,
        obstacles: <IslandObstacle>[obstacle],
      );

      // Ball should have reversed horizontal velocity
      expect(ball.velocity.x, lessThan(0.0));
      // And position should be pushed out
      expect(ball.position.x, lessThanOrEqualTo(1.0 - 0.8 + 1e-4));
    });

    test('bounces off island boundary rim', () {
      final ball = PhysicsBall(
        position: vm.Vector3(2.8, 0.3, 0),
        velocity: vm.Vector3(5.0, 0, 0),
        radius: 0.3,
        groundY: 0.0,
      );

      ball.step(
        deltaSeconds: 0.05,
        islandRimRadius: 3.0,
        obstacles: const <IslandObstacle>[],
      );

      // Must be kept inside rim (3.0 - 0.3 = 2.7)
      expect(ball.position.x, lessThanOrEqualTo(2.7 + 1e-4));
      // Rebounds inward
      expect(ball.velocity.x, lessThan(0.0));
    });
  });

  group('BallPhysicsWorld', () {
    test('setupBalls creates requested number of balls with valid positions', () {
      final world = BallPhysicsWorld();
      world.setupBalls(1);
      expect(world.balls.length, equals(1));

      world.setupBalls(8);
      expect(world.balls.length, equals(8));

      for (final b in world.balls) {
        final dist = math.sqrt(b.position.x * b.position.x + b.position.z * b.position.z);
        expect(dist, lessThan(world.islandRimRadius));
      }
    });

    test('resolves ball-to-ball collisions elastically', () {
      final world = BallPhysicsWorld(obstacles: const <IslandObstacle>[]);
      world.balls.clear();

      final b1 = PhysicsBall(
        position: vm.Vector3(-0.5, 0.3, 0),
        velocity: vm.Vector3(2.0, 0, 0),
        radius: 0.3,
        restitution: 0.8,
        groundFriction: 0.0,
      );
      final b2 = PhysicsBall(
        position: vm.Vector3(0.0, 0.3, 0),
        velocity: vm.Vector3(-2.0, 0, 0),
        radius: 0.3,
        restitution: 0.8,
        groundFriction: 0.0,
      );
      world.balls.addAll([b1, b2]);

      world.update(0.05);

      // Velocities should reverse
      expect(b1.velocity.x, lessThan(0.0));
      expect(b2.velocity.x, greaterThan(0.0));
    });

    test('handleCharacterKick pushes ball away and imparts speed', () {
      final world = BallPhysicsWorld(obstacles: const <IslandObstacle>[]);
      world.balls.clear();

      final ball = PhysicsBall(
        position: vm.Vector3(0.4, 0.3, 0.0),
        velocity: vm.Vector3.zero(),
        radius: 0.3,
      );
      world.balls.add(ball);

      world.handleCharacterKick(
        characterPosition: vm.Vector3.zero(),
        characterRadius: 0.4,
        characterSpeed: 2.0,
      );

      expect(ball.velocity.x, greaterThan(2.0));
      expect(ball.position.x, greaterThanOrEqualTo(0.7 - 1e-4));
    });

    test('handleCharacterPunch launches ball forward and up within cone', () {
      final world = BallPhysicsWorld();
      world.balls.clear();

      // Ball right in front of character (character yaw = 0 points along +Z)
      final ballInFront = PhysicsBall(
        position: vm.Vector3(0.0, 0.3, 1.0),
        velocity: vm.Vector3.zero(),
        radius: 0.3,
      );
      // Ball behind character
      final ballBehind = PhysicsBall(
        position: vm.Vector3(0.0, 0.3, -1.0),
        velocity: vm.Vector3.zero(),
        radius: 0.3,
      );
      world.balls.addAll([ballInFront, ballBehind]);

      final hits = world.handleCharacterPunch(
        characterPosition: vm.Vector3.zero(),
        characterYaw: 0.0, // facing +Z
      );

      expect(hits, equals(1));
      expect(ballInFront.velocity.z, greaterThan(5.0));
      expect(ballInFront.velocity.y, greaterThan(3.0));
      expect(ballBehind.velocity.z, equals(0.0));
    });
  });
}

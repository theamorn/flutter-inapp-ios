import 'package:flutter_module/tabs/promo/lanyard_physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

const _frame = 1 / 60;

LanyardWorld _world() => LanyardWorld(width: 360, height: 340);

/// Steps [world] at display rate, collecting impacts and checking [eachFrame].
List<Impact> _run(
  LanyardWorld world,
  double seconds, {
  void Function()? eachFrame,
}) {
  final impacts = <Impact>[];
  final frames = (seconds / _frame).round();
  for (var i = 0; i < frames; i++) {
    impacts.addAll(world.step(_frame));
    eachFrame?.call();
  }
  return impacts;
}

/// Grabs the card at its center and drags it at [velocity] for a few frames
/// before letting go, the way a finger flick would.
List<Impact> _fling(LanyardWorld world, vm.Vector2 velocity, {int frames = 6}) {
  final impacts = <Impact>[];
  final finger = world.pose.center.clone();
  expect(world.grab(finger), isTrue);
  for (var i = 0; i < frames; i++) {
    finger.add(velocity * _frame);
    world.dragTo(finger);
    impacts.addAll(world.step(_frame));
  }
  world.release();
  return impacts;
}

void _expectFinite(LanyardWorld world) {
  for (final point in [...world.ropePoints, ...world.pose.corners]) {
    expect(point.x.isFinite && point.y.isFinite, isTrue, reason: '$point');
  }
}

void main() {
  group('LanyardWorld', () {
    test('starts hanging straight below the anchor', () {
      final world = _world();

      expect(world.anchor.x, 180);
      expect(world.pose.hole.x, closeTo(world.anchor.x, 1e-6));
      expect(
        world.pose.hole.y,
        closeTo(world.anchor.y + world.config.ropeLength, 1e-6),
      );
      expect(world.pose.angle, closeTo(0, 1e-6));
    });

    test('does not report impacts while hanging at rest', () {
      final world = _world();

      expect(_run(world, 2), isEmpty);
    });

    test('settles upright below the anchor after a throw', () {
      final world = _world();

      _fling(world, vm.Vector2(1500, -300));
      _run(world, 12);

      expect(world.pose.hole.x, closeTo(world.anchor.x, 1.0));
      expect(world.pose.angle, closeTo(0, 0.02));
      expect(world.cardVelocity.length, lessThan(5));
    });

    test('keeps the rope near its rest length through a hard throw', () {
      final world = _world();
      final rest = world.config.ropeLength;

      _fling(world, vm.Vector2(5000, -1500));
      _run(
        world,
        3,
        eachFrame: () => expect(world.ropeLength, lessThan(rest * 1.05)),
      );

      expect(world.ropeLength, closeTo(rest, rest * 0.02));
    });

    test('keeps every card corner inside the tile', () {
      final world = _world();

      void expectInside() {
        for (final corner in world.pose.corners) {
          expect(corner.x, inInclusiveRange(-0.5, world.width + 0.5));
          expect(corner.y, inInclusiveRange(-0.5, world.height + 0.5));
        }
      }

      _fling(world, vm.Vector2(5000, 2000));
      expectInside();
      _run(world, 3, eachFrame: expectInside);
    });

    test('reports an impact when the card slams into a wall', () {
      // A narrow tile, so a sideways throw reaches the wall before the strap
      // runs out and swings the card upward instead.
      final world = LanyardWorld(width: 260, height: 340);

      final impacts = [
        ..._fling(world, vm.Vector2(3000, 0), frames: 3),
        ..._run(world, 1),
      ];

      expect(impacts, isNotEmpty);
      expect(impacts.first.speed, greaterThan(world.config.impactSpeed));
      expect(impacts.first.position.x, closeTo(world.width, 1));
    });

    test('holds the grabbed point of the card under the finger', () {
      final world = _world();
      final finger = world.pose.center + vm.Vector2(30, 10);
      expect(world.grab(finger), isTrue);
      final local = world.pose.toLocal(finger);

      finger.add(vm.Vector2(40, -20));
      world.dragTo(finger);
      _run(world, 0.1);

      expect(world.isGrabbed, isTrue);
      expect(world.pose.toWorld(local).distanceTo(finger), lessThan(1));
    });

    test('keeps moving in the throw direction after release', () {
      // Wide enough that the card cannot reach a wall: this is about momentum
      // surviving the release, not about bouncing.
      final world = LanyardWorld(width: 800, height: 340);

      _fling(world, vm.Vector2(1200, 0), frames: 4);
      final before = world.pose.center.x;
      world.step(_frame);

      expect(world.isGrabbed, isFalse);
      expect(world.cardVelocity.x, greaterThan(0));
      expect(world.pose.center.x, greaterThan(before));
    });

    test('ignores grabs that miss the card', () {
      final world = _world();

      expect(world.grab(vm.Vector2(5, 330)), isFalse);
      expect(world.isGrabbed, isFalse);
    });

    test('an upward scroll jolt lifts the card', () {
      final world = _world();
      final restY = world.pose.hole.y;

      for (var i = 0; i < 4; i++) {
        world.step(_frame, externalAcceleration: vm.Vector2(0, -6000));
      }

      expect(world.pose.hole.y, lessThan(restY - 1));
    });

    test('survives a huge frame and a scroll jolt without NaN', () {
      final world = _world();

      world.step(0.5, externalAcceleration: vm.Vector2(0, 6000));
      world.step(0.5, externalAcceleration: vm.Vector2(0, -6000));
      _fling(world, vm.Vector2(9000, 9000));
      world.step(0.5);

      _expectFinite(world);
    });

    test('resize re-centers the anchor and carries the badge along', () {
      final world = _world();

      world.resize(460, 340);

      expect(world.anchor.x, 230);
      expect(world.pose.hole.x, closeTo(230, 1e-6));
      expect(_run(world, 1), isEmpty);
    });

    test('bounds cover every card corner', () {
      final world = _world();
      _fling(world, vm.Vector2(800, 400));

      final bounds = world.cardBounds;
      for (final corner in world.pose.corners) {
        expect(corner.x, inInclusiveRange(bounds.min.x, bounds.max.x));
        expect(corner.y, inInclusiveRange(bounds.min.y, bounds.max.y));
      }
    });
  });
}

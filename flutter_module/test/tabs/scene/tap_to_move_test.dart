import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/tabs/scene/tap_to_move.dart';
import 'package:vector_math/vector_math.dart' as vm;

vm.Ray _rayFrom(vm.Vector3 origin, vm.Vector3 direction) =>
    vm.Ray.originDirection(origin, direction);

void main() {
  group('intersectGroundPlane', () {
    test('hits the plane in front of the ray', () {
      final hit = intersectGroundPlane(
        _rayFrom(vm.Vector3(2, 5, -3), vm.Vector3(0, -1, 0)),
      );
      expect(hit, isNotNull);
      expect(hit!.x, closeTo(2, 1e-9));
      expect(hit.y, closeTo(0, 1e-9));
      expect(hit.z, closeTo(-3, 1e-9));
    });

    test('honours a non-zero plane height', () {
      final hit = intersectGroundPlane(
        _rayFrom(vm.Vector3(0, 4, 0), vm.Vector3(1, -1, 0)),
        planeY: 2,
      );
      expect(hit!.x, closeTo(2, 1e-9));
      expect(hit.y, closeTo(2, 1e-9));
    });

    test('a tap on the sky misses', () {
      expect(
        intersectGroundPlane(
          _rayFrom(vm.Vector3(0, 5, 0), vm.Vector3(0, 1, 0)),
        ),
        isNull,
      );
    });

    test('a ray parallel to the ground misses', () {
      expect(
        intersectGroundPlane(
          _rayFrom(vm.Vector3(0, 5, 0), vm.Vector3(1, 0, 0)),
        ),
        isNull,
      );
    });
  });

  group('clampToIsland', () {
    test('leaves interior points alone', () {
      final p = clampToIsland(vm.Vector3(1, 0, 1), radius: 3);
      expect(p.x, closeTo(1, 1e-9));
      expect(p.z, closeTo(1, 1e-9));
    });

    test('pulls exterior points back to the rim', () {
      final p = clampToIsland(vm.Vector3(30, 0, 40), radius: 3);
      // vector_math stores Vector3 in a Float32List, so every tolerance here
      // is float32-sized, not float64-sized.
      expect(math.sqrt(p.x * p.x + p.z * p.z), closeTo(3, 1e-5));
      // Direction is preserved.
      expect(p.x / p.z, closeTo(30 / 40, 1e-5));
    });

    test('keeps the walker out of the sea from any bearing', () {
      for (var i = 0; i < 16; i++) {
        final angle = i / 16 * 2 * math.pi;
        final far = vm.Vector3(math.cos(angle) * 50, 0, math.sin(angle) * 50);
        final p = clampToIsland(far, radius: 3);
        expect(math.sqrt(p.x * p.x + p.z * p.z), lessThanOrEqualTo(3 + 1e-5));
      }
    });
  });

  group('shortestAngleDelta', () {
    test('takes the short way round', () {
      expect(shortestAngleDelta(0.1, -0.1), closeTo(-0.2, 1e-9));
      expect(
        shortestAngleDelta(3.0, -3.0),
        closeTo(-6.0 + 2 * math.pi, 1e-9),
      );
      expect(shortestAngleDelta(0, math.pi / 2), closeTo(math.pi / 2, 1e-9));
    });

    test('never exceeds half a turn', () {
      for (var i = 0; i < 64; i++) {
        final from = i * 0.31;
        final to = -i * 0.77;
        expect(shortestAngleDelta(from, to).abs(), lessThanOrEqualTo(math.pi));
      }
    });
  });

  group('WalkerMotion', () {
    test('starts still', () {
      expect(WalkerMotion().isMoving, isFalse);
    });

    test('walks to the target and stops there', () {
      final walker = WalkerMotion(speed: 2, turnRate: 100);
      walker.moveTo(vm.Vector3(0, 0, 4));
      expect(walker.isMoving, isTrue);
      for (var i = 0; i < 400; i++) {
        walker.advance(1 / 60);
      }
      expect(walker.isMoving, isFalse);
      expect(walker.position.z, closeTo(4, 1e-6));
      expect(walker.position.x, closeTo(0, 1e-6));
    });

    test('faces the direction of travel', () {
      final walker = WalkerMotion(speed: 2, turnRate: 100);
      walker.moveTo(vm.Vector3(3, 0, 0));
      for (var i = 0; i < 30; i++) {
        walker.advance(1 / 60);
      }
      // atan2(dx, dz) with dz == 0 and dx > 0 is +pi/2.
      expect(walker.yaw, closeTo(math.pi / 2, 1e-3));
    });

    test('turns gradually rather than snapping', () {
      final walker = WalkerMotion(speed: 2, turnRate: 1.0);
      walker.moveTo(vm.Vector3(3, 0, 0));
      walker.advance(0.1);
      expect(walker.yaw, closeTo(0.1, 1e-9));
    });

    test('a long stall does not teleport it', () {
      final walker = WalkerMotion(speed: 2, turnRate: 100);
      walker.moveTo(vm.Vector3(0, 0, 100));
      // 30 seconds of frozen render loop arriving as a single delta.
      walker.advance(30);
      expect(walker.position.z, lessThanOrEqualTo(2 * 0.1 + 1e-5));
    });

    test('ignores a tap on its own feet', () {
      final walker = WalkerMotion(position: vm.Vector3(1, 0, 1));
      walker.moveTo(vm.Vector3(1.01, 0, 1.0));
      expect(walker.isMoving, isFalse);
    });

    test('never leaves the ground plane when walking', () {
      final walker = WalkerMotion(position: vm.Vector3(0, 0, 0), speed: 3);
      walker.moveTo(vm.Vector3(2, 9, 2));
      for (var i = 0; i < 200; i++) {
        walker.advance(1 / 60);
      }
      expect(walker.position.y, closeTo(0, 1e-9));
    });

    test('jumps in a ballistic arc and lands back on the ground', () {
      final walker = WalkerMotion(position: vm.Vector3(0, 0, 0));
      expect(walker.isJumping, isFalse);
      final jumped = walker.jump();
      expect(jumped, isTrue);
      expect(walker.isJumping, isTrue);

      // Mid-air
      walker.advance(0.15);
      expect(walker.position.y, greaterThan(0.3));
      expect(walker.isJumping, isTrue);

      // Cannot double-jump while airborne
      expect(walker.jump(), isFalse);

      // Land after arc completes
      for (var i = 0; i < 80; i++) {
        walker.advance(1 / 60);
      }
      expect(walker.position.y, closeTo(0, 1e-9));
      expect(walker.isJumping, isFalse);
    });
  });

  group('unprojection round-trip', () {
    // The trap this guards: an error that GROWS TOWARD THE SCREEN EDGES, from
    // a device-pixel-ratio or widget-versus-screen coordinate mistake. Tapping
    // only the centre would pass with a wrong scale factor; the corners will
    // not. `screenPointToRay` works in the view's logical pixels, so the ray
    // and `worldToScreen` must agree at every corner of every aspect ratio.
    const sizes = <Size>[
      Size(393, 852), // iPhone 17 Pro, portrait
      Size(852, 393), // landscape
      Size(1024, 1366), // iPad
    ];

    for (final size in sizes) {
      test('agrees at the corners of ${size.width}x${size.height}', () {
        final camera = PerspectiveCamera(
          fovRadiansY: 45 * vm.degrees2Radians,
          position: vm.Vector3(6, 5, -7),
          target: vm.Vector3(0, 0.4, 0),
        );
        final probes = <Offset>[
          Offset(size.width / 2, size.height / 2),
          const Offset(1, 1),
          Offset(size.width - 1, 1),
          Offset(1, size.height - 1),
          Offset(size.width - 1, size.height - 1),
          Offset(size.width * 0.16, size.height * 0.4),
          Offset(size.width * 0.84, size.height * 0.72),
        ];
        for (final probe in probes) {
          final ray = camera.screenPointToRay(probe, size);
          final hit = intersectGroundPlane(ray);
          if (hit == null) {
            // Above the horizon: nothing to check, but it must not be a
            // silent miss at a point that should have hit the ground.
            continue;
          }
          final back = camera.worldToScreen(hit, size);
          expect(back, isNotNull, reason: 'no projection for $probe');
          // A device-pixel-ratio or widget-versus-screen mistake shows up
          // here as an error of tens or hundreds of pixels, growing toward the
          // edges. A twentieth of a pixel is float32 noise from the matrix
          // inverse and nothing else.
          expect(back!.dx, closeTo(probe.dx, 0.05), reason: 'x at $probe');
          expect(back.dy, closeTo(probe.dy, 0.05), reason: 'y at $probe');
        }
      });
    }

    test('a tap below the horizon always lands on the island', () {
      const size = Size(393, 852);
      final camera = PerspectiveCamera(
        fovRadiansY: 45 * vm.degrees2Radians,
        position: vm.Vector3(6, 5, -7),
        target: vm.Vector3(0, 0.4, 0),
      );
      for (var x = 0; x <= 10; x++) {
        for (var y = 5; y <= 10; y++) {
          final probe = Offset(
            size.width * x / 10,
            size.height * y / 10,
          );
          final picked = pickIslandPoint(
            camera.screenPointToRay(probe, size),
            radius: 3,
          );
          expect(picked, isNotNull, reason: 'missed at $probe');
          final r = math.sqrt(
            picked!.x * picked.x + picked.z * picked.z,
          );
          expect(r, lessThanOrEqualTo(3 + 1e-5));
        }
      }
    });
  });

  group('OtsCameraRig', () {
    const rig = OtsCameraRig(
      followDistance: 2.0,
      camHeight: 1.5,
      shoulderOffset: 0.5,
      targetHeight: 1.0,
      lookAheadDistance: 4.0,
      minGroundClearance: 0.5,
    );

    test('computes eye behind and over right shoulder when yaw is 0', () {
      final (eye, target) = rig.compute(
        characterPosition: vm.Vector3(0, 0, 0),
        yaw: 0.0,
      );

      // With yaw=0, forward=(0,0,1), right=(1,0,0)
      // Eye: -forward*2 + right*0.5 + up*1.5 = (0.5, 1.5, -2.0)
      expect(eye.x, closeTo(0.5, 1e-5));
      expect(eye.y, closeTo(1.5, 1e-5));
      expect(eye.z, closeTo(-2.0, 1e-5));

      // Target: forward*4 + up*1.0 + right*(0.5*0.25)
      expect(target.x, closeTo(0.125, 1e-5));
      expect(target.y, closeTo(1.0, 1e-5));
      expect(target.z, closeTo(4.0, 1e-5));
    });

    test('tracks character turning to the right (yaw = pi/2)', () {
      final (eye, target) = rig.compute(
        characterPosition: vm.Vector3(1, 0, 1),
        yaw: math.pi / 2,
      );

      // yaw=pi/2, forward=(1,0,0), right=(0,0,-1)
      // Eye: pos + (-forward*2 + right*0.5 + up*1.5) = (1-2, 1.5, 1-0.5) = (-1.0, 1.5, 0.5)
      expect(eye.x, closeTo(-1.0, 1e-5));
      expect(eye.y, closeTo(1.5, 1e-5));
      expect(eye.z, closeTo(0.5, 1e-5));

      // Target: pos + (forward*4 + up*1.0 + right*(0.5*0.25)) = (1+4, 1.0, 1-0.125)
      expect(target.x, closeTo(5.0, 1e-5));
      expect(target.y, closeTo(1.0, 1e-5));
      expect(target.z, closeTo(0.875, 1e-5));
    });

    test('respects min ground clearance floor', () {
      final (eye, _) = rig.compute(
        characterPosition: vm.Vector3(0, -2.0, 0),
        yaw: 0.0,
        groundY: 0.0,
      );
      // Even if char is down at -2.0, eye.y never dips below groundY + minGroundClearance (0.5)
      expect(eye.y, greaterThanOrEqualTo(0.5));
    });

    test('default constructor provides tight RE4-style camera framing', () {
      const defaultRig = OtsCameraRig();
      expect(defaultRig.followDistance, closeTo(2.0, 1e-5));
      expect(defaultRig.shoulderOffset, closeTo(0.25, 1e-5));
      expect(defaultRig.camHeight, closeTo(1.15, 1e-5));
      expect(defaultRig.lookAheadDistance, closeTo(4.0, 1e-5));

      final (eye, target) = defaultRig.compute(
        characterPosition: vm.Vector3.zero(),
        yaw: 0.0,
      );
      // Eye: behind right shoulder (2.0m back, 0.25m right, 1.15m high)
      expect(eye.x, closeTo(0.25, 1e-5));
      expect(eye.y, closeTo(1.15, 1e-5));
      expect(eye.z, closeTo(-2.0, 1e-5));

      // Target: looking forward ahead along +Z at 4.0m distance
      expect(target.x, closeTo(0.0625, 1e-5));
      expect(target.y, closeTo(0.65, 1e-5));
      expect(target.z, closeTo(4.0, 1e-5));
    });
  });

  group('FrustumCuller', () {
    const culler = FrustumCuller();
    // Camera at (0, 1.8, 5.0) looking forward towards (0, 1.0, 0.0)
    final camera = PerspectiveCamera(
      fovRadiansY: 45 * vm.degrees2Radians,
      position: vm.Vector3(0, 1.8, 5.0),
      target: vm.Vector3(0, 1.0, 0.0),
      fovNear: 0.1,
      fovFar: 100.0,
    );
    final frustum = camera.getFrustum(const Size(393, 852));

    test('sphere directly in front of camera is visible', () {
      expect(
        culler.isSphereVisible(frustum, vm.Vector3(0, 1.0, 0.0), 1.0),
        isTrue,
      );
    });

    test('sphere behind camera is culled', () {
      expect(
        culler.isSphereVisible(frustum, vm.Vector3(0, 1.8, 10.0), 1.0),
        isFalse,
      );
    });

    test('sphere far to the side outside FOV is culled', () {
      expect(
        culler.isSphereVisible(frustum, vm.Vector3(25.0, 1.0, 0.0), 1.0),
        isFalse,
      );
    });

    test('sphere overlapping boundary with its radius is preserved (no clipping)', () {
      // Near frustum boundary
      expect(
        culler.isSphereVisible(frustum, vm.Vector3(3.5, 1.0, 0.0), 3.0),
        isTrue,
      );
    });

    test('AABB bounding box in front of camera is visible', () {
      final aabb = vm.Aabb3.minMax(
        vm.Vector3(-0.5, 0.0, -0.5),
        vm.Vector3(0.5, 1.0, 0.5),
      );
      expect(culler.isAabbVisible(frustum, aabb), isTrue);
    });

    test('AABB bounding box behind camera is culled', () {
      final aabb = vm.Aabb3.minMax(
        vm.Vector3(-0.5, 0.0, 12.0),
        vm.Vector3(0.5, 1.0, 15.0),
      );
      expect(culler.isAabbVisible(frustum, aabb), isFalse);
    });
  });

  group('pickWanderTarget', () {
    test('stays on the walkable disc and clear of the campfire', () {
      final random = math.Random(7);
      const walkableRadius = 9.0;
      const avoidRadius = 1.4;
      final avoid = vm.Vector3(0, 0, -0.45);

      for (var i = 0; i < 80; i++) {
        final point = pickWanderTarget(
          random: random,
          walkableRadius: walkableRadius,
          avoid: avoid,
          avoidRadius: avoidRadius,
        );
        final dist = math.sqrt(point.x * point.x + point.z * point.z);
        expect(dist, lessThanOrEqualTo(walkableRadius + 1e-5));
        expect(point.y, closeTo(0, 1e-9));

        final dx = point.x - avoid.x;
        final dz = point.z - avoid.z;
        expect(math.sqrt(dx * dx + dz * dz), greaterThanOrEqualTo(avoidRadius));
      }
    });

    test('falls back to a rim point when the avoid disc covers everything', () {
      final point = pickWanderTarget(
        random: math.Random(1),
        walkableRadius: 1.0,
        avoid: vm.Vector3.zero(),
        avoidRadius: 4.0,
        maxAttempts: 3,
      );
      expect(
        math.sqrt(point.x * point.x + point.z * point.z),
        closeTo(1.0, 1e-5),
      );
    });
  });

  group('filterIslandScatterPoints', () {
    test('keeps walkable points and drops the sea, campfire, and occupied discs', () {
      final kept = filterIslandScatterPoints(
        samples: <vm.Vector2>[
          vm.Vector2(9.0, 9.0 + 3.0), // walkable, clear of the campfire
          vm.Vector2(9.0 + 8.5, 9.0), // still on the disc
          vm.Vector2(9.0 + 12.0, 9.0), // sea
          vm.Vector2(9.0, 9.0 - 0.45), // campfire
          vm.Vector2(9.0 + 2.0, 9.0), // on top of an occupied prop
        ],
        rectOrigin: 9.0,
        walkableRadius: 9.0,
        campfire: vm.Vector2(0.0, -0.45),
        campfireAvoidRadius: 1.4,
        occupied: <vm.Vector2>[vm.Vector2(2.0, 0.0)],
        occupiedRadius: 1.2,
        maxCount: 20,
      );

      expect(kept, hasLength(2));
      expect(kept[0].x, closeTo(0.0, 1e-5));
      expect(kept[0].y, closeTo(3.0, 1e-5));
      expect(kept[1].x, closeTo(8.5, 1e-5));
      expect(kept[1].y, closeTo(0.0, 1e-5));
    });

    test('caps the extra scatter so Ultra foliage stays bounded', () {
      final samples = <vm.Vector2>[
        for (var i = 0; i < 40; i++) vm.Vector2(9.0 + i * 0.15, 9.0),
      ];
      final kept = filterIslandScatterPoints(
        samples: samples,
        rectOrigin: 9.0,
        walkableRadius: 9.0,
        campfire: vm.Vector2(0.0, -0.45),
        campfireAvoidRadius: 1.4,
        occupied: const <vm.Vector2>[],
        occupiedRadius: 1.2,
        maxCount: 20,
      );
      expect(kept, hasLength(20));
    });

    test('drops the inner walk disc so ground cover leaves a path', () {
      final kept = filterIslandScatterPoints(
        samples: <vm.Vector2>[
          vm.Vector2(9.0 + 1.0, 9.0), // inside the clear radius
          vm.Vector2(9.0 + 5.0, 9.0), // on the rim ring
        ],
        rectOrigin: 9.0,
        walkableRadius: 9.0,
        campfire: vm.Vector2(0.0, -0.45),
        campfireAvoidRadius: 1.4,
        occupied: const <vm.Vector2>[],
        occupiedRadius: 1.2,
        maxCount: 20,
        innerClearRadius: 3.2,
      );
      expect(kept, hasLength(1));
      expect(kept.single.x, closeTo(5.0, 1e-5));
      expect(kept.single.y, closeTo(0.0, 1e-5));
    });
  });

  group('NpcSteeringMotion', () {
    test('arrives at a far target without leaving the island', () {
      final npc = NpcSteeringMotion(
        position: vm.Vector3(0, 0, 0),
        maxSpeed: 1.4,
        groundY: 0,
      );
      npc.moveTo(vm.Vector3(4, 0, 0));
      for (var i = 0; i < 400; i++) {
        npc.advance(
          1 / 60,
          playerPosition: vm.Vector3(-8, 0, 0),
          walkableRadius: 9.0,
          campfire: vm.Vector3(0, 0, -0.45),
          campfireAvoidRadius: 1.4,
        );
      }
      expect(npc.position.x, closeTo(4, 0.25));
      expect(npc.position.z, closeTo(0, 0.25));
      expect(npc.isMoving, isFalse);
      expect(
        math.sqrt(npc.position.x * npc.position.x + npc.position.z * npc.position.z),
        lessThanOrEqualTo(9.0 + 1e-5),
      );
    });

    test('separates away from the player when they stand too close', () {
      final npc = NpcSteeringMotion(
        position: vm.Vector3(0.2, 0, 0),
        maxSpeed: 1.4,
        groundY: 0,
      );
      final startX = npc.position.x;
      for (var i = 0; i < 45; i++) {
        npc.advance(
          1 / 60,
          playerPosition: vm.Vector3.zero(),
          walkableRadius: 9.0,
          campfire: vm.Vector3(0, 0, -8),
          campfireAvoidRadius: 1.4,
        );
      }
      expect(npc.position.x, greaterThan(startX + 0.15));
    });

    test('is pushed out of the campfire disc', () {
      final npc = NpcSteeringMotion(
        position: vm.Vector3(0.1, 0, -0.45),
        maxSpeed: 1.4,
        groundY: 0,
      );
      npc.advance(
        1 / 60,
        playerPosition: vm.Vector3(8, 0, 8),
        walkableRadius: 9.0,
        campfire: vm.Vector3(0, 0, -0.45),
        campfireAvoidRadius: 1.4,
      );
      final dx = npc.position.x - 0.0;
      final dz = npc.position.z - (-0.45);
      expect(math.sqrt(dx * dx + dz * dz), greaterThanOrEqualTo(1.4 - 1e-4));
    });
  });

  group('DebrisChipMotion', () {
    test('follows a ballistic arc and dies after its lifetime', () {
      final chip = DebrisChipMotion(
        position: vm.Vector3(0, 0.4, 0),
        velocity: vm.Vector3(2.0, 3.0, 0.5),
        lifetime: 1.2,
      );
      chip.advance(0.1, groundY: 0.0);
      expect(chip.position.y, greaterThan(0.4));
      expect(chip.isDead, isFalse);

      for (var i = 0; i < 80; i++) {
        chip.advance(1 / 60, groundY: 0.0);
      }
      expect(chip.position.y, greaterThanOrEqualTo(0.0));
      expect(chip.isDead, isTrue);
    });
  });

  group('FlockBirdMotion', () {
    test('cruises around the island rim instead of collapsing to the origin', () {
      final bird = FlockBirdMotion(
        position: vm.Vector3(12, 5.5, 0),
        velocity: vm.Vector3(0, 0, 6),
        maxSpeed: 7.0,
        orbitRadius: 12.0,
        cruiseHeight: 5.5,
      );
      for (var i = 0; i < 240; i++) {
        bird.advance(
          1 / 60,
          neighborPositions: const <vm.Vector3>[],
          neighborVelocities: const <vm.Vector3>[],
        );
      }
      final radius = math.sqrt(
        bird.position.x * bird.position.x + bird.position.z * bird.position.z,
      );
      expect(radius, inInclusiveRange(9.0, 16.0));
      expect(bird.position.y, inInclusiveRange(3.5, 8.0));
    });

    test('separates from a neighbor that is sitting on top of it', () {
      final bird = FlockBirdMotion(
        position: vm.Vector3(12.0, 5.5, 0.0),
        velocity: vm.Vector3(0, 0, 1),
        maxSpeed: 7.0,
        orbitRadius: 12.0,
        cruiseHeight: 5.5,
      );
      final start = bird.position.clone();
      for (var i = 0; i < 40; i++) {
        bird.advance(
          1 / 60,
          neighborPositions: <vm.Vector3>[vm.Vector3(12.0, 5.5, 0.0)],
          neighborVelocities: <vm.Vector3>[vm.Vector3(0, 0, 1)],
        );
      }
      expect((bird.position - start).length, greaterThan(0.35));
    });
  });
}

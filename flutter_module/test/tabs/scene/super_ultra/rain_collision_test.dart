import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/island_scene.dart';
import 'package:flutter_module/tabs/scene/super_ultra/island_terrain.dart';
import 'package:flutter_module/tabs/scene/super_ultra/rain_collision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final grid = buildRainHeightGrid(IslandDimensions.seaY);
  final collider = RainCollider(
    grid: grid,
    seaLevel: IslandDimensions.seaY,
    props: const <RainProp>[
      RainProp('palm', 6.0, -4.0, 1.0),
      RainProp('pine', -4.6, -5.8, 1.0),
      RainProp('rockLarge', 3.3, 5.9, 1.0),
      RainProp('bush', 4.0, 7.0, 1.0),
    ],
  );
  final none = RainDynamics();

  test('the height grid follows the terrain it was sampled from', () {
    final terrain = IslandTerrain(seaLevel: IslandDimensions.seaY);
    for (final p in <List<double>>[
      <double>[0, 0],
      <double>[5, -7],
      <double>[11.3, 2.2],
      <double>[-13.1, 4.4],
      <double>[20, 20],
    ]) {
      expect(
        grid.heightAt(p[0], p[1]),
        closeTo(terrain.height(p[0], p[1]), 0.12),
        reason: 'at $p',
      );
    }
    expect(grid.heightAt(0, 0), 0.0);
    expect(grid.heightAt(200, 0), IslandTerrain.deepestFloor);
  });

  test('a falling drop is free until it reaches a surface', () {
    expect(collider.test(1.0, 5.0, 1.0, none), isNull);
    expect(collider.test(1.0, 0.02, 1.0, none), isNull);
    final hit = collider.test(1.0, -0.01, 1.0, none);
    expect(hit?.surface, RainSurface.ground);
    expect(hit!.y, 0.0);
  });

  test('drops over the sea land on the water, not the seabed', () {
    expect(collider.test(30.0, IslandDimensions.seaY + 0.02, 0.0, none), isNull);
    final hit = collider.test(30.0, IslandDimensions.seaY - 0.01, 0.0, none);
    expect(hit?.surface, RainSurface.water);
    expect(hit!.y, IslandDimensions.seaY);
  });

  test('props catch rain on their tops', () {
    // Palm canopy, well above the ground.
    final canopy = collider.test(6.0, 1.3, -4.0, none);
    expect(canopy?.surface, RainSurface.prop);
    expect(canopy!.y, closeTo(1.37, 0.01));
    // Pine cone near its tip, and just outside the cone at the same height.
    expect(collider.test(-4.6, 1.0, -5.8, none)?.surface, RainSurface.prop);
    expect(collider.test(-4.4, 1.0, -5.8, none), isNull);
    // Rock dome and bush.
    expect(collider.test(3.3, 0.2, 5.9, none)?.surface, RainSurface.prop);
    expect(collider.test(4.0, 0.2, 7.0, none)?.surface, RainSurface.prop);
    expect(collider.propTop, greaterThan(1.3));
    expect(collider.propTop, lessThan(1.6));
  });

  test('the broadphase finds the same first hit as testing every prop', () {
    // A crowded, overlapping scatter like the real island's. The reference
    // for each point is the first prop, in placement order, whose own
    // single-prop collider catches the drop; failing that, the bare ground.
    const kinds = <String>['palm', 'pine', 'rockLarge', 'rockSmall', 'bush'];
    final random = math.Random(7);
    final props = <RainProp>[
      for (var i = 0; i < 70; i++)
        RainProp(
          kinds[random.nextInt(kinds.length)],
          (random.nextDouble() * 2 - 1) * 12.0,
          (random.nextDouble() * 2 - 1) * 12.0,
          0.6 + random.nextDouble(),
        ),
    ];
    RainCollider single(List<RainProp> props) => RainCollider(
          grid: grid,
          seaLevel: IslandDimensions.seaY,
          props: props,
          fireX: 1000.0,
        );
    final crowded = single(props);
    final alone = <RainCollider>[
      for (final prop in props) single(<RainProp>[prop]),
    ];
    final bare = single(const <RainProp>[]);
    var propHits = 0;
    for (var i = 0; i < 20000; i++) {
      // Half the drops aimed near a prop, half anywhere.
      final near = props[random.nextInt(props.length)];
      final spread = i.isEven ? 0.7 * near.scale : 14.0;
      final x = (i.isEven ? near.x : 0.0) + (random.nextDouble() * 2 - 1) * spread;
      final z = (i.isEven ? near.z : 0.0) + (random.nextDouble() * 2 - 1) * spread;
      final y = -0.3 + random.nextDouble() * 2.3;
      RainHit? expected;
      for (final c in alone) {
        final hit = c.test(x, y, z, none);
        if (hit?.surface == RainSurface.prop) {
          expected = hit;
          break;
        }
      }
      expected ??= bare.test(x, y, z, none);
      final actual = crowded.test(x, y, z, none);
      expect(actual?.surface, expected?.surface, reason: 'at $x, $y, $z');
      expect(actual?.y, expected?.y, reason: 'at $x, $y, $z');
      if (actual?.surface == RainSurface.prop) {
        propHits++;
      }
    }
    // The sample must actually exercise the props.
    expect(propHits, greaterThan(300));
  });

  test('the fire turns rain into steam', () {
    expect(collider.test(0.0, 0.3, -0.45, none)?.surface, RainSurface.fire);
  });

  test('moving things: characters and balls', () {
    final dynamics = RainDynamics()
      ..addCapsule(2.0, 0.0, 2.0, 0.22, 1.0)
      ..addSphere(-2.0, 3.0, 1.0, 0.32);
    expect(collider.test(2.0, 0.9, 2.0, dynamics)?.surface, RainSurface.character);
    expect(collider.test(2.5, 0.9, 2.0, dynamics), isNull);
    final ball = collider.test(-2.0, 3.2, 1.0, dynamics);
    expect(ball?.surface, RainSurface.ball);
    expect(ball!.y, closeTo(3.32, 1e-6));
    dynamics.clear();
    expect(collider.test(2.0, 0.9, 2.0, dynamics), isNull);
  });
}

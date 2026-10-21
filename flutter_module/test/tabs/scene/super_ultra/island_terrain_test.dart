import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/island_scene.dart';
import 'package:flutter_module/tabs/scene/super_ultra/island_terrain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  final terrain = IslandTerrain(seaLevel: IslandDimensions.seaY);

  test('the walkable top is exactly the tap plane', () {
    for (var r = 0.0; r <= terrain.flatRadius; r += 0.25) {
      for (var a = 0.0; a < 2 * math.pi; a += 0.3) {
        expect(
          terrain.height(r * math.cos(a), r * math.sin(a)),
          IslandDimensions.groundY,
        );
      }
    }
    // The flat top covers everything that walks or rolls.
    expect(terrain.flatRadius, greaterThanOrEqualTo(9.9));
    expect(terrain.flatRadius, greaterThan(IslandDimensions.walkableRadius));
  });

  test('the coast meets the sea and the shelf stays under it', () {
    for (var a = 0.0; a < 2 * math.pi; a += 0.2) {
      final shore = terrain.shorelineRadius(a);
      expect(shore, greaterThan(terrain.flatRadius + IslandTerrain.lipWidth));
      final atShore = terrain.height(shore * math.cos(a), shore * math.sin(a));
      expect(atShore, closeTo(IslandDimensions.seaY, 1e-9));
      for (var d = 0.5; d < 120.0; d += 2.5) {
        final r = shore + d;
        final h = terrain.height(r * math.cos(a), r * math.sin(a));
        expect(h, lessThan(IslandDimensions.seaY + 0.05), reason: 'a=$a d=$d');
        expect(h, greaterThanOrEqualTo(IslandTerrain.deepestFloor));
      }
    }
  });

  test('the land descends monotonically from the lip to the waterline', () {
    for (var a = 0.0; a < 2 * math.pi; a += 0.35) {
      final shore = terrain.shorelineRadius(a);
      var previous = 0.0;
      for (var r = terrain.flatRadius; r <= shore; r += 0.05) {
        final h = terrain.height(r * math.cos(a), r * math.sin(a));
        expect(h, lessThanOrEqualTo(previous + 1e-9));
        previous = h;
      }
    }
  });

  test('the trail and clearing are marked, the far lawn is not', () {
    expect(terrain.dirtMask(0.0, -0.45), closeTo(1.0, 1e-9));
    expect(terrain.dirtMask(3.6, -4.3), greaterThan(0.8));
    expect(terrain.dirtMask(-6.0, 5.0), 0.0);
  });

  test('the mesh faces up and is well formed', () {
    final mesh = terrain.buildMesh(segments: 48);
    expect(mesh.indices, isNotNull);
    final indices = mesh.indices!;
    expect(indices.length % 3, 0);
    for (final index in indices) {
      expect(index, inInclusiveRange(0, mesh.vertexCount - 1));
    }
    final p = mesh.positions;
    vm.Vector3 at(int i) => vm.Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
    var up = 0;
    for (var t = 0; t < indices.length; t += 3) {
      final a = at(indices[t]);
      final normal =
          (at(indices[t + 1]) - a).cross(at(indices[t + 2]) - a);
      if (normal.y > 0) {
        up++;
      }
    }
    // Every triangle of a heightfield is front-facing from above.
    expect(up, indices.length ~/ 3);
  });

  test('the sea ring faces up', () {
    final mesh = buildOceanMeshData(segments: 32);
    final indices = mesh.indices!;
    final p = mesh.positions;
    vm.Vector3 at(int i) => vm.Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
    for (var t = 0; t < indices.length; t += 3) {
      final a = at(indices[t]);
      final normal =
          (at(indices[t + 1]) - a).cross(at(indices[t + 2]) - a);
      expect(normal.y, greaterThan(0));
    }
  });

  test('the simple sea bakes the water depth and reaches the far plane', () {
    final mesh = buildSimpleSeaMeshData(terrain, segments: 32);
    final p = mesh.positions;
    final colors = mesh.colors!;
    var farthest = 0.0;
    for (var i = 0; i < mesh.vertexCount; i++) {
      final x = p[i * 3];
      final z = p[i * 3 + 2];
      final depth = colors[i * 4] * kSimpleSeaDepthScale;
      final expected = math.min(
        math.max(IslandDimensions.seaY - terrain.height(x, z), 0.0),
        kSimpleSeaDepthScale,
      );
      expect(depth, closeTo(expected, 1e-4), reason: '($x, $z)');
      farthest = math.max(farthest, math.sqrt(x * x + z * z));
    }
    // Opaque, so it cannot fade into the sky: it runs to the camera's far
    // plane (640 m) instead.
    expect(farthest, greaterThanOrEqualTo(640.0));
    // Dry under the island, deep off the reef.
    expect(colors[0], 0.0);
    expect(colors[(mesh.vertexCount - 1) * 4], greaterThan(0.5));
  });
}

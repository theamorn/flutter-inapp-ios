/// The Super Ultra island as a heightfield: a flat walkable top, a grass lip,
/// a beach (or a rocky headland), a shallow sandy shelf, and a reef drop into
/// deep water.
///
/// Once the sea is clear, the Normal/Ultra landmass (a cylinder cap on an
/// upside-down cone) reads as a floating rock. This replaces it in Super
/// Ultra only. Everything inside [IslandTerrain.flatRadius] is exactly
/// `y = 0`, the plane tap-to-move picks against, so picking is unchanged.
///
/// Pure maths plus [MeshData]; no GPU work happens here, so the mesh can be
/// built on a background isolate and the profile is unit-tested.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_module/tabs/scene/super_ultra/procedural_textures.dart'
    show TileableNoise;
import 'package:flutter_scene/scene.dart' show MeshData;
import 'package:vector_math/vector_math.dart' as vm;

class IslandTerrain {
  IslandTerrain({
    this.seed = 5,
    this.seaLevel = -1.35,
    this.flatRadius = 10.0,
  }) : _noise = TileableNoise(seed);

  final int seed;
  final double seaLevel;

  /// Radius inside which the ground is exactly `y = 0`. Covers the walk
  /// clamp (9.0) and the ball rim (9.9), so neither the character nor a ball
  /// ever stands on a slope.
  final double flatRadius;

  final TileableNoise _noise;

  static const double lipWidth = 0.55;
  static const double outerRadius = 140.0;
  static const double deepestFloor = -15.0;

  /// Campfire clearing and a worn trail down to the beach, in world XZ.
  /// Threads between the Normal-mode props (see `_normalPlacements`).
  static final List<vm.Vector2> trail = <vm.Vector2>[
    vm.Vector2(0.0, -0.45),
    vm.Vector2(1.3, -1.9),
    vm.Vector2(3.6, -4.3),
    vm.Vector2(5.0, -6.6),
    vm.Vector2(6.3, -8.2),
    vm.Vector2(7.6, -9.9),
  ];

  static final vm.Vector2 campfire = vm.Vector2(0.0, -0.45);

  /// -1..1 coastline character at [theta], periodic around the island.
  double _coast(double theta) {
    final u = (theta / (2 * math.pi)) % 1.0;
    return _noise.fbm(u, 0.31, period: 5, octaves: 3) * 1.6;
  }

  /// Distance from the island centre to the waterline at [theta].
  double shorelineRadius(double theta) =>
      (12.0 + 1.3 * _coast(theta)).clamp(flatRadius + lipWidth + 0.6, 14.5);

  /// 0 for a sandy beach, 1 for a rocky headland.
  double rockiness(double theta) => _smoothstep(0.2, 0.55, _coast(theta));

  /// Ground height at world ([x], [z]).
  double height(double x, double z) {
    final r = math.sqrt(x * x + z * z);
    // The epsilon absorbs `sqrt` rounding on the rim ring itself, which would
    // otherwise sit a hair outside the flat top at -1e-30.
    if (r <= flatRadius + 1e-6) {
      return 0.0;
    }
    final theta = math.atan2(z, x);
    final rocky = rockiness(theta);
    final lipDepth = 0.28 + 0.5 * rocky;
    final lipEnd = flatRadius + lipWidth;
    if (r <= lipEnd) {
      return -lipDepth * _smoothstep(flatRadius, lipEnd, r);
    }
    final shore = math.max(shorelineRadius(theta), lipEnd + 0.4);
    if (r <= shore) {
      // Concave beach: steeper under the lip, flattening into the water.
      final t = (r - lipEnd) / (shore - lipEnd);
      final profile = 1.0 - math.pow(1.0 - t, 1.6);
      return -lipDepth + (seaLevel + lipDepth) * profile;
    }
    final d = r - shore;
    final shelf = 2.3 * (1.0 - math.exp(-d / 4.5));
    final drop = 9.0 * _smoothstep(12.0, 38.0, d);
    final u = x / 256.0 + 0.5;
    final v = z / 256.0 + 0.5;
    final bumps =
        0.35 * _noise.fbm(u, v, period: 24, octaves: 3) * _smoothstep(0.0, 4.0, d);
    final boulders = rocky *
        0.75 *
        math.max(0.0, _noise.fbm(u + 0.5, v, period: 48, octaves: 2)) *
        _smoothstep(0.3, 2.5, d) *
        (1.0 - _smoothstep(7.0, 13.0, d));
    return math.max(seaLevel - shelf - drop + bumps + boulders, deepestFloor);
  }

  /// 0..1 exposed rock: rocky headlands from the lip down onto the shelf.
  double rockMask(double x, double z) {
    final r = math.sqrt(x * x + z * z);
    if (r <= flatRadius + 0.05) {
      return 0.0;
    }
    final theta = math.atan2(z, x);
    final shore = shorelineRadius(theta);
    final band = _smoothstep(flatRadius, flatRadius + 0.3, r) *
        (1.0 - _smoothstep(shore + 5.0, shore + 9.0, r));
    return rockiness(theta) * band;
  }

  /// 0..1 worn dirt: the campfire clearing and the trail to the beach.
  double dirtMask(double x, double z) {
    final p = vm.Vector2(x, z);
    final clearing = 1.0 - _smoothstep(1.35, 2.2, (p - campfire).length);
    var nearest = double.infinity;
    for (var i = 0; i < trail.length - 1; i++) {
      final a = trail[i];
      final ab = trail[i + 1] - a;
      final t = ((p - a).dot(ab) / ab.length2).clamp(0.0, 1.0);
      final distance = (p - (a + ab * t)).length;
      if (distance < nearest) {
        nearest = distance;
      }
    }
    final wobble = 0.12 * _noise.fbm(x / 64.0 + 0.5, z / 64.0 + 0.5, period: 12, octaves: 2);
    final path = 1.0 - _smoothstep(0.42, 0.85, nearest + wobble);
    return math.max(clearing, path);
  }

  /// The whole island as a polar grid, one draw. Vertex colour carries
  /// `(rock, dirt, 0, 1)` for `island_ground.fmat`; normals are generated from
  /// the faces by [MeshData.build].
  MeshData buildMesh({int segments = 192}) {
    final radii = terrainRingRadii();
    return _buildPolarGrid(
      radii: radii,
      segments: segments,
      heightAt: height,
      colorAt: (x, z) => (rockMask(x, z), dirtMask(x, z)),
    );
  }
}

/// Ring radii for the terrain: dense where the shape changes (the lip and
/// beach), coarse on the flat top and the deep seabed.
List<double> terrainRingRadii() {
  final radii = <double>[];
  for (var r = 0.35; r < 10.0; r += 0.35) {
    radii.add(r);
  }
  for (var r = 10.0; r < 16.0; r += 0.15) {
    radii.add(r);
  }
  for (var r = 16.0; r < 40.0; r += 0.5) {
    radii.add(r);
  }
  for (var r = 40.0; r < IslandTerrain.outerRadius; r *= 1.08) {
    radii.add(r);
  }
  radii.add(IslandTerrain.outerRadius);
  return radii;
}

/// Ring radii for the sea surface: fine enough near the island to carry the
/// shortest wave, geometric out to the horizon. Starts under the island
/// (hidden by it) so the waterline is always inside the mesh.
List<double> oceanRingRadii({double inner = 9.5, double outer = 320.0}) {
  final radii = <double>[];
  for (var r = inner; r < 40.0; r += 0.45) {
    radii.add(r);
  }
  for (var r = 40.0; r < outer; r *= 1.07) {
    radii.add(r);
  }
  radii.add(outer);
  return radii;
}

/// A flat ring grid for the sea, with authored up normals (the ocean shader
/// replaces them) and uv = world XZ.
MeshData buildOceanMeshData({int segments = 224}) {
  final radii = oceanRingRadii();
  return _withUpNormals(
    _buildPolarGrid(
      radii: radii,
      segments: segments,
      heightAt: (_, _) => 0.0,
      includeCentre: false,
    ),
  );
}

/// How deep the simple sea's vertex colours count: red = water depth /
/// this, so 0..1 spans the shelf and the reef drop.
const double kSimpleSeaDepthScale = 16.0;

/// The sea for the simple (opaque) water: the same rings as
/// [buildOceanMeshData], carried on out to the camera's far plane (it cannot
/// alpha-fade into the sky), with the water depth under each vertex baked
/// into red, since the shader cannot read the scene depth.
MeshData buildSimpleSeaMeshData(IslandTerrain terrain, {int segments = 224}) {
  return _withUpNormals(
    _buildPolarGrid(
      radii: oceanRingRadii(outer: 660.0),
      segments: segments,
      heightAt: (_, _) => 0.0,
      colorAt: (x, z) {
        final depth = math.max(terrain.seaLevel - terrain.height(x, z), 0.0);
        return (math.min(depth / kSimpleSeaDepthScale, 1.0), 0.0);
      },
      includeCentre: false,
    ),
  );
}

MeshData _withUpNormals(MeshData data) {
  final normals = Float32List(data.vertexCount * 3);
  for (var i = 0; i < data.vertexCount; i++) {
    normals[i * 3 + 1] = 1.0;
  }
  return MeshData(
    positions: data.positions,
    vertexCount: data.vertexCount,
    normals: normals,
    texCoords: data.texCoords,
    colors: data.colors,
    indices: data.indices,
  );
}

/// Top-level wrappers so the meshes can be built with `compute`.
MeshData buildIslandTerrainMeshData(int seed) =>
    IslandTerrain(seed: seed).buildMesh();

MeshData buildOceanMeshDataIsolate(int segments) =>
    buildOceanMeshData(segments: segments);

MeshData buildSimpleSeaMeshDataIsolate(int seed) =>
    buildSimpleSeaMeshData(IslandTerrain(seed: seed));

/// Triangulates concentric rings around the origin, wound counter-clockwise
/// seen from above so the front faces point +Y.
MeshData _buildPolarGrid({
  required List<double> radii,
  required int segments,
  required double Function(double x, double z) heightAt,
  (double, double) Function(double x, double z)? colorAt,
  bool includeCentre = true,
}) {
  final ringCount = radii.length;
  final centreCount = includeCentre ? 1 : 0;
  final vertexCount = centreCount + ringCount * segments;
  final positions = Float32List(vertexCount * 3);
  final texCoords = Float32List(vertexCount * 2);
  final colors = Float32List(vertexCount * 4);

  void write(int index, double x, double z) {
    final y = heightAt(x, z);
    positions[index * 3] = x;
    positions[index * 3 + 1] = y;
    positions[index * 3 + 2] = z;
    texCoords[index * 2] = x;
    texCoords[index * 2 + 1] = z;
    final (a, b) = colorAt?.call(x, z) ?? (0.0, 0.0);
    colors[index * 4] = a;
    colors[index * 4 + 1] = b;
    colors[index * 4 + 2] = 0.0;
    colors[index * 4 + 3] = 1.0;
  }

  if (includeCentre) {
    write(0, 0.0, 0.0);
  }
  for (var ring = 0; ring < ringCount; ring++) {
    final r = radii[ring];
    for (var s = 0; s < segments; s++) {
      final theta = s / segments * 2 * math.pi;
      write(
        centreCount + ring * segments + s,
        r * math.cos(theta),
        r * math.sin(theta),
      );
    }
  }

  int at(int ring, int s) => centreCount + ring * segments + (s % segments);

  final indices = <int>[];
  if (includeCentre) {
    for (var s = 0; s < segments; s++) {
      indices
        ..add(0)
        ..add(at(0, s + 1))
        ..add(at(0, s));
    }
  }
  for (var ring = 0; ring < ringCount - 1; ring++) {
    for (var s = 0; s < segments; s++) {
      final inner0 = at(ring, s);
      final inner1 = at(ring, s + 1);
      final outer0 = at(ring + 1, s);
      final outer1 = at(ring + 1, s + 1);
      indices
        ..add(inner0)
        ..add(inner1)
        ..add(outer0)
        ..add(inner1)
        ..add(outer1)
        ..add(outer0);
    }
  }
  return MeshData.build(
    positions: positions,
    texCoords: texCoords,
    colors: colors,
    indices: indices,
  );
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

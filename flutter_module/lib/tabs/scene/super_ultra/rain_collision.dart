/// What a raindrop hits in the Super Ultra island, as cheap analytic shapes.
///
/// Rain is thousands of CPU particles, so collision cannot go through
/// `Scene.raycast`: that tests render triangles without a per-mesh BVH, and it
/// skips instanced meshes entirely (the scattered props and balls are
/// instanced). Instead every surface a drop can land on is a proxy:
///
/// * the island and seabed: a height grid sampled once from
///   `IslandTerrain.height` (on an isolate);
/// * the sea: a plane at sea level wherever the ground is below it;
/// * props: vertical ellipsoids (rocks, bushes, palm canopies), cylinders
///   (trunks) and cones (pines), sized from the models' real bounds;
/// * things that move (player, NPC, balls, crates): capsules and spheres,
///   refreshed once per simulation step.
///
/// Pure maths, no GPU, so it is unit-tested.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_module/tabs/scene/super_ultra/island_terrain.dart';

/// The kind of surface a drop hit, which decides its splash.
enum RainSurface { ground, water, prop, character, ball, fire }

/// Where and on what a drop landed. [y] is the surface height there.
class RainHit {
  const RainHit(this.surface, this.x, this.y, this.z);

  final RainSurface surface;
  final double x;
  final double y;
  final double z;
}

/// A prop placement, in the island's placement terms.
class RainProp {
  const RainProp(this.kind, this.x, this.z, this.scale);

  /// `palm`, `pine`, `rockLarge`, `rockSmall`, `bush`, or `campfire`.
  final String kind;
  final double x;
  final double z;
  final double scale;
}

/// Ground heights on a regular grid, bilinearly interpolated. Outside the
/// grid the ground is [outside] (deep seabed).
class RainHeightGrid {
  RainHeightGrid({
    required this.heights,
    required this.resolution,
    required this.halfSize,
    required this.outside,
  }) : samples = (2 * halfSize / resolution).round() + 1;

  final Float32List heights;
  final double resolution;
  final double halfSize;
  final double outside;
  final int samples;

  double heightAt(double x, double z) {
    final gx = (x + halfSize) / resolution;
    final gz = (z + halfSize) / resolution;
    if (gx < 0 || gz < 0 || gx >= samples - 1 || gz >= samples - 1) {
      return outside;
    }
    final ix = gx.floor();
    final iz = gz.floor();
    final fx = gx - ix;
    final fz = gz - iz;
    final i00 = iz * samples + ix;
    final h00 = heights[i00];
    final h10 = heights[i00 + 1];
    final h01 = heights[i00 + samples];
    final h11 = heights[i00 + samples + 1];
    final top = h00 + (h10 - h00) * fx;
    final bottom = h01 + (h11 - h01) * fx;
    return top + (bottom - top) * fz;
  }
}

/// Samples the island terrain into a [RainHeightGrid]. Top-level so it can
/// run with `compute`; the terrain's noise makes this tens of milliseconds.
RainHeightGrid buildRainHeightGrid(double seaLevel) {
  const halfSize = 48.0;
  const resolution = 0.5;
  final terrain = IslandTerrain(seed: 5, seaLevel: seaLevel);
  final samples = (2 * halfSize / resolution).round() + 1;
  final heights = Float32List(samples * samples);
  for (var iz = 0; iz < samples; iz++) {
    final z = -halfSize + iz * resolution;
    for (var ix = 0; ix < samples; ix++) {
      final x = -halfSize + ix * resolution;
      heights[iz * samples + ix] = terrain.height(x, z);
    }
  }
  return RainHeightGrid(
    heights: heights,
    resolution: resolution,
    halfSize: halfSize,
    outside: IslandTerrain.deepestFloor,
  );
}

/// Moving obstacles, rewritten once per simulation step. Spheres and
/// vertical capsules only.
class RainDynamics {
  final List<double> _spheres = <double>[];
  final List<double> _capsules = <double>[];
  double _highest = double.negativeInfinity;

  /// The top of the highest moving obstacle, so drops above it (and above
  /// every prop) can skip collision entirely.
  double get highestPoint => _highest;

  /// The capsules (characters), for aiming extra rain at them.
  int get capsuleCount => _capsules.length ~/ 5;
  double capsuleX(int i) => _capsules[i * 5];
  double capsuleZ(int i) => _capsules[i * 5 + 2];

  void clear() {
    _spheres.clear();
    _capsules.clear();
    _highest = double.negativeInfinity;
  }

  void addSphere(double x, double y, double z, double radius) {
    _spheres
      ..add(x)
      ..add(y)
      ..add(z)
      ..add(radius);
    _highest = math.max(_highest, y + radius);
  }

  /// A vertical capsule standing on (x, [bottom], z), [height] tall.
  void addCapsule(double x, double bottom, double z, double radius, double height) {
    _capsules
      ..add(x)
      ..add(bottom)
      ..add(z)
      ..add(radius)
      ..add(height);
    _highest = math.max(_highest, bottom + height + radius);
  }
}

class RainCollider {
  RainCollider({
    required this.grid,
    required this.seaLevel,
    required List<RainProp> props,
    this.fireX = 0.0,
    this.fireZ = -0.45,
    this.fireRadius = 0.42,
  }) {
    for (final prop in props) {
      _addProp(prop);
    }
    for (final shape in _shapes) {
      _propTop = math.max(_propTop, shape.top);
    }
    _buildCells();
  }

  final RainHeightGrid grid;
  final double seaLevel;
  final double fireX;
  final double fireZ;
  final double fireRadius;

  final List<_Shape> _shapes = <_Shape>[];
  double _propTop = 0.0;

  /// Broadphase: a uniform grid over the props' footprints. Each cell lists,
  /// in shape order, the shapes whose footprint square overlaps it, so a drop
  /// tests only its own cell's shapes and still gets the same first hit as
  /// testing every shape.
  static const double _cellSize = 1.0;
  double _cellMinX = 0.0;
  double _cellMinZ = 0.0;
  int _cellsX = 0;
  int _cellsZ = 0;
  Int32List _cellStart = Int32List(1);
  Int32List _cellShapes = Int32List(0);

  /// The highest point any static prop reaches. Drops above it (and above
  /// every moving obstacle) skip the prop tests entirely.
  double get propTop => _propTop;

  /// How many static shapes the props became.
  int get shapeCount => _shapes.length;

  /// Heights and footprints from the models' own bounds (`assets/models`):
  /// palm 1.36 tall with a 0.52 canopy, pine 1.25 with a 0.26 base, large
  /// rock 0.26 x 0.45, small rock 0.18, bush 0.24 x 0.19, all times scale.
  void _addProp(RainProp prop) {
    final s = prop.scale;
    switch (prop.kind) {
      case 'palm':
        _shapes
          ..add(_Cylinder(prop.x, prop.z, 0.06 * s, 0.0, 1.15 * s))
          ..add(_Ellipsoid(prop.x, 1.2 * s, prop.z, 0.54 * s, 0.17 * s));
      case 'pine':
        _shapes.add(_Cone(prop.x, prop.z, 0.28 * s, 0.1 * s, 1.25 * s));
      case 'rockLarge':
        _shapes.add(_Ellipsoid(prop.x, 0.0, prop.z, 0.46 * s, 0.26 * s));
      case 'rockSmall':
        _shapes.add(_Ellipsoid(prop.x, 0.0, prop.z, 0.19 * s, 0.18 * s));
      case 'bush':
        _shapes.add(_Ellipsoid(prop.x, 0.0, prop.z, 0.2 * s, 0.25 * s));
      case 'campfire':
        // The fire itself is handled as [RainSurface.fire]; the stones are
        // too low to matter.
        break;
    }
  }

  void _buildCells() {
    if (_shapes.isEmpty) {
      return;
    }
    var minX = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final shape in _shapes) {
      minX = math.min(minX, shape.cx - shape.reach);
      minZ = math.min(minZ, shape.cz - shape.reach);
      maxX = math.max(maxX, shape.cx + shape.reach);
      maxZ = math.max(maxZ, shape.cz + shape.reach);
    }
    _cellMinX = minX;
    _cellMinZ = minZ;
    _cellsX = ((maxX - minX) / _cellSize).floor() + 1;
    _cellsZ = ((maxZ - minZ) / _cellSize).floor() + 1;
    final buckets = List<List<int>>.generate(_cellsX * _cellsZ, (_) => <int>[]);
    for (var i = 0; i < _shapes.length; i++) {
      final shape = _shapes[i];
      final x0 = ((shape.cx - shape.reach - minX) / _cellSize).floor();
      final x1 = ((shape.cx + shape.reach - minX) / _cellSize).floor();
      final z0 = ((shape.cz - shape.reach - minZ) / _cellSize).floor();
      final z1 = ((shape.cz + shape.reach - minZ) / _cellSize).floor();
      for (var cz = z0; cz <= z1; cz++) {
        for (var cx = x0; cx <= x1; cx++) {
          buckets[cz * _cellsX + cx].add(i);
        }
      }
    }
    _cellStart = Int32List(buckets.length + 1);
    _cellShapes = Int32List(buckets.fold<int>(0, (n, b) => n + b.length));
    var at = 0;
    for (var c = 0; c < buckets.length; c++) {
      _cellStart[c] = at;
      for (final i in buckets[c]) {
        _cellShapes[at++] = i;
      }
    }
    _cellStart[buckets.length] = at;
  }

  /// Tests a drop at ([x], [y], [z]). Returns what it hit, or null while it is
  /// still falling. Call after each integration step; a drop moves about
  /// 0.2 m per step, so hits are resolved to within that.
  RainHit? test(double x, double y, double z, RainDynamics dynamics) {
    // Moving things first: balls can be in the air, well above the props.
    final spheres = dynamics._spheres;
    for (var i = 0; i < spheres.length; i += 4) {
      final dx = x - spheres[i];
      final dy = y - spheres[i + 1];
      final dz = z - spheres[i + 2];
      final r = spheres[i + 3];
      if (dx * dx + dy * dy + dz * dz <= r * r) {
        final top = spheres[i + 1] +
            math.sqrt(math.max(r * r - dx * dx - dz * dz, 0.0));
        return RainHit(RainSurface.ball, x, top, z);
      }
    }
    final capsules = dynamics._capsules;
    for (var i = 0; i < capsules.length; i += 5) {
      final bottom = capsules[i + 1];
      final radius = capsules[i + 3];
      final top = bottom + capsules[i + 4];
      if (y > top + radius || y < bottom) {
        continue;
      }
      final dx = x - capsules[i];
      final dz = z - capsules[i + 2];
      final cy = y.clamp(bottom + radius, top);
      final dy = y - cy;
      if (dx * dx + dy * dy + dz * dz <= radius * radius) {
        return RainHit(RainSurface.character, x, y, z);
      }
    }

    if (y <= _propTop) {
      final fdx = x - fireX;
      final fdz = z - fireZ;
      if (y < 0.55 && fdx * fdx + fdz * fdz <= fireRadius * fireRadius) {
        return RainHit(RainSurface.fire, x, math.max(y, 0.05), z);
      }
      final cx = ((x - _cellMinX) / _cellSize).floor();
      final cz = ((z - _cellMinZ) / _cellSize).floor();
      if (cx >= 0 && cz >= 0 && cx < _cellsX && cz < _cellsZ) {
        final cell = cz * _cellsX + cx;
        for (var i = _cellStart[cell]; i < _cellStart[cell + 1]; i++) {
          final surface = _shapes[_cellShapes[i]].surfaceAbove(x, y, z);
          if (surface != null) {
            return RainHit(RainSurface.prop, x, surface, z);
          }
        }
      }
    }

    // Cheap reject before touching the grid: nothing lies above the flat top.
    if (y > 0.05) {
      return null;
    }
    final ground = grid.heightAt(x, z);
    if (ground >= seaLevel) {
      return y <= ground ? RainHit(RainSurface.ground, x, ground, z) : null;
    }
    return y <= seaLevel ? RainHit(RainSurface.water, x, seaLevel, z) : null;
  }
}

/// A static obstacle. [surfaceAbove] returns the height of the shape's top
/// surface over (x, z) if the point is inside the shape, else null.
abstract class _Shape {
  /// Footprint centre, and the horizontal radius that bounds it.
  double get cx;
  double get cz;
  double get reach;
  double get top;
  double? surfaceAbove(double x, double y, double z);
}

/// An ellipsoid with a vertical axis: horizontal radius [rx], vertical [ry].
class _Ellipsoid implements _Shape {
  _Ellipsoid(this.cx, this.cy, this.cz, this.rx, this.ry);

  @override
  final double cx, cz;
  final double cy, rx, ry;

  @override
  double get reach => rx;

  @override
  double get top => cy + ry;

  @override
  double? surfaceAbove(double x, double y, double z) {
    final dx = x - cx;
    final dz = z - cz;
    final radial = (dx * dx + dz * dz) / (rx * rx);
    if (radial > 1.0) {
      return null;
    }
    final dy = y - cy;
    if (radial + dy * dy / (ry * ry) > 1.0) {
      return null;
    }
    return cy + ry * math.sqrt(1.0 - radial);
  }
}

class _Cylinder implements _Shape {
  _Cylinder(this.cx, this.cz, this.radius, this.bottom, this.height);

  @override
  final double cx, cz;
  final double radius, bottom, height;

  @override
  double get reach => radius;

  @override
  double get top => bottom + height;

  @override
  double? surfaceAbove(double x, double y, double z) {
    if (y < bottom || y > top) {
      return null;
    }
    final dx = x - cx;
    final dz = z - cz;
    return dx * dx + dz * dz <= radius * radius ? top : null;
  }
}

/// A cone standing on its base: [baseRadius] at [bottom], a point at
/// `bottom + height`.
class _Cone implements _Shape {
  _Cone(this.cx, this.cz, this.baseRadius, this.bottom, this.height);

  @override
  final double cx, cz;
  final double baseRadius, bottom, height;

  @override
  double get reach => baseRadius;

  @override
  double get top => bottom + height;

  @override
  double? surfaceAbove(double x, double y, double z) {
    if (y < bottom || y > top) {
      return null;
    }
    final dx = x - cx;
    final dz = z - cz;
    final d = math.sqrt(dx * dx + dz * dz);
    final allowed = baseRadius * (1.0 - (y - bottom) / height);
    if (d > allowed) {
      return null;
    }
    return bottom + height * (1.0 - d / baseRadius);
  }
}

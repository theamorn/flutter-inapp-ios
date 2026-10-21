/// The indirect light the Super Ultra firepit stones supply themselves
/// (`campfire_stone.fmat`, `environment_lighting: false`): a sky colour above
/// and a ground bounce below, following the island's ambient schedule. The
/// sun, moon and campfire still light the stones as real lights; only the
/// image-based term is replaced, and only on this one small rough object.
///
/// [stoneLightingFor] is pure (no GPU) and unit-tested; [StoneLightingBinding]
/// is its scene adapter.
library;

import 'package:flutter_module/tabs/scene/render/material_binding_policy.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// The firepit's comparison: the engine's image-based indirect light, or the
/// stones' own sky/ground gradient. Custom by default in Super Ultra.
enum StoneIndirectMode {
  engine,
  custom;

  static const StoneIndirectMode initial = StoneIndirectMode.custom;
}

/// Upper (sky) and lower (ground bounce) indirect radiance, already scaled by
/// the ambient schedule, plus a multiplier the shader applies on top.
class StoneLighting {
  const StoneLighting(
    this.upper,
    this.lower,
    this.multiplier, {
    this.weather = 0.0,
    this.campfireIntensity = 0.0,
  });
  final Vector3 upper, lower;
  final double multiplier;
  final double weather;
  final double campfireIntensity;
}

// Clear-sky zenith by day and by night, the overcast grey rain blends toward,
// and how much of the sky the sand and grass throw back up.
final Vector3 _daySky = Vector3(0.55, 0.66, 0.78);
final Vector3 _nightSky = Vector3(0.05, 0.08, 0.16);
final Vector3 _overcast = Vector3(0.5, 0.52, 0.55);
final Vector3 _groundTint = Vector3(0.62, 0.55, 0.42);
const double _groundBounce = 0.35;

double _unit(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

/// The stones' indirect light for an island [ambient] (the scene's
/// environment intensity), a [night] blend and a [weather] (rain) level.
/// Zero ambient gives zero indirect light: the stones never glow on their own.
StoneLighting stoneLightingFor({
  required double ambient,
  required double night,
  required double weather,
  double campfireIntensity = 0.0,
}) {
  final a = ambient.isNaN ? 0.0 : ambient.clamp(0.0, 4.0);
  final n = _unit(night);
  final w = _unit(weather);
  final fire = campfireIntensity.isNaN ? 0.0 : campfireIntensity.clamp(0.0, 2.0);
  final clear = _daySky * (1.0 - n) + _nightSky * n;
  // Overcast keeps the sky's brightness but drains its colour.
  final luma = clear.dot(Vector3(0.2126, 0.7152, 0.0722));
  final grey = _overcast * (luma / 0.52);
  final sky = clear * (1.0 - 0.8 * w) + grey * (0.8 * w);
  final upper = sky * a;
  final lower = Vector3(
        sky.x * _groundTint.x,
        sky.y * _groundTint.y,
        sky.z * _groundTint.z,
      ) *
      (_groundBounce * a);
  return StoneLighting(
    upper,
    lower,
    1.0,
    weather: w,
    campfireIntensity: fire,
  );
}

/// The imported campfire model's stone ring and its material.
const String kCampfireStonesNode = 'campfire_stones';
const String kCampfireStoneMaterial = 'stone';

/// Dresses the firepit stones under each placed campfire in
/// `campfire_stone.fmat`, and puts the imported mesh back on [release].
/// Only primitives wearing the imported `stone` material change, on nodes
/// named [kCampfireStonesNode]; every other imported material keeps its
/// authored shading.
class StoneLightingBinding {
  StoneLightingBinding(this.material);

  final PreprocessedMaterial material;
  final MaterialBindingPolicy<Node, Mesh> _policy = MaterialBindingPolicy();
  double _baseRoughness = 0.85;
  double _weather = 0.0;
  double _campfireIntensity = 0.0;

  bool get isBound => _policy.bound.isNotEmpty;

  /// Binds the stones under every node in [campfires] (and releases any
  /// bound earlier that are no longer among them).
  void bind(Iterable<Node> campfires) {
    final stones = <Node>[for (final root in campfires) ..._stonesUnder(root)];
    final changes = _policy.reconcile(stones);
    _restore(changes.release);
    for (final node in changes.bind) {
      final own = node.mesh;
      if (own == null) continue;
      node.mesh = Mesh.primitives(primitives: [
        for (final p in own.primitives)
          MeshPrimitive(p.geometry, _isStone(p.material) ? _styled(p.material) : p.material)
            ..visible = p.visible
            ..castsShadow = p.castsShadow,
      ]);
      _policy.bind(node, own);
    }
  }

  /// Puts every imported mesh back.
  void release() => _restore(_policy.releaseAll());

  /// Pushes the island's current indirect light into the stone material.
  void apply(StoneLighting lighting) {
    final u = lighting.upper, l = lighting.lower;
    _weather = lighting.weather;
    _campfireIntensity = lighting.campfireIntensity;
    material.parameters
      ..setVec4('sky_upper', Vector4(u.x, u.y, u.z, lighting.multiplier))
      ..setVec4('sky_lower', Vector4(l.x, l.y, l.z, 0))
      ..setVec4(
        'stone',
        Vector4(_baseRoughness, 0, _weather, _campfireIntensity),
      );
  }

  static void _restore(List<(Node, Mesh)> released) {
    for (final (node, own) in released) {
      if (!identical(node.mesh, own)) node.mesh = own;
    }
  }

  static bool _isStone(Material m) => m.name == kCampfireStoneMaterial;

  /// The stone material, coloured like the imported one it replaces.
  Material _styled(Material imported) {
    if (imported is PhysicallyBasedMaterial) {
      final c = imported.baseColorFactor;
      _baseRoughness = imported.roughnessFactor.clamp(0.5, 1.0);
      material.parameters
        ..setVec4('base_color', Vector4(c.x, c.y, c.z, 1))
        ..setVec4(
          'stone',
          Vector4(_baseRoughness, 0, _weather, _campfireIntensity),
        );
    }
    return material;
  }

  static Iterable<Node> _stonesUnder(Node root) sync* {
    if (root.name == kCampfireStonesNode &&
        (root.mesh?.primitives.any((p) => _isStone(p.material)) ?? false)) {
      yield root;
    }
    for (final child in root.children) {
      yield* _stonesUnder(child);
    }
  }
}

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'material_binding_policy.dart';
import 'wind.dart';

/// The sway material, compiled by the build hook.
const String kFoliageSwayFmat = 'assets/materials/foliage_sway.fmat';

/// How one tree material sways: the tree's [height] in its mesh's own units
/// (the top bends fully), the [bend] at the top in full wind (metres), and
/// the crown's [flutter] (metres; 0 for bark).
class TreeSwayStyle {
  const TreeSwayStyle({required this.height, required this.bend, this.flutter = 0});
  final double height, bend, flutter;
}

/// Dresses trees in `foliage_sway.fmat` and puts their own materials back on
/// [release]. Works on cloned tree meshes (the mesh is swapped) and on
/// instanced batches (the batch is rebuilt over the same instances, since an
/// [InstancedMesh] keeps its material for life). Each original material maps
/// to one sway material with its colour, shared by every tree that wore it.
class TreeSway {
  TreeSway._(this._pool);

  /// Loads [count] sway materials: one per distinct tree material it will
  /// meet.
  static Future<TreeSway> load(int count) async =>
      TreeSway._([for (var i = 0; i < count; i++) await loadFmatMaterial(kFoliageSwayFmat)]);

  final List<PreprocessedMaterial> _pool;
  final Map<Material, PreprocessedMaterial> _byOriginal = {};
  final MaterialBindingPolicy<Node, (Mesh, bool)> _meshes = MaterialBindingPolicy();
  final Map<Node, (List<InstancedMeshComponent>, List<InstancedMeshComponent>, bool)> _batches = {};

  /// The underlying sway material pool so callers can include them in a
  /// [MaterialGroup] for shared lighting uniforms.
  List<PreprocessedMaterial> get materials => _pool;

  bool get isBound => _meshes.bound.isNotEmpty || _batches.isNotEmpty;

  /// Sways every tree under [roots]. [styleFor] picks the sway for an
  /// original material, or null to leave the surface alone. Already-bound
  /// trees are left as they are.
  void bind(Iterable<Node> roots, TreeSwayStyle? Function(Material original) styleFor) {
    void visit(Node node) {
      _bindMesh(node, styleFor);
      _bindBatches(node, styleFor);
      node.children.forEach(visit);
    }

    roots.forEach(visit);
  }

  void _bindMesh(Node node, TreeSwayStyle? Function(Material) styleFor) {
    final own = node.mesh;
    if (own == null || _meshes.isBound(node)) return;
    final swapped = [for (final p in own.primitives) _swayFor(p.material, styleFor)];
    if (swapped.every((m) => m == null)) return;
    node.mesh = Mesh.primitives(primitives: [
      for (var i = 0; i < own.primitives.length; i++)
        MeshPrimitive(own.primitives[i].geometry, swapped[i] ?? own.primitives[i].material)
          ..visible = own.primitives[i].visible
          ..castsShadow = own.primitives[i].castsShadow,
    ]);
    // A displaced caster must not live in the cached static shadows.
    _meshes.bind(node, (own, node.shadowStatic));
    node.shadowStatic = false;
  }

  void _bindBatches(Node node, TreeSwayStyle? Function(Material) styleFor) {
    if (_batches.containsKey(node)) return;
    final removed = <InstancedMeshComponent>[], added = <InstancedMeshComponent>[];
    for (final component in node.getComponents<InstancedMeshComponent>().toList()) {
      final batch = component.instancedMesh;
      final sway = _swayFor(batch.material, styleFor);
      if (sway == null) continue;
      final copy = InstancedMesh(
        geometry: batch.geometry,
        material: sway,
        cullInstances: batch.cullInstances,
      )..drawSelector = batch.drawSelector;
      batch.updateInstanceTransforms((transforms) {
        for (final t in transforms) {
          copy.addInstance(t);
        }
      }, recomputeWinding: false);
      node.removeComponent(component);
      removed.add(component);
      final replacement = InstancedMeshComponent(copy);
      node.addComponent(replacement);
      added.add(replacement);
    }
    if (removed.isEmpty) return;
    // A displaced caster must not live in the cached static shadows.
    _batches[node] = (removed, added, node.shadowStatic);
    node.shadowStatic = false;
  }

  PreprocessedMaterial? _swayFor(Material original, TreeSwayStyle? Function(Material) styleFor) {
    final cached = _byOriginal[original];
    if (cached != null) return cached;
    final style = styleFor(original);
    if (style == null || _byOriginal.length >= _pool.length) return null;
    final sway = _pool[_byOriginal.length];
    var color = Vector4(1, 1, 1, 1);
    var roughness = 0.85;
    var vertexColor = 0.0;
    if (original is PhysicallyBasedMaterial) {
      color = original.baseColorFactor.clone();
      roughness = original.roughnessFactor;
      vertexColor = original.vertexColorWeight > 0.5 ? 1 : 0;
    }
    sway.parameters
      ..setVec4('base_color', color)
      ..setVec4('sway', Vector4(style.height, style.bend, style.flutter, vertexColor))
      ..setVec4('surface', Vector4(roughness, 0, 0, 0));
    return _byOriginal[original] = sway;
  }

  /// Blows every swaying tree with [wind].
  void apply(Wind wind) {
    final params = wind.shaderParams;
    for (final m in _byOriginal.values) {
      m.parameters.setVec4('wind', params);
    }
  }

  /// Every tree back in its own material, every batch rebuilt as it was.
  void release() {
    for (final (node, (own, wasStatic)) in _meshes.releaseAll()) {
      if (!identical(node.mesh, own)) node.mesh = own;
      node.shadowStatic = wasStatic;
    }
    _batches.forEach((node, entry) {
      final (removed, added, wasStatic) = entry;
      for (final c in added) {
        if (c.isAttached) node.removeComponent(c);
      }
      for (final c in removed) {
        node.addComponent(c);
      }
      node.shadowStatic = wasStatic;
    });
    _batches.clear();
  }
}

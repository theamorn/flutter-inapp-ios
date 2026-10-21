import 'package:flutter_module/tabs/scene/super_ultra/footprints.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Super Ultra's ground decals: one scorch ring under the campfire and a
/// pooled trail of footprints behind the player. Each DecalNode needs its own
/// material instance (the projection lives in its parameters).
class SuperUltraDecals {
  SuperUltraDecals._(this.root, this._prints, this.trail);

  final Node root;
  final List<DecalNode> _prints;
  final FootprintTrail trail;

  static const String _material = 'assets/materials/decal_ground.fmat';
  static const int _noReflectLayer = 1 << 1;

  static Future<SuperUltraDecals> build({
    required double campfireX,
    required double campfireZ,
  }) async {
    final root = Node(name: 'super_ultra_decals')..layers = _noReflectLayer;
    final scorch = DecalNode(
      material: await loadFmatMaterial(_material),
      name: 'scorch',
    )
      ..layers = _noReflectLayer
      ..project(
        point: vm.Vector3(campfireX, 0, campfireZ),
        normal: vm.Vector3(0, 1, 0),
        size: 2.5,
      );
    root.add(scorch);
    final trail = FootprintTrail();
    final prints = <DecalNode>[];
    for (var i = 0; i < trail.capacity; i++) {
      final m = await loadFmatMaterial(_material);
      m.parameters
        ..setFloat('kind', 1.0)
        ..setVec4('tint', vm.Vector4(0.04, 0.03, 0.02, 0.72));
      final d = DecalNode(material: m, name: 'footprint_$i')
        ..layers = _noReflectLayer
        ..visible = false;
      prints.add(d);
      root.add(d);
    }
    return SuperUltraDecals._(root, prints, trail);
  }

  /// Number of footprint decals currently shown.
  int get visiblePrints => _prints.where((n) => n.visible).length;

  void tick(double dt, double playerX, double playerZ, double heading) {
    if (!root.visible) {
      return;
    }
    trail.update(dt, playerX, playerZ, heading);
    final shown = trail.prints;
    for (var i = 0; i < _prints.length; i++) {
      final node = _prints[i];
      if (i >= shown.length) {
        node.visible = false;
        continue;
      }
      final p = shown[i];
      node
        ..visible = true
        // `rotation` turns the box about the normal (0.24 DecalNode.project).
        ..project(
          point: vm.Vector3(p.x, 0, p.z),
          normal: vm.Vector3(0, 1, 0),
          size: 0.38,
          rotation: p.heading,
        )
        ..fade = p.fade;
    }
  }
}

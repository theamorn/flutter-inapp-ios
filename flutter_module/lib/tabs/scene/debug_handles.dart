/// Debug builds only: the live island scene and VM-service helpers, so a
/// `vm_service` `evaluate` can reach them when a device check is driven from
/// a terminal (set a mode, pose the camera, read a counter).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart';
import 'package:flutter_module/tabs/scene/island_scene.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';
import 'package:flutter_scene/scene.dart'
    show
        DebugView,
        InstancedMesh,
        InstancedMeshComponent,
        Mesh,
        MeshDrawContext,
        MeshDrawPass,
        MeshGeometry,
        MeshPrimitive,
        Node,
        PhysicallyBasedMaterial,
        RenderQualityTier,
        Scene,
        SurfaceDebugChannel,
        loadFmatMaterial;
import 'package:vector_math/vector_math.dart';

IslandScene? debugIsland;

Scene? get debugIslandScene => debugIsland?.scene;
Node? get debugIslandCamera => debugIsland?.cameraNode;

void debugIslandAttach(IslandScene island) {
  debugIsland = island;
}

void debugIslandDetach(IslandScene island) {
  if (identical(debugIsland, island)) {
    debugIsland = null;
  }
}

final List<FrameTiming> _timings = [];
bool _listening = false;

/// Starts (once) collecting frame timings and clears what was collected, so
/// a later [debugFrameReport] covers only the frames after this call.
void debugFramesReset() {
  if (!_listening) {
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
  }
  _timings.clear();
}

/// Frames since [debugFramesReset]: count, average and p90 build and raster
/// milliseconds.
String debugFrameReport() {
  if (_timings.isEmpty) return 'no frames';
  List<double> ms(Duration Function(FrameTiming) f) =>
      [for (final t in _timings) f(t).inMicroseconds / 1000.0]..sort();
  String stat(List<double> v) =>
      '${(v.reduce((a, b) => a + b) / v.length).toStringAsFixed(1)}'
      '/p90 ${v[(v.length * 0.9).floor().clamp(0, v.length - 1)].toStringAsFixed(1)}';
  return 'n=${_timings.length} build ${stat(ms((t) => t.buildDuration))} '
      'raster ${stat(ms((t) => t.rasterDuration))}';
}

/// Frames the island's orbit camera on ([x], [y], [z]) from about twice
/// [radius] away, [polar] radians above its lowest elevation, turned by
/// [azimuth] radians.
void debugIslandFrame(
  double x,
  double y,
  double z,
  double radius, {
  double azimuth = 0,
  double polar = 0,
}) {
  final orbit = debugIsland!.orbit..minDistance = 0.3;
  orbit
    ..frame(
      Aabb3.centerAndHalfExtents(Vector3(x, y, z), Vector3.all(radius)),
      margin: 1.0,
    )
    ..orbitBy(0, -10)
    ..orbitBy(azimuth, polar);
}

/// Switches the island Effects menu entry named [name] (a [SuperUltraEffect]).
void debugIslandEffect(String name, bool on) =>
    debugIsland!.setEffect(SuperUltraEffect.values.byName(name), on);

/// Sets the island clock to [hours] (0..24).
void debugIslandTime(double hours) => debugIsland!.timeOfDay = hours;

/// Every node named [name] in the island scene: visibility, world position
/// and its primitives' material types and names.
String debugIslandDescribe(String name) {
  final out = <String>[];
  void walk(Node n) {
    if (n.name == name) {
      final p = n.globalTransform.getTranslation();
      final materials = [
        for (final prim in n.mesh?.primitives ?? const [])
          '${prim.material.runtimeType}:${prim.material.name}'
      ];
      out.add(
        '${n.visible} (${p.x.toStringAsFixed(2)}, ${p.y.toStringAsFixed(2)}, '
        '${p.z.toStringAsFixed(2)}) $materials',
      );
    }
    n.children.forEach(walk);
  }

  walk(debugIsland!.scene.root);
  return out.join(' | ');
}

/// Shows the island's surfaces through the debug channel named [channel]
/// (a [SurfaceDebugChannel]), or the lit scene again for null.
void debugIslandView(String? channel) =>
    debugIsland!.scene.debug.view = channel == null
        ? DebugView.none
        : DebugView(channel: SurfaceDebugChannel.values.byName(channel));

/// Experiments on the first node named [name] in the island scene:
/// `reattach` (detach and re-add to its parent) or `pbr` (swap every
/// primitive to a plain red PBR material, as the bindings swap meshes).
String debugIslandNodeOp(String name, String op) {
  Node? found;
  void walk(Node n) {
    if (found == null && n.name == name) found = n;
    n.children.forEach(walk);
  }

  walk(debugIsland!.scene.root);
  final node = found;
  if (node == null) return 'not found';
  switch (op) {
    case 'reattach':
      final parent = node.parent!;
      node.detach();
      parent.add(node);
    case 'pbr':
      final own = node.mesh!;
      node.mesh = Mesh.primitives(primitives: [
        for (final p in own.primitives)
          MeshPrimitive(
            p.geometry,
            PhysicallyBasedMaterial()..baseColorFactor = Vector4(1, 0, 0, 1),
          ),
      ]);
  }
  return 'ok static=${node.shadowStatic} parentStatic=${node.parent?.shadowStatic}';
}

/// Captures one island frame and prints every draw and skipped item whose
/// node path contains [needle], as `capture:` lines, then `capture: done`.
void debugIslandCapture(String needle) {
  Scene.debugAllowRenderGraphCapture = true;
  debugIsland!.scene.captureRenderGraph().then((r) {
    for (final pass in r.passes) {
      for (final d in pass.draws) {
        if ((d.nodePath ?? '').contains(needle)) {
          debugPrint('capture: ${pass.name} draw ${d.nodePath} '
              '${d.materialSource ?? d.materialType} ${d.fragmentShaderName} '
              'verts ${d.vertexCount} inst ${d.instanceCount}');
        }
      }
      for (final s in pass.skips) {
        if ((s.nodePath ?? '').contains(needle)) {
          debugPrint('capture: ${pass.name} skip ${s.nodePath} ${s.reason.name}');
        }
      }
    }
    debugPrint('capture: done (${r.passes.length} passes)');
  }, onError: (Object e) => debugPrint('capture: error $e'));
}

/// Loads the `.fmat` at [path] and swaps every primitive of the first island
/// node named [name] to it (prints `swap: done` when it lands); [repack]
/// first copies the geometry into a code-built [MeshGeometry].
void debugIslandNodeFmat(String name, String path, {bool repack = false}) {
  Node? found;
  void walk(Node n) {
    if (found == null && n.name == name) found = n;
    n.children.forEach(walk);
  }

  walk(debugIsland!.scene.root);
  final node = found!;
  loadFmatMaterial(path).then((m) {
    final own = node.mesh!;
    node.mesh = Mesh.primitives(primitives: [
      for (final p in own.primitives)
        MeshPrimitive(
          repack
              ? MeshGeometry.fromMeshData(p.geometry.extractMeshData())
              : p.geometry,
          m,
        ),
    ]);
    debugPrint('swap: done $path');
  });
}

/// Loads the `.fmat` at [path] and draws the Super Ultra lawn with it (a
/// fresh InstancedMesh over the same instances), for shader experiments.
void debugIslandLawnFmat(String path) {
  Node? found;
  void walk(Node n) {
    if (found == null && n.name == 'su_grass') found = n;
    n.children.forEach(walk);
  }

  walk(debugIsland!.scene.root);
  final node = found!;
  final current = node.getComponent<InstancedMeshComponent>()!;
  loadFmatMaterial(path).then((m) {
    final old = current.instancedMesh;
    final batch = InstancedMesh(geometry: old.geometry, material: m)
      ..drawSelector = old.drawSelector;
    old.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        batch.addInstance(transforms[i]);
      }
    }, recomputeWinding: false);
    for (final c in node.getComponents<InstancedMeshComponent>().toList()) {
      node.removeComponent(c);
    }
    node.addComponent(InstancedMeshComponent(batch));
    debugPrint('lawn: done $path');
  });
}

/// Pins the island's render quality tier (`low`, `medium`, `high`), or lets
/// the platform pick again for null. Returns the effective tier.
String debugIslandTier(String? tier) {
  final scene = debugIsland!.scene;
  scene.renderQuality.tier =
      tier == null ? null : RenderQualityTier.values.byName(tier);
  return scene.effectiveRenderQualityTier.name;
}

/// How many lawn tufts the Super Ultra grass selector draws now, per pass,
/// out of the total.
String debugIslandGrassCount() {
  Node? found;
  void walk(Node n) {
    if (found == null && n.name == 'su_grass') found = n;
    n.children.forEach(walk);
  }

  walk(debugIsland!.scene.root);
  final mesh = found!.getComponent<InstancedMeshComponent>()!.instancedMesh;
  final selector = mesh.drawSelector;
  if (selector == null) return 'no selector, ${mesh.instanceCount}';
  final context = MeshDrawContext(
    pass: MeshDrawPass.color,
    cameraPosition: Vector3.zero(),
    primaryView: true,
  );
  final colour = selector(context).instanceCount;
  context.pass = MeshDrawPass.depth;
  final depth = selector(context).instanceCount;
  return 'colour $colour depth $depth of ${mesh.instanceCount}';
}

/// The island's live ripple count and whether the distortion pass is on.
String debugIslandRipples() {
  final d = debugIsland!.scene.screenDistortion;
  return 'pulses ${d.pulses.length} enabled ${d.enabled} strikes ${debugIsland!.lightningStrikes}';
}

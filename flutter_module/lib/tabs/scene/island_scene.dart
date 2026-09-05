/// The island scene graph, camera rig, and day/night model for tab 5.
///
/// See `docs/hybrid-demo/06-island-scene.md`. Everything that touches
/// `flutter_scene` lives here; the tap-to-move maths is in `tap_to_move.dart`
/// (unit-testable, no GPU) and the 2D particle layer is in `particles.dart`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/kit.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_module/tabs/scene/tap_to_move.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Fixed dimensions of the island. The walkable disc and the visible grass cap
/// are derived from the same constants so the ground the tap picks and the
/// ground the audience sees can never drift apart.
class IslandDimensions {
  const IslandDimensions._();

  /// The height of the walkable surface. Everything picks against this plane.
  static const double groundY = 0.0;

  /// Radius of the grass cap.
  static const double topRadius = 3.5;

  /// Radius the character is allowed to reach — inside the rim, so it never
  /// stands half over the edge.
  static const double walkableRadius = 3.0;

  /// Height of the grass cap slab (its top face is [groundY]).
  static const double capHeight = 0.45;

  /// Radius and height of the dirt cone hanging below the cap.
  static const double coneBottomRadius = 0.55;
  static const double coneHeight = 3.0;

  /// Sea level. The cone pokes through it, so the island reads as land rather
  /// than as a floating rock.
  static const double seaY = -1.35;
  static const double seaRadius = 60.0;
}

/// Model + view-model for the island. Owns the [Scene], the camera rig, the
/// day/night cycle, and the character.
class IslandScene {
  IslandScene();

  final Scene scene = Scene();

  /// One sky source drives the visible sky, the image-based lighting, and
  /// (through [dayNight]) the sun's direction, colour and intensity.
  final PhysicalSkySource sky = PhysicalSkySource();

  /// Reused across every instance of a prop so triangles are counted once per
  /// *instance* but extracted once per *geometry*.
  final Map<Geometry, int> _triangleCache = <Geometry, int>{};

  late final DirectionalLight sunLight;
  late final Node sunNode;
  late final DirectionalLight moonLight;
  late final Node moonNode;
  late final DayNightCycleComponent dayNight;

  late final CameraComponent _cameraComponent;
  late final OrbitCameraController orbit;

  /// The camera the [SceneView] renders through and the tap picks against.
  /// The same object, so a picked ray can never disagree with the image.
  Camera get camera => _cameraComponent.toCamera();

  final WalkerMotion walker = WalkerMotion(
    position: vm.Vector3(0, IslandDimensions.groundY, 1.1),
    speed: 1.9,
  );

  Node? _characterPivot;
  AnimationClip? _idleClip;
  AnimationClip? _walkClip;
  double _walkBlend = 0;

  _TapMarker? _marker;

  /// Triangles submitted by the scene graph, counted at build time.
  int triangleCount = 0;

  /// Mesh primitives in the scene graph. Each is one draw call in the colour
  /// pass; shadow, sky and post passes are extra and are NOT counted here.
  int drawCallCount = 0;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Time of day, 0..24. The slider writes straight to this.
  double get timeOfDay => dayNight.timeOfDay;
  set timeOfDay(double value) => dayNight.timeOfDay = value.clamp(0.0, 24.0);

  /// 0 in full daylight, 1 in full night. Drives the particle cross-fade.
  double get nightBlend {
    final elevation = dayNight.sunDirection.y;
    // Fade across the horizon band rather than snapping at exactly y == 0.
    return (1.0 - (elevation + 0.12) / 0.34).clamp(0.0, 1.0);
  }

  /// Builds the whole scene. Safe to await before the first frame is shown.
  Future<void> load() async {
    await Scene.initializeStaticResources();

    _buildEnvironment();
    _buildTerrain();
    _buildCamera();
    await _buildProps();
    await _buildCharacter();

    _marker = _TapMarker(scene);
    // Aim the sun and the sky once before the first frame, for the same
    // reason as the camera above.
    dayNight.update(0.0);
    _recount();
    _loaded = true;
  }

  // ---------------------------------------------------------------- sky/sun

  void _buildEnvironment() {
    scene.skybox = Skybox(sky);
    // The sun moves continuously while the slider is swept, so the baked IBL
    // has to be refreshed. `interval` at a low face resolution keeps that to a
    // fraction of a frame instead of a full bake every frame.
    scene.skyEnvironment = SkyEnvironment(
      sky,
      refresh: SkyEnvironmentRefresh.interval,
      interval: const Duration(milliseconds: 200),
      faceResolution: 64,
      equirectWidth: 256,
    );

    // NOTE: this is deliberately NOT `Scene.sunLight`/`SunLight`. See the
    // findings in 06-island-scene.md: in flutter_scene 0.23.0
    // `PhysicalSkySource.sunLightColor` is a constant white, so a `SunLight`
    // never reddens at sunset. `DayNightCycleComponent` ramps the sun colour
    // itself, on the same 0..3 intensity scale the sky uses, so it is the one
    // that actually produces a sunset.
    sunLight = DirectionalLight(
      castsShadow: true,
      shadowMaxDistance: 24.0,
      shadowCascadeCount: 2,
      shadowMapResolution: 1024,
      shadowSoftness: 0.06,
      shadowAmbientStrength: 0.35,
    );
    sunNode = Node(name: 'sun')
      ..addComponent(DirectionalLightComponent(sunLight));
    scene.add(sunNode);

    // A moon. Without it the island is pure black once the sun sets: the sky
    // is the only light source, `PhysicalSkySource` renders black below the
    // horizon, so the baked environment goes black too and no amount of
    // `environmentIntensity` brings it back. A dim, cold, fixed key light is
    // what makes the night half of the slider readable from the back of a
    // room. It casts no shadow -- one shadow pass is enough.
    moonLight = DirectionalLight(
      color: vm.Vector3(0.34, 0.48, 0.95),
      intensity: 0.0,
    );
    moonNode = Node(name: 'moon')
      ..addComponent(DirectionalLightComponent(moonLight));
    scene.add(moonNode);
    moonNode.lookAtFrom(vm.Vector3(-7, 9, 6), vm.Vector3.zero());

    dayNight = DayNightCycleComponent(
      timeOfDay: 10.5,
      // 0 = presenter-driven. The slider is the clock; nothing runs on its own.
      timeSpeed: 0.0,
      latitude: 26.0,
      sunLightNode: sunNode,
      skySource: sky,
      targetScene: scene,
      // The component still aims the sun and drives the sky; only the colour
      // and intensity application is taken over in [_applyLighting], so the
      // ambient term can be given a floor and the moon can be blended in.
      applyLightingToTarget: false,
    );
    scene.root.addComponent(dayNight);

    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      // Below 1.0: the default exposure pushes this palette into the tone
      // curve's desaturating shoulder and the whole island goes pastel.
      exposure: 0.8,
      colorGradingEnabled: true,
      saturation: 1.4,
      contrast: 1.18,
      brightness: 1.0,
      temperature: 0.1,
      bloomEnabled: true,
      bloomThreshold: 0.9,
      bloomIntensity: 0.28,
      bloomScatter: 0.8,
      vignetteEnabled: true,
      vignetteIntensity: 0.2,
    );
  }

  // ---------------------------------------------------------------- terrain

  void _buildTerrain() {
    final grass = _flatMaterial(0.11, 0.40, 0.13, roughness: 0.92);
    final dirt = _flatMaterial(0.28, 0.15, 0.07, roughness: 0.95);
    final sea = _flatMaterial(0.012, 0.10, 0.26, roughness: 0.16);

    // Grass cap: a slightly flared slab whose TOP face sits exactly on
    // groundY, which is the plane the tap picks against.
    final cap = Node(
      name: 'island_cap',
      mesh: Mesh(
        CylinderGeometry(
          bottomRadius: IslandDimensions.topRadius - 0.18,
          topRadius: IslandDimensions.topRadius,
          height: IslandDimensions.capHeight,
          radialSegments: 40,
        ),
        grass,
      ),
    )..position = vm.Vector3(0, IslandDimensions.groundY - IslandDimensions.capHeight / 2, 0);
    cap.shadowStatic = true;
    scene.add(cap);

    final cone = Node(
      name: 'island_cone',
      mesh: Mesh(
        CylinderGeometry(
          bottomRadius: IslandDimensions.coneBottomRadius,
          topRadius: IslandDimensions.topRadius - 0.18,
          height: IslandDimensions.coneHeight,
          radialSegments: 40,
          topCap: false,
        ),
        dirt,
      ),
    )..position = vm.Vector3(
        0,
        IslandDimensions.groundY - IslandDimensions.capHeight - IslandDimensions.coneHeight / 2,
        0,
      );
    cone.shadowStatic = true;
    scene.add(cone);

    final water = Node(
      name: 'sea',
      mesh: Mesh(DiscGeometry(radius: IslandDimensions.seaRadius, segments: 64), sea),
    )..position = vm.Vector3(0, IslandDimensions.seaY, 0);
    water.castsShadows = false;
    water.shadowStatic = true;
    scene.add(water);
  }

  PhysicallyBasedMaterial _flatMaterial(
    double r,
    double g,
    double b, {
    double roughness = 0.9,
  }) {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(r, g, b, 1)
      // Kenney's glTF exports ship metallic 1 / roughness 1, which reads as
      // black plastic under PBR. Everything on this island is dielectric.
      ..metallicFactor = 0.0
      ..roughnessFactor = roughness;
  }

  // ----------------------------------------------------------------- camera

  void _buildCamera() {
    _cameraComponent = CameraComponent(
      projection: PerspectiveProjection(
        fovRadiansY: 45 * vm.degrees2Radians,
        near: 0.4,
        far: 220.0,
      ),
      activateOnMount: true,
    );
    orbit = OrbitCameraController(
      target: vm.Vector3(0, 0.2, 0),
      distance: 17.0,
      azimuth: 0.55,
      polar: 0.62,
      minDistance: 9.0,
      maxDistance: 26.0,
      // Never let the presenter get under the terrain or straight overhead.
      minPolar: 0.12,
      maxPolar: 1.15,
      // Panning is disabled: the island stays framed no matter how hard the
      // scene is mauled on stage.
      panSpeed: 0.0,
      smoothing: 0.18,
    );
    final cameraNode = Node(name: 'camera')
      ..addComponent(_cameraComponent)
      ..addComponent(orbit);
    scene.add(cameraNode);
    // Place the rig before the first frame. Without this the camera node is
    // still identity for one frame — at the origin, inside the island.
    orbit.update(0.0);
  }

  // ------------------------------------------------------------------ props

  Future<void> _buildProps() async {
    final palm = await _loadProp('assets/models/tree_palm.glb');
    final pine = await _loadProp('assets/models/tree_pine.glb');
    final rockLarge = await _loadProp('assets/models/rock_large.glb');
    final rockSmall = await _loadProp('assets/models/rock_small.glb');
    final campfire = await _loadProp('assets/models/campfire.glb');
    final bush = await _loadProp('assets/models/bush.glb');

    // Hand-placed rather than random: a fixed silhouette that reads from the
    // back of a room beats a scatter that might clump on the night of.
    const placements = <_Placement>[
      _Placement('palm', 2.05, -1.25, 0.7, 1.05),
      _Placement('palm', -2.25, 0.85, -2.1, 0.92),
      _Placement('palm', 0.45, -2.45, 2.4, 0.85),
      _Placement('pine', -1.55, -1.95, 1.2, 1.0),
      _Placement('pine', -0.55, -2.55, -0.35, 0.8),
      _Placement('pine', 2.35, 1.35, -1.9, 0.9),
      _Placement('rockLarge', 1.1, 1.95, 1.55, 1.0),
      _Placement('rockLarge', -2.6, -0.35, 1.35, 0.75),
      _Placement('rockSmall', 1.75, 0.55, -0.4, 1.0),
      _Placement('rockSmall', -1.15, 1.15, 2.6, 1.2),
      _Placement('rockSmall', 0.95, -0.75, -2.3, 0.9),
      _Placement('campfire', 0.0, 0.05, -0.15, 1.3),
      _Placement('bush', 1.35, 2.35, 0.9, 1.1),
      _Placement('bush', -2.05, 1.85, 2.2, 0.9),
      _Placement('bush', 2.75, -0.45, -1.1, 1.0),
      _Placement('bush', -0.85, -1.05, 0.4, 0.8),
    ];

    final sources = <String, Node>{
      'palm': palm,
      'pine': pine,
      'rockLarge': rockLarge,
      'rockSmall': rockSmall,
      'campfire': campfire,
      'bush': bush,
    };

    for (final placement in placements) {
      final source = sources[placement.kind]!;
      final instance = source.clone()
        ..position = vm.Vector3(
          placement.x,
          IslandDimensions.groundY,
          placement.z,
        )
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          placement.yaw,
        )
        // Uniform only: a non-uniform scale silently breaks lighting.
        ..scale = vm.Vector3.all(placement.scale);
      instance.shadowStatic = true;
      scene.add(instance);
    }
  }

  Future<Node> _loadProp(String assetPath) async {
    try {
      final node = await loadScene(assetPath);
      _relightImportedMaterials(node);
      return node;
    } catch (error) {
      // Without the asset path an import failure is anonymous: the stack
      // stops inside flutter_scene's realizer and every prop looks alike.
      throw Exception('failed to load $assetPath: $error');
    }
  }

  // -------------------------------------------------------------- character

  Future<void> _buildCharacter() async {
    final model = await loadScene('assets/models/character.glb');
    _relightImportedMaterials(model);

    // The Kenney character is authored ~8 units tall and faces -Z. Both are
    // absorbed by this inner node so the pivot the walker drives is a clean
    // "stands on the ground, +Z is forward" transform.
    final inner = Node(name: 'character_model')
      ..add(model)
      ..scale = vm.Vector3.all(_characterScale)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);

    final pivot = Node(name: 'character')..add(inner);
    pivot.position = vm.Vector3(
      walker.position.x,
      IslandDimensions.groundY,
      walker.position.z,
    );
    scene.add(pivot);
    _characterPivot = pivot;

    final idle = model.findAnimationByName('idle');
    final walk = model.findAnimationByName('walk');
    if (idle != null) {
      _idleClip = model.createAnimationClip(idle)
        ..loop = true
        ..weight = 1.0
        ..play();
    }
    if (walk != null) {
      _walkClip = model.createAnimationClip(walk)
        ..loop = true
        ..weight = 0.0
        ..play();
    }
  }

  static const double _characterScale = 0.2;

  // ------------------------------------------------------------------ input

  /// Handles a tap at [localPosition] inside a view of [viewSize] *logical*
  /// pixels — the same coordinate space `SceneView` lays out in.
  ///
  /// Returns the picked world point, or null when the tap landed on the sky.
  vm.Vector3? tapAt(ui.Offset localPosition, ui.Size viewSize) {
    final hit = groundPointAt(localPosition, viewSize);
    if (hit == null) {
      return null;
    }
    final point = clampToIsland(hit, radius: IslandDimensions.walkableRadius);
    walker.moveTo(point);
    _marker?.pingAt(point);
    return point;
  }

  /// The raw, UNCLAMPED point where a tap meets the ground plane, or null when
  /// the tap landed on the sky. Exposed so the debug probe can check the
  /// unprojection itself rather than the clamp.
  vm.Vector3? groundPointAt(ui.Offset localPosition, ui.Size viewSize) {
    if (!_loaded || viewSize.isEmpty) {
      return null;
    }
    return intersectGroundPlane(
      camera.screenPointToRay(localPosition, viewSize),
      planeY: IslandDimensions.groundY,
    );
  }

  // ------------------------------------------------------------------- tick

  /// Advances everything this class owns by [deltaSeconds]. The scene's own
  /// components (camera orbit, day/night) are ticked by `Scene.render`.
  void tick(double deltaSeconds) {
    if (!_loaded) {
      return;
    }
    _applyLighting();
    walker.advance(deltaSeconds);

    final pivot = _characterPivot;
    if (pivot != null) {
      pivot.position = vm.Vector3(
        walker.position.x,
        IslandDimensions.groundY,
        walker.position.z,
      );
      pivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), walker.yaw);
    }

    // Cross-fade idle <-> walk instead of hard-switching, so a short hop does
    // not pop.
    final wanted = walker.isMoving ? 1.0 : 0.0;
    final rate = math.min(1.0, deltaSeconds * 8.0);
    _walkBlend += (wanted - _walkBlend) * rate;
    _walkClip?.weight = _walkBlend;
    _idleClip?.weight = 1.0 - _walkBlend;

    _marker?.advance(deltaSeconds);
  }

  /// Applies the day/night model's evaluated lighting, with two departures
  /// from what `DayNightCycleComponent` would do on its own: the ambient term
  /// keeps a floor so dusk does not fall off a cliff, and the moon fades in as
  /// the sun goes down.
  void _applyLighting() {
    final lighting = dayNight.evaluateLighting();
    sunLight.color = lighting.sunColor;
    sunLight.intensity = lighting.sunIntensity;
    sunLight.castsShadow = lighting.shadowDarkness > 0.0;
    sunLight.shadowAmbientStrength = (1.0 - lighting.shadowDarkness).clamp(
      0.0,
      1.0,
    );
    scene.environmentIntensity = math.max(
      lighting.environmentIntensity,
      0.25,
    );
    moonLight.intensity = 0.78 * nightBlend;
  }

  // ------------------------------------------------------------- statistics

  void _recount() {
    var triangles = 0;
    var draws = 0;
    void visit(Node node) {
      if (node.visible) {
        final mesh = node.mesh;
        if (mesh != null) {
          for (final primitive in mesh.primitives) {
            draws += 1;
            triangles += _trianglesOf(primitive.geometry);
          }
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(scene.root);
    triangleCount = triangles;
    drawCallCount = draws;
  }

  int _trianglesOf(Geometry geometry) {
    final cached = _triangleCache[geometry];
    if (cached != null) {
      return cached;
    }
    var count = 0;
    if (geometry.isReadable) {
      try {
        count = geometry.extractMeshData().triangleCount;
      } on StateError catch (error) {
        debugPrint('island scene: could not count triangles: $error');
      }
    }
    _triangleCache[geometry] = count;
    return count;
  }

  // ------------------------------------------------------------------ utils

  /// Rewrites imported materials so they respond to the sun.
  ///
  /// Two problems, both silent: Kenney's glTF exports declare `metallic 1 /
  /// roughness 1` (black under PBR), and the character declares
  /// `KHR_materials_unlit`, which imports as an [UnlitMaterial] that day/night
  /// lighting cannot touch at all.
  void _relightImportedMaterials(Node node) {
    final mesh = node.mesh;
    if (mesh != null) {
      for (final primitive in mesh.primitives) {
        final material = primitive.material;
        if (material is PhysicallyBasedMaterial) {
          material.metallicFactor = 0.0;
          material.roughnessFactor = math.max(material.roughnessFactor, 0.75);
        } else if (material is UnlitMaterial) {
          primitive.material = PhysicallyBasedMaterial()
            ..baseColorTexture = material.baseColorTexture
            ..baseColorFactor = material.baseColorFactor
            ..metallicFactor = 0.0
            ..roughnessFactor = 0.85;
        }
      }
    }
    for (final child in node.children) {
      _relightImportedMaterials(child);
    }
  }
}

class _Placement {
  const _Placement(this.kind, this.x, this.z, this.yaw, this.scale);

  final String kind;
  final double x;
  final double z;
  final double yaw;
  final double scale;
}

/// The expanding ring dropped where the presenter tapped.
///
/// A 3D ring lying on the ground, not a 2D marker: it has to sit in the scene
/// and track the camera, or it proves nothing about the render being live.
class _TapMarker {
  _TapMarker(Scene scene) {
    _material = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, 0.0);
    _node = Node(
      name: 'tap_marker',
      mesh: Mesh(
        RingGeometry(innerRadius: 0.34, outerRadius: 0.42, segments: 48),
        _material,
      ),
    );
    _node.castsShadows = false;
    _node.visible = false;
    scene.add(_node);
  }

  static const double _lifetime = 0.85;

  late final Node _node;
  late final UnlitMaterial _material;
  double _age = _lifetime;

  void pingAt(vm.Vector3 point) {
    _age = 0;
    _node.visible = true;
    _node.position = vm.Vector3(
      point.x,
      IslandDimensions.groundY + 0.03,
      point.z,
    );
  }

  void advance(double deltaSeconds) {
    if (_age >= _lifetime) {
      return;
    }
    _age += deltaSeconds;
    final t = (_age / _lifetime).clamp(0.0, 1.0);
    if (t >= 1.0) {
      _node.visible = false;
      return;
    }
    final scale = 0.55 + t * 1.35;
    _node.scale = vm.Vector3.all(scale);
    _material.baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, (1.0 - t) * 0.9);
  }
}

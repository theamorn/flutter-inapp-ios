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
import 'package:flutter_module/tabs/scene/ball_physics.dart';
import 'package:flutter_module/tabs/scene/tap_to_move.dart';
import 'package:flutter_module/tabs/scene/water_bump.dart';
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

/// Modes for the 3D scene camera.
enum IslandCameraMode {
  /// Wide cinematic overview of the whole island with orbit controls.
  orbit,

  /// Immersive third-person chase camera situated over the character's right shoulder.
  overTheShoulder,
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

  late final PointLight campfireLight;
  late final Node campfireNode;
  late final Node _flameNode;
  late final PhysicallyBasedMaterial _flameMaterial;
  bool campfireLit = true;
  double _campfireIntensity = 1.0;
  double _flickerPhase = 0.0;

  late final Node cameraNode;
  late final CameraComponent _cameraComponent;
  late final OrbitCameraController orbit;

  IslandCameraMode _cameraMode = IslandCameraMode.orbit;
  IslandCameraMode get cameraMode => _cameraMode;

  final OtsCameraRig _otsRig = const OtsCameraRig();
  final FrustumCuller _culler = const FrustumCuller();
  final List<_PropInstance> _props = <_PropInstance>[];
  int culledMeshCount = 0;
  vm.Vector3? _otsEye;
  vm.Vector3? _otsTarget;
  double _otsOrbitAngle = 0.0;
  double _otsPitch = 0.0;

  /// The camera the [SceneView] renders through and the tap picks against.
  /// The same object, so a picked ray can never disagree with the image.
  Camera get camera => _cameraComponent.toCamera();

  final WalkerMotion walker = WalkerMotion(
    position: vm.Vector3(0, IslandDimensions.groundY, 1.1),
    speed: 1.9,
    groundY: IslandDimensions.groundY,
  );

  Node? _characterPivot;
  AnimationClip? _idleClip;
  AnimationClip? _walkClip;
  AnimationClip? _punchClip;
  double _walkBlend = 0;
  double _punchTimer = 0.0;
  static const double _punchDuration = 0.45;

  final BallPhysicsWorld physicsWorld = BallPhysicsWorld(
    groundY: IslandDimensions.groundY,
  );
  final List<Node> _ballNodes = <Node>[];
  final Map<int, Mesh> _ballMeshCache = <int, Mesh>{};

  late final Node _waterNode;
  late final PhysicallyBasedMaterial _normalSeaMaterial;
  late final PhysicallyBasedMaterial _ultraSeaMaterial;
  TextureSource? _waveNormalTexture;
  vm.Vector2 _waveOffset = vm.Vector2.zero();

  bool _ultraMode = false;
  bool get isUltraMode => _ultraMode;

  _TapMarker? _marker;

  /// Triangles submitted by the scene graph, counted at build time.
  int triangleCount = 0;

  /// Mesh primitives in the scene graph. Labelled "meshes" on screen, NOT
  /// "draw calls": each is one draw in the colour pass, but the shadow, sky
  /// and post passes issue more that flutter_scene does not expose. Calling
  /// this a draw-call count on stage would overstate what is measured, and
  /// every number in this demo has to survive being questioned.
  int meshCount = 0;

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
    _buildCampfireLighting();
    await _buildProps();
    await _buildCharacter();

    physicsWorld.setupBalls(1);
    _syncBallNodes();

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

    _applyEnvironmentSettings();
  }

  void _buildCampfireLighting() {
    campfireLight = PointLight(
      color: vm.Vector3(1.0, 0.52, 0.12),
      intensity: 5.2,
      range: 14.0,
      falloffExponent: 1.8,
    );
    campfireNode = Node(name: 'campfire_light')
      ..addComponent(PointLightComponent(campfireLight))
      ..position = vm.Vector3(0.0, 0.45, -0.15);
    scene.add(campfireNode);

    _flameMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(1.0, 0.4, 0.05, 1.0)
      ..emissiveFactor = vm.Vector4(1.0, 0.45, 0.1, 1.0)
      ..emissiveStrength = 4.5
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.2;
    _flameNode = Node(
      name: 'campfire_flame',
      mesh: Mesh(
        SphereGeometry(radius: 0.22, segments: 16, rings: 12),
        _flameMaterial,
      ),
    )..position = vm.Vector3(0.0, 0.32, -0.15);
    _flameNode.castsShadows = false;
    scene.add(_flameNode);
  }

  void toggleCampfire() {
    campfireLit = !campfireLit;
  }

  void _tickCampfire(double deltaSeconds) {
    _flickerPhase += deltaSeconds;
    final target = campfireLit ? 1.0 : 0.0;
    _campfireIntensity +=
        (target - _campfireIntensity) * math.min(1.0, deltaSeconds * 6.0);

    if (_campfireIntensity > 0.01) {
      _flameNode.visible = true;
      final flicker = 1.0 +
          0.20 * math.sin(_flickerPhase * 15.0) +
          0.10 * math.cos(_flickerPhase * 27.0);
      campfireLight.intensity = 5.5 * _campfireIntensity * flicker;
      final s = 0.22 * _campfireIntensity * flicker;
      _flameNode.scale = vm.Vector3(s, s * 1.25, s);
      _flameMaterial.emissiveStrength = 5.0 * _campfireIntensity * flicker;
    } else {
      _flameNode.visible = false;
      campfireLight.intensity = 0.0;
    }
  }

  Mesh _getBallMesh(int index) {
    return _ballMeshCache.putIfAbsent(index, () {
      final color = BallPhysicsWorld.ballPalettes[
          index % BallPhysicsWorld.ballPalettes.length];
      final mat = PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(color[0], color[1], color[2], color[3])
        ..metallicFactor = 0.05
        ..roughnessFactor = 0.30;
      return Mesh(
        SphereGeometry(radius: 0.32, segments: 24, rings: 16),
        mat,
      );
    });
  }

  void _syncBallNodes() {
    final needed = physicsWorld.balls.length;
    while (_ballNodes.length < needed) {
      final index = _ballNodes.length;
      final node = Node(
        name: 'physics_ball_$index',
        mesh: _getBallMesh(index),
      );
      node.castsShadows = true;
      scene.add(node);
      _ballNodes.add(node);
    }
    for (var i = 0; i < _ballNodes.length; i++) {
      _ballNodes[i].visible = i < needed;
    }
  }

  void setUltraMode(bool ultra) {
    if (_ultraMode == ultra) {
      return;
    }
    _ultraMode = ultra;
    physicsWorld.setupBalls(ultra ? 8 : 1);
    _syncBallNodes();
    _waterNode.mesh = Mesh(
      DiscGeometry(radius: IslandDimensions.seaRadius, segments: 64),
      ultra ? _ultraSeaMaterial : _normalSeaMaterial,
    );
    _applyEnvironmentSettings();
    if (_cameraMode == IslandCameraMode.orbit) {
      _recount();
    }
  }

  void resetBalls() {
    physicsWorld.setupBalls(_ultraMode ? 8 : 1);
    _syncBallNodes();
  }

  void _applyEnvironmentSettings() {
    if (_ultraMode) {
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        exposure: 0.82,
        colorGradingEnabled: true,
        saturation: 1.45,
        contrast: 1.2,
        brightness: 1.0,
        temperature: 0.1,
        bloomEnabled: true,
        bloomThreshold: 0.82,
        bloomIntensity: 0.44,
        bloomScatter: 0.82,
        vignetteEnabled: true,
        vignetteIntensity: 0.22,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionRadius: 0.45,
        ambientOcclusionIntensity: 1.3,
        ambientOcclusionSampleCount: 24,
        screenSpaceReflectionsEnabled: true,
        screenSpaceReflectionsMaxSteps: 90,
        godRaysEnabled: true,
        godRaysIntensity: 1.15,
        depthOfFieldEnabled: true,
        depthOfFieldQuality: DepthOfFieldQuality.medium,
      );
    } else {
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
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
        ambientOcclusionEnabled: false,
        screenSpaceReflectionsEnabled: false,
        godRaysEnabled: false,
        depthOfFieldEnabled: false,
      );
    }
  }

  // ---------------------------------------------------------------- terrain

  void _buildTerrain() {
    final grass = _flatMaterial(0.11, 0.40, 0.13, roughness: 0.92);
    final dirt = _flatMaterial(0.28, 0.15, 0.07, roughness: 0.95);
    _normalSeaMaterial = _flatMaterial(0.012, 0.10, 0.26, roughness: 0.16);

    // Procedural wave normal map texture for bump mapping and reflections in Ultra mode.
    final normalPixels = generateWaveNormalPixels(size: 128);
    _waveNormalTexture = Texture2D.fromPixels(
      normalPixels,
      128,
      128,
      content: TextureContent.normal,
      sampling: TextureSampling(
        mipmaps: true,
      ),
    );

    _ultraSeaMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.012, 0.12, 0.30, 1.0)
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.03
      ..specular = 1.0
      ..ior = 1.333
      ..normalTexture = _waveNormalTexture
      ..normalScale = 1.3
      ..normalTextureTransform = TextureTransform(
        scale: vm.Vector2(20.0, 20.0),
        offset: vm.Vector2.zero(),
      );

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

    final initialSeaMat = _ultraMode ? _ultraSeaMaterial : _normalSeaMaterial;
    _waterNode = Node(
      name: 'sea',
      mesh: Mesh(
        DiscGeometry(radius: IslandDimensions.seaRadius, segments: 64),
        initialSeaMat,
      ),
    )..position = vm.Vector3(0, IslandDimensions.seaY, 0);
    _waterNode.castsShadows = false;
    _waterNode.shadowStatic = false;
    scene.add(_waterNode);
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
        near: 0.15,
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
    cameraNode = Node(name: 'camera')
      ..addComponent(_cameraComponent)
      ..addComponent(orbit);
    scene.add(cameraNode);
    // Place the rig before the first frame. Without this the camera node is
    // still identity for one frame — at the origin, inside the island.
    orbit.update(0.0);
  }

  bool get _isOrbitAttached =>
      cameraNode.getComponent<OrbitCameraController>() != null;

  void _detachOrbit() {
    if (_isOrbitAttached) {
      cameraNode.removeComponent(orbit);
    }
  }

  void _attachOrbit() {
    if (!_isOrbitAttached) {
      cameraNode.addComponent(orbit);
      orbit.target = vm.Vector3(0, 0.2, 0);
      orbit.update(0.0);
    }
  }

  /// Sets the active camera perspective.
  void setCameraMode(IslandCameraMode mode) {
    if (_cameraMode == mode) return;
    _cameraMode = mode;
    if (mode == IslandCameraMode.overTheShoulder) {
      _detachOrbit();
      _otsEye = null;
      _otsTarget = null;
      _otsOrbitAngle = 0.0;
      _otsPitch = 0.0;
    } else {
      _attachOrbit();
      _restoreAllVisibility();
    }
  }

  void _restoreAllVisibility() {
    culledMeshCount = 0;
  }

  void _cullOffscreenNodes(ui.Size viewportSize) {
    if (_cameraMode != IslandCameraMode.overTheShoulder) {
      return;
    }
    final frustum = camera.getFrustum(viewportSize);
    var culled = 0;

    // flutter_scene natively culls off-screen nodes in its BVH during the
    // render pass (via `frustumCulled: true`). We count off-screen objects
    // here solely for the HUD readout without mutating `node.visible`,
    // which would invalidate DirectionalShadowCache on every frame and trigger
    // empty static shadow render passes that crash the Adreno Vulkan driver.
    for (final prop in _props) {
      final inView = _culler.isSphereVisible(
        frustum,
        prop.center,
        prop.radius,
      );
      if (!inView) {
        culled++;
      }
    }

    final needed = physicsWorld.balls.length;
    for (var i = 0; i < needed && i < _ballNodes.length; i++) {
      final ball = physicsWorld.balls[i];
      final inView = _culler.isSphereVisible(
        frustum,
        ball.position,
        ball.radius + 0.15,
      );
      if (!inView) {
        culled++;
      }
    }

    if (campfireLit && _campfireIntensity > 0.01) {
      final flameInView = _culler.isSphereVisible(
        frustum,
        _flameNode.position,
        0.8,
      );
      if (!flameInView) {
        culled++;
      }
    }

    culledMeshCount = culled;
  }

  /// Toggles between [IslandCameraMode.orbit] and [IslandCameraMode.overTheShoulder].
  void toggleCameraMode() {
    setCameraMode(
      _cameraMode == IslandCameraMode.orbit
          ? IslandCameraMode.overTheShoulder
          : IslandCameraMode.orbit,
    );
  }

  /// Rotates the over-the-shoulder camera around the character by dragging.
  void rotateOtsCamera(double deltaX, double deltaY) {
    if (_cameraMode != IslandCameraMode.overTheShoulder) return;
    _otsOrbitAngle -= deltaX * 0.007;
    _otsPitch = (_otsPitch - deltaY * 0.005).clamp(-0.25, 0.55);
  }

  void _tickOtsCamera(double deltaSeconds) {
    if (walker.isMoving) {
      final recenterRate = math.min(1.0, deltaSeconds * 3.5);
      _otsOrbitAngle += (0.0 - _otsOrbitAngle) * recenterRate;
      _otsPitch += (0.0 - _otsPitch) * recenterRate;
    }

    final totalYaw = walker.yaw + _otsOrbitAngle;
    final (targetEye, targetLookAt) = _otsRig.compute(
      characterPosition: walker.position,
      yaw: totalYaw,
      pitchOffset: _otsPitch,
      groundY: IslandDimensions.groundY,
    );

    if (_otsEye == null || _otsTarget == null) {
      _otsEye = targetEye.clone();
      _otsTarget = targetLookAt.clone();
    } else {
      final eyeSpeed = math.min(1.0, deltaSeconds * 12.0);
      final targetSpeed = math.min(1.0, deltaSeconds * 16.0);
      _otsEye!.x += (targetEye.x - _otsEye!.x) * eyeSpeed;
      _otsEye!.y += (targetEye.y - _otsEye!.y) * eyeSpeed;
      _otsEye!.z += (targetEye.z - _otsEye!.z) * eyeSpeed;

      _otsTarget!.x += (targetLookAt.x - _otsTarget!.x) * targetSpeed;
      _otsTarget!.y += (targetLookAt.y - _otsTarget!.y) * targetSpeed;
      _otsTarget!.z += (targetLookAt.z - _otsTarget!.z) * targetSpeed;
    }

    cameraNode.lookAtFrom(_otsEye!, _otsTarget!);
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

      final (heightOffset, radius) = switch (placement.kind) {
        'palm' => (1.8 * placement.scale, 2.6 * placement.scale),
        'pine' => (1.4 * placement.scale, 2.2 * placement.scale),
        'rockLarge' => (0.6 * placement.scale, 1.8 * placement.scale),
        'rockSmall' => (0.3 * placement.scale, 1.2 * placement.scale),
        'campfire' => (0.35 * placement.scale, 1.3 * placement.scale),
        _ => (0.5 * placement.scale, 1.4 * placement.scale),
      };

      _props.add(_PropInstance(
        node: instance,
        center: vm.Vector3(
          placement.x,
          IslandDimensions.groundY + heightOffset,
          placement.z,
        ),
        radius: radius,
      ));
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

    // The Kenney character model is 2.0 units tall. At 0.5 scale, it stands
    // 1.0m tall with shoulder/neck level at 0.8m, aligning with the 0.8m
    // over-the-shoulder camera elevation.
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
    final punch = model.findAnimationByName('attack-melee-right');
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
    if (punch != null) {
      _punchClip = model.createAnimationClip(punch)
        ..loop = false
        ..weight = 0.0;
    }
  }

  static const double _characterScale = 0.5;

  /// Performs a punch attack, playing the character's strike animation and
  /// flinging any nearby physics balls forward.
  int punch() {
    _punchTimer = _punchDuration;
    _punchClip?.replay();
    return physicsWorld.handleCharacterPunch(
      characterPosition: walker.position,
      characterYaw: walker.yaw,
    );
  }

  /// Initiates a jump arc for the character.
  bool jump() {
    return walker.jump();
  }

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

    // Check if the campfire in the center was tapped (x: 0.0, z: -0.15)
    final dxCamp = hit.x - 0.0;
    final dzCamp = hit.z - (-0.15);
    if (math.sqrt(dxCamp * dxCamp + dzCamp * dzCamp) <= 0.85) {
      toggleCampfire();
      _marker?.pingAt(vm.Vector3(0.0, IslandDimensions.groundY, -0.15));
      return hit;
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
  void tick(double deltaSeconds, {ui.Size? viewportSize}) {
    if (!_loaded) {
      return;
    }
    _applyLighting();
    walker.advance(deltaSeconds);
    _tickCampfire(deltaSeconds);

    final pivot = _characterPivot;
    if (pivot != null) {
      pivot.position = vm.Vector3(
        walker.position.x,
        walker.position.y,
        walker.position.z,
      );
      pivot.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), walker.yaw);
    }

    // Cross-fade idle <-> walk <-> punch
    final wanted = walker.isMoving ? 1.0 : 0.0;
    final rate = math.min(1.0, deltaSeconds * 8.0);
    _walkBlend += (wanted - _walkBlend) * rate;

    if (_punchTimer > 0) {
      _punchTimer -= deltaSeconds;
      final punchWeight = (_punchTimer / _punchDuration).clamp(0.0, 1.0);
      _punchClip?.advance(deltaSeconds);
      _punchClip?.weight = punchWeight;
      _walkClip?.weight = _walkBlend * (1.0 - punchWeight);
      _idleClip?.weight = (1.0 - _walkBlend) * (1.0 - punchWeight);
      if (_punchTimer <= 0) {
        _punchClip?.stop();
        _punchClip?.weight = 0.0;
      }
    } else {
      _walkClip?.weight = _walkBlend;
      _idleClip?.weight = 1.0 - _walkBlend;
    }

    // Step physics world and handle character kick
    physicsWorld.update(deltaSeconds);
    physicsWorld.handleCharacterKick(
      characterPosition: walker.position,
      characterRadius: 0.42,
      characterSpeed: walker.isMoving ? walker.speed : 0.0,
    );
    for (var i = 0;
        i < physicsWorld.balls.length && i < _ballNodes.length;
        i++) {
      final ball = physicsWorld.balls[i];
      _ballNodes[i].position = ball.position;
      _ballNodes[i].rotation = ball.rotation;
    }

    if (_ultraMode) {
      _waveOffset = vm.Vector2(
        (_waveOffset.x + deltaSeconds * 0.035) % 1.0,
        (_waveOffset.y + deltaSeconds * 0.022) % 1.0,
      );
      _ultraSeaMaterial.normalTextureTransform = TextureTransform(
        scale: vm.Vector2(20.0, 20.0),
        offset: _waveOffset,
      );
    }

    if (_cameraMode == IslandCameraMode.overTheShoulder) {
      _tickOtsCamera(deltaSeconds);
      _cullOffscreenNodes(viewportSize ?? const ui.Size(393, 852));
    }

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
    meshCount = draws;
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
    final alpha = (1.0 - t) * (1.0 - t);
    _material.baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, alpha * 0.95);
    final scale = 1.0 + t * 0.45;
    _node.scale = vm.Vector3(scale, 1.0, scale);
  }
}

class _PropInstance {
  const _PropInstance({
    required this.node,
    required this.center,
    required this.radius,
  });

  final Node node;
  final vm.Vector3 center;
  final double radius;
}

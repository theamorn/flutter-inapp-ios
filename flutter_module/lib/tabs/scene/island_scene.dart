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
import 'package:flutter_module/tabs/scene/island_components.dart';
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
  static const double topRadius = 10.5;

  /// Radius the character is allowed to reach — inside the rim, so it never
  /// stands half over the edge.
  static const double walkableRadius = 9.0;

  /// Height of the grass cap slab (its top face is [groundY]).
  static const double capHeight = 0.45;

  /// Radius and height of the dirt cone hanging below the cap.
  static const double coneBottomRadius = 1.65;
  static const double coneHeight = 3.0;

  /// Sea level. The cone pokes through it, so the island reads as land rather
  /// than as a floating rock.
  static const double seaY = -1.35;
  static const double seaRadius = 90.0;

  /// Campfire sits near the origin; tap, light, and the hull all share this.
  static const double campfireX = 0.0;
  static const double campfireZ = -0.45;
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
  ParticleEmitterComponent? _flameEmitter;
  Node? _flameEmitterNode;
  ParticleEmitterComponent? _smokeEmitter;
  Node? _smokeEmitterNode;
  ParticleEmitterComponent? _sparkEmitter;
  Node? _sparkEmitterNode;
  bool campfireLit = true;

  late final Node cameraNode;
  late final CameraComponent _cameraComponent;
  late final OrbitCameraController orbit;
  OtsCameraComponent? _otsCamera;

  IslandCameraMode _cameraMode = IslandCameraMode.orbit;
  IslandCameraMode get cameraMode => _cameraMode;

  final OtsCameraRig _otsRig = const OtsCameraRig();
  final FrustumCuller _culler = const FrustumCuller();
  int _cullHudFrame = 0;
  final List<_PropInstance> _props = <_PropInstance>[];
  final List<_PropInstance> _ultraProps = <_PropInstance>[];
  Node? _groundCoverRoot;
  Node? _ultraScatterRoot;
  Node? _sandRoot;
  Map<String, Node>? _propSources;
  int culledMeshCount = 0;
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

  final NpcSteeringMotion npcSteering = NpcSteeringMotion(
    position: vm.Vector3(-4.2, IslandDimensions.groundY, 3.6),
    maxSpeed: 1.4,
    groundY: IslandDimensions.groundY,
  );
  Node? _npcPivot;
  AnimationClip? _npcIdleClip;
  AnimationClip? _npcWalkClip;
  NpcWanderComponent? _npcWander;
  final math.Random _npcRandom = math.Random();
  Node? _flockRoot;
  SeagullFlockComponent? _flock;

  final BallPhysicsWorld physicsWorld = BallPhysicsWorld(
    groundY: IslandDimensions.groundY,
  );
  InstancedMesh? _ballBatch;
  Node? _ballRoot;
  NodePool? _debrisPool;
  Node? _debrisRoot;
  DebrisSimComponent? _debrisSim;
  final Map<Node, DebrisChipMotion> _debris = <Node, DebrisChipMotion>{};
  Mesh? _chipMesh;

  late final Node _waterNode;
  late final PhysicallyBasedMaterial _normalSeaMaterial;
  late final PhysicallyBasedMaterial _ultraSeaMaterial;
  WaterSurfaceComponent? _waterSurface;
  GerstnerDisplaceComponent? _waterDisplace;
  final List<_Buoy> _buoys = <_Buoy>[];

  bool _ultraMode = false;
  bool get isUltraMode => _ultraMode;

  TapMarkerComponent? _marker;
  CampfireFlickerComponent? _campfireFlicker;

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
  set timeOfDay(double value) {
    final next = value.clamp(0.0, 24.0);
    if (next == dayNight.timeOfDay) {
      return;
    }
    dayNight.timeOfDay = next;
    // Aim the sun and refresh IBL only when the clock actually moves. The
    // component is not ticked by Scene.render (see [_buildEnvironment]), so
    // an idle island does not dirty the light basis or rebake every frame.
    dayNight.update(0.0);
    scene.skyEnvironment?.invalidate();
    _applyLighting();
  }

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
    await _buildNpc();

    physicsWorld.setupBalls(1);
    _ensureBalls();

    final markerMaterial = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, 0.0);
    final markerNode = Node(
      name: 'tap_marker',
      mesh: Mesh(
        RingGeometry(innerRadius: 0.34, outerRadius: 0.42, segments: 48),
        markerMaterial,
      ),
    )
      ..castsShadows = false
      ..visible = false;
    _marker = TapMarkerComponent(markerMaterial);
    markerNode.addComponent(_marker!);
    scene.add(markerNode);
    // Aim the sun and the sky once before the first frame, for the same
    // reason as the camera above.
    dayNight.update(0.0);
    _applyLighting();
    _recount();
    _loaded = true;
  }

  // ---------------------------------------------------------------- sky/sun

  void _buildEnvironment() {
    scene.skybox = Skybox(sky);
    // Manual IBL: bake once on bind, then only when [timeOfDay] changes.
    // `interval` rebake (even at 200ms) keeps a SkyBakeJob in flight on an
    // idle clock and showed up as raster jank on device (release gfxinfo:
    // 55% missed deadlines, GPU p50 17ms).
    scene.skyEnvironment = SkyEnvironment(
      sky,
      refresh: SkyEnvironmentRefresh.manual,
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
      shadowCascadeCount: 1,
      shadowMapResolution: 512,
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
    // Do not mount this on the graph. Its update() rewrites the sun node's
    // transform every frame even at timeSpeed 0, which trips
    // DirectionalShadowCache's light-basis check and rebuilds static shadow
    // tiles. [timeOfDay] calls update() when the clock actually moves.

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
      ..position = vm.Vector3(
        IslandDimensions.campfireX,
        0.45,
        IslandDimensions.campfireZ,
      );
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
    )..position = vm.Vector3(
        IslandDimensions.campfireX,
        0.32,
        IslandDimensions.campfireZ,
      );
    _flameNode.castsShadows = false;
    scene.add(_flameNode);

    _flameEmitter = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 20,
        shape: const ConeEmitterShape(angle: 0.38, radius: 0.07),
        spawner: Spawner(rate: 16),
        modules: <ParticleModule>[
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(1.0, 0.88, 0.28, 1.0)),
                ColorStop(0.28, vm.Vector4(1.0, 0.42, 0.06, 0.95)),
                ColorStop(0.7, vm.Vector4(0.18, 0.04, 0.01, 0.28)),
                ColorStop(1.0, vm.Vector4(0.0, 0.0, 0.0, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(ParticleCurve.linear(from: 1.0, to: 0.12)),
          ),
        ],
        lifetime: const UniformFloat(0.35, 0.7),
        startSpeed: const UniformFloat(0.85, 1.55),
        startSize: const UniformFloat(0.11, 0.2),
        gravity: vm.Vector3(0, 0.55, 0),
        prewarm: 0.7,
      ),
      material: SpriteMaterial()..blendMode = SpriteBlendMode.additive,
    )..paused = true;
    _flameEmitterNode = Node(name: 'campfire_particles')
      ..position = vm.Vector3(
        IslandDimensions.campfireX,
        0.28,
        IslandDimensions.campfireZ,
      )
      ..visible = false
      ..castsShadows = false
      ..addComponent(_flameEmitter!);
    scene.add(_flameEmitterNode!);

    _smokeEmitter = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 8,
        shape: const ConeEmitterShape(angle: 0.2, radius: 0.05),
        spawner: Spawner(rate: 6),
        modules: <ParticleModule>[
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(0.55, 0.52, 0.48, 0.35)),
                ColorStop(0.45, vm.Vector4(0.32, 0.32, 0.34, 0.22)),
                ColorStop(1.0, vm.Vector4(0.18, 0.18, 0.2, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(ParticleCurve.linear(from: 1.0, to: 2.4)),
          ),
        ],
        lifetime: const UniformFloat(1.1, 1.9),
        startSpeed: const UniformFloat(0.32, 0.55),
        startSize: const UniformFloat(0.2, 0.36),
        gravity: vm.Vector3(0, 0.38, 0),
        prewarm: 1.6,
      ),
      material: SpriteMaterial()..blendMode = SpriteBlendMode.alpha,
    )..paused = true;
    _smokeEmitterNode = Node(name: 'campfire_smoke')
      ..position = vm.Vector3(
        IslandDimensions.campfireX,
        0.42,
        IslandDimensions.campfireZ,
      )
      ..visible = false
      ..castsShadows = false
      ..addComponent(_smokeEmitter!);
    scene.add(_smokeEmitterNode!);

    _sparkEmitter = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 4,
        shape: const ConeEmitterShape(angle: 0.55, radius: 0.03),
        spawner: Spawner(rate: 6),
        modules: <ParticleModule>[
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(1.0, 0.85, 0.35, 1.0)),
                ColorStop(0.5, vm.Vector4(1.0, 0.35, 0.05, 0.8)),
                ColorStop(1.0, vm.Vector4(0.1, 0.02, 0.0, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(ParticleCurve.linear(from: 1.0, to: 0.05)),
          ),
        ],
        lifetime: const UniformFloat(0.22, 0.45),
        startSpeed: const UniformFloat(1.6, 2.8),
        startSize: const UniformFloat(0.035, 0.06),
        gravity: vm.Vector3(0, -1.4, 0),
        prewarm: 0.4,
      ),
      material: SpriteMaterial()..blendMode = SpriteBlendMode.additive,
    )..paused = true;
    _sparkEmitterNode = Node(name: 'campfire_sparks')
      ..position = vm.Vector3(
        IslandDimensions.campfireX,
        0.34,
        IslandDimensions.campfireZ,
      )
      ..visible = false
      ..castsShadows = false
      ..addComponent(_sparkEmitter!);
    scene.add(_sparkEmitterNode!);

    _campfireFlicker = CampfireFlickerComponent(
      light: campfireLight,
      flameNode: _flameNode,
      flameMaterial: _flameMaterial,
      isLit: () => campfireLit,
      isUltra: () => _ultraMode,
      flameEmitter: _flameEmitter,
      flameEmitterNode: _flameEmitterNode,
      smokeEmitter: _smokeEmitter,
      smokeEmitterNode: _smokeEmitterNode,
      sparkEmitter: _sparkEmitter,
      sparkEmitterNode: _sparkEmitterNode,
    );
    campfireNode.addComponent(_campfireFlicker!);
  }

  void toggleCampfire() {
    campfireLit = !campfireLit;
  }

  void _ensureBalls() {
    _ballBatch ??= InstancedMesh(
      geometry: SphereGeometry(radius: 0.32, segments: 24, rings: 16),
      material: PhysicallyBasedMaterial()
        ..metallicFactor = 0.05
        ..roughnessFactor = 0.30,
    );
    if (_ballRoot == null) {
      _ballRoot = Node(name: 'physics_balls')
        ..castsShadows = true
        ..addComponent(InstancedMeshComponent(_ballBatch!))
        ..addComponent(
          PhysicsBallVisualComponent(
            world: physicsWorld,
            batch: _ballBatch!,
          ),
        );
      scene.add(_ballRoot!);
    }
    _fillBallInstances();
  }

  void _syncBallInstances() {
    if (_ballBatch == null) {
      _ensureBalls();
      return;
    }
    _fillBallInstances();
  }

  void _fillBallInstances() {
    final batch = _ballBatch!;
    batch.clearInstances();
    for (var i = 0; i < physicsWorld.balls.length; i++) {
      final color = BallPhysicsWorld.ballPalettes[
          i % BallPhysicsWorld.ballPalettes.length];
      final ball = physicsWorld.balls[i];
      batch.addInstance(
        vm.Matrix4.compose(
          ball.position,
          ball.rotation,
          vm.Vector3.all(1.0),
        ),
        color: vm.Vector4(color[0], color[1], color[2], color[3]),
      );
    }
  }

  void setUltraMode(bool ultra) {
    if (_ultraMode == ultra) {
      return;
    }
    _ultraMode = ultra;
    physicsWorld.setupBalls(ultra ? 8 : 1);
    physicsWorld.replaceUltraObstacles(const <IslandObstacle>[]);
    _syncBallInstances();
    _syncUltraProps(ultra);
    _syncUltraGroundCover(ultra);
    _syncUltraSand(ultra);
    _syncUltraWater(ultra);
    _syncNpc(ultra);
    _syncFlock(ultra);
    if (!ultra) {
      _clearDebris();
    } else {
      _ensureDebrisPool();
    }
    _applyEnvironmentSettings();
    if (_cameraMode == IslandCameraMode.orbit) {
      _recount();
    }
  }

  void resetBalls() {
    physicsWorld.setupBalls(_ultraMode ? 8 : 1);
    _syncBallInstances();
  }

  void _applyEnvironmentSettings() {
    sunLight.shadowCascadeCount = 1;
    sunLight.shadowMapResolution = 512;
    sunLight.shadowMaxDistance = 24.0;
    if (_ultraMode) {
      scene.renderScale = 0.85;
      scene.antiAliasingMode = AntiAliasingMode.msaa;
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        colorGradingEnabled: true,
        saturation: 1.25,
        contrast: 1.1,
        brightness: 1.05,
        temperature: 0.1,
        bloomEnabled: true,
        bloomThreshold: 1.2,
        bloomIntensity: 0.12,
        bloomScatter: 0.4,
        lensFlareEnabled: false,
        vignetteEnabled: true,
        vignetteIntensity: 0.2,
        exposure: 0.82,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.obscurance,
        ambientOcclusionHalfResolution: true,
        ambientOcclusionIntensity: 1.0,
        screenSpaceReflectionsEnabled: true,
        screenSpaceReflectionsIntensity: 1.0,
        screenSpaceReflectionsMaxDistance: 28.0,
        screenSpaceReflectionsMaxSteps: 24,
        screenSpaceReflectionsResolutionScale: 0.4,
      );
    } else {
      scene.renderScale = 0.75;
      scene.antiAliasingMode = AntiAliasingMode.auto;
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        colorGradingEnabled: true,
        saturation: 1.25,
        contrast: 1.1,
        brightness: 1.05,
        temperature: 0.1,
        bloomEnabled: true,
        bloomThreshold: 0.9,
        bloomIntensity: 0.28,
        bloomScatter: 0.8,
        vignetteEnabled: true,
        vignetteIntensity: 0.2,
        exposure: 0.8,
        ambientOcclusionEnabled: true,
        ambientOcclusionHalfResolution: true,
        ambientOcclusionIntensity: 0.8,
      );
    }
  }

  // ---------------------------------------------------------------- terrain

  void _buildTerrain() {
    final grass = _flatMaterial(0.11, 0.40, 0.13, roughness: 0.92);
    final dirt = _flatMaterial(0.28, 0.15, 0.07, roughness: 0.95);
    _normalSeaMaterial = _flatMaterial(0.012, 0.10, 0.26, roughness: 0.16);

    // Ultra sea stays shinier than Normal, but without a scrolling wave
    // normal map — that bump + SSR path was too expensive on device.
    _ultraSeaMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.012, 0.12, 0.30, 1.0)
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.03
      ..specular = 1.0
      ..ior = 1.333;

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
      distance: 40.0,
      azimuth: 0.55,
      polar: 0.62,
      minDistance: 20.0,
      maxDistance: 70.0,
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
    _otsCamera = OtsCameraComponent(
      rig: _otsRig,
      characterPosition: () => walker.position,
      characterYaw: () => walker.yaw,
      isMoving: () => walker.isMoving,
      orbitAngle: () => _otsOrbitAngle,
      pitch: () => _otsPitch,
      setOrbitAngle: (value) => _otsOrbitAngle = value,
      setPitch: (value) => _otsPitch = value,
      groundY: IslandDimensions.groundY,
    )..enabled = false;
    cameraNode.addComponent(_otsCamera!);
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
      _otsOrbitAngle = 0.0;
      _otsPitch = 0.0;
      _otsCamera?.resetSmoothing();
      _otsCamera?.enabled = true;
    } else {
      _otsCamera?.enabled = false;
      _attachOrbit();
      _restoreAllVisibility();
    }
    if (_ultraMode) {
      _applyEnvironmentSettings();
    }
  }

  void _restoreAllVisibility() {
    culledMeshCount = 0;
  }

  void _cullOffscreenNodes(ui.Size viewportSize) {
    if (_cameraMode != IslandCameraMode.overTheShoulder) {
      return;
    }
    _cullHudFrame = (_cullHudFrame + 1) & 7;
    if (_cullHudFrame != 0) {
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

    for (final ball in physicsWorld.balls) {
      final inView = _culler.isSphereVisible(
        frustum,
        ball.position,
        ball.radius + 0.15,
      );
      if (!inView) {
        culled++;
      }
    }

    if (campfireLit && (_campfireFlicker?.intensity ?? 0) > 0.01) {
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
    // XZ is the original layout scaled 3x so the same composition fills the
    // larger island in both modes.
    const placements = _normalPlacements;

    _propSources = <String, Node>{
      'palm': palm,
      'pine': pine,
      'rockLarge': rockLarge,
      'rockSmall': rockSmall,
      'campfire': campfire,
      'bush': bush,
    };

    for (final placement in placements) {
      _instantiatePlacement(placement, dest: _props);
    }
  }

  static const List<_Placement> _normalPlacements = <_Placement>[
    _Placement('palm', 6.15, -3.75, 0.7, 1.05),
    _Placement('palm', -6.75, 2.55, -2.1, 0.92),
    _Placement('palm', 1.35, -7.35, 2.4, 0.85),
    _Placement('pine', -4.65, -5.85, 1.2, 1.0),
    _Placement('pine', -1.65, -7.65, -0.35, 0.8),
    _Placement('pine', 7.05, 4.05, -1.9, 0.9),
    _Placement('rockLarge', 3.3, 5.85, 1.55, 1.0),
    _Placement('rockLarge', -7.8, -1.05, 1.35, 0.75),
    _Placement('rockSmall', 5.25, 1.65, -0.4, 1.0),
    _Placement('rockSmall', -3.45, 3.45, 2.6, 1.2),
    _Placement('rockSmall', 2.85, -2.25, -2.3, 0.9),
    _Placement(
      'campfire',
      IslandDimensions.campfireX,
      IslandDimensions.campfireZ,
      -0.15,
      1.3,
    ),
    _Placement('bush', 4.05, 7.05, 0.9, 1.1),
    _Placement('bush', -6.15, 5.55, 2.2, 0.9),
    _Placement('bush', 8.25, -1.35, -1.1, 1.0),
    _Placement('bush', -2.55, -3.15, 0.4, 0.8),
  ];

  static const List<String> _ultraScatterKinds = <String>[
    'palm',
    'pine',
    'bush',
    'rockSmall',
    'palm',
    'pine',
    'bush',
    'rockLarge',
  ];

  void _instantiatePlacement(
    _Placement placement, {
    required List<_PropInstance> dest,
  }) {
    final sources = _propSources;
    if (sources == null) {
      return;
    }
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

    dest.add(_PropInstance(
      node: instance,
      center: vm.Vector3(
        placement.x,
        IslandDimensions.groundY + heightOffset,
        placement.z,
      ),
      radius: radius,
    ));
  }

  void _syncUltraProps(bool ultra) {
    if (!ultra) {
      _ultraScatterRoot?.detach();
      _ultraScatterRoot = null;
      for (final prop in _ultraProps) {
        _props.remove(prop);
      }
      _ultraProps.clear();
      physicsWorld.replaceUltraObstacles(const <IslandObstacle>[]);
      return;
    }
    if (_ultraProps.isNotEmpty || _propSources == null) {
      return;
    }
    const radius = IslandDimensions.walkableRadius;
    final samples = PoissonDiscSampler.sampleRect(
      radius * 2,
      radius * 2,
      2.35,
      seed: 47,
    );
    final occupied = <vm.Vector2>[
      for (final placement in _normalPlacements)
        vm.Vector2(placement.x, placement.z),
    ];
    final points = filterIslandScatterPoints(
      samples: samples,
      rectOrigin: radius,
      walkableRadius: radius,
      campfire: vm.Vector2(
        IslandDimensions.campfireX,
        IslandDimensions.campfireZ,
      ),
      campfireAvoidRadius: 1.6,
      occupied: occupied,
      occupiedRadius: 1.6,
      maxCount: 20,
    );
    final hulls = <IslandObstacle>[];
    final byKind = <String, List<_Placement>>{};
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final kind = _ultraScatterKinds[i % _ultraScatterKinds.length];
      final yaw = (i * 2.399) % (math.pi * 2.0);
      final scale = 0.82 + (i % 5) * 0.06;
      byKind.putIfAbsent(kind, () => <_Placement>[]).add(
            _Placement(kind, point.x, point.y, yaw, scale),
          );
      hulls.add(
        IslandObstacle(
          name: 'ultra_$i',
          x: point.x,
          z: point.y,
          radius: switch (kind) {
            'rockLarge' => 0.6,
            'rockSmall' => 0.4,
            _ => 0.35,
          },
        ),
      );
    }

    final root = Node(name: 'ultra_scatter');
    root.shadowStatic = true;
    for (final entry in byKind.entries) {
      _addInstancedKind(root, entry.key, entry.value);
    }
    scene.add(root);
    _ultraScatterRoot = root;

    for (final entry in byKind.entries) {
      for (final placement in entry.value) {
        final (heightOffset, radiusHull) = switch (placement.kind) {
          'palm' => (1.8 * placement.scale, 2.6 * placement.scale),
          'pine' => (1.4 * placement.scale, 2.2 * placement.scale),
          'rockLarge' => (0.6 * placement.scale, 1.8 * placement.scale),
          'rockSmall' => (0.3 * placement.scale, 1.2 * placement.scale),
          _ => (0.5 * placement.scale, 1.4 * placement.scale),
        };
        _ultraProps.add(
          _PropInstance(
            node: root,
            center: vm.Vector3(
              placement.x,
              IslandDimensions.groundY + heightOffset,
              placement.z,
            ),
            radius: radiusHull,
          ),
        );
      }
    }
    physicsWorld.replaceUltraObstacles(hulls);
    _props.addAll(_ultraProps);
  }

  void _addInstancedKind(Node root, String kind, List<_Placement> placements) {
    final primitives = _flattenMeshPrimitives(_propSources?[kind]);
    if (primitives.isEmpty) {
      return;
    }
    for (final primitive in primitives) {
      final batch = InstancedMesh(
        geometry: primitive.geometry,
        material: primitive.material,
      );
      for (final placement in placements) {
        final model = vm.Matrix4.compose(
          vm.Vector3(
            placement.x,
            IslandDimensions.groundY,
            placement.z,
          ),
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), placement.yaw),
          vm.Vector3.all(placement.scale),
        )..multiply(primitive.local);
        batch.addInstance(model);
      }
      root.addComponent(InstancedMeshComponent(batch));
    }
  }

  void _syncUltraGroundCover(bool ultra) {
    if (!ultra) {
      _groundCoverRoot?.detach();
      _groundCoverRoot = null;
      return;
    }
    if (_groundCoverRoot != null) {
      return;
    }

    const radius = IslandDimensions.walkableRadius;
    final occupied = <vm.Vector2>[
      for (final placement in _normalPlacements)
        vm.Vector2(placement.x, placement.z),
      for (final prop in _ultraProps) vm.Vector2(prop.center.x, prop.center.z),
    ];
    final samples = PoissonDiscSampler.sampleRect(
      radius * 2,
      radius * 2,
      1.05,
      seed: 91,
    );
    final points = filterIslandScatterPoints(
      samples: samples,
      rectOrigin: radius,
      walkableRadius: radius - 0.35,
      campfire: vm.Vector2(
        IslandDimensions.campfireX,
        IslandDimensions.campfireZ,
      ),
      campfireAvoidRadius: 1.8,
      occupied: occupied,
      occupiedRadius: 1.35,
      maxCount: 32,
      innerClearRadius: 3.2,
    );

    final primitives = _flattenMeshPrimitives(_propSources?['bush']);
    if (primitives.isEmpty) {
      primitives.add(
        (
          geometry: CylinderGeometry(
            bottomRadius: 0.22,
            topRadius: 0.05,
            height: 0.62,
            radialSegments: 8,
          ),
          material: _flatMaterial(0.12, 0.34, 0.14, roughness: 0.94),
          local: vm.Matrix4.translation(vm.Vector3(0, 0.31, 0)),
        ),
      );
    }

    final root = Node(name: 'ultra_ground_cover');
    root.shadowStatic = true;
    root.castsShadows = false;

    for (final primitive in primitives) {
      final batch = InstancedMesh(
        geometry: primitive.geometry,
        material: primitive.material,
      );
      for (var i = 0; i < points.length; i++) {
        final point = points[i];
        final yaw = (i * 1.618) % (math.pi * 2.0);
        final scale = 0.42 + (i % 5) * 0.055;
        final tint = 0.88 + (i % 4) * 0.05;
        final model = vm.Matrix4.compose(
          vm.Vector3(point.x, IslandDimensions.groundY, point.y),
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw),
          vm.Vector3.all(scale),
        )..multiply(primitive.local);
        batch.addInstance(
          model,
          color: vm.Vector4(tint * 0.92, tint, tint * 0.82, 1.0),
        );
      }
      root.addComponent(InstancedMeshComponent(batch));
    }

    scene.add(root);
    _groundCoverRoot = root;
  }

  void _syncUltraSand(bool ultra) {
    if (!ultra) {
      _sandRoot?.detach();
      _sandRoot = null;
      return;
    }
    if (_sandRoot != null) {
      return;
    }

    final dry = _flatMaterial(0.76, 0.61, 0.38, roughness: 0.9);
    final wet = _flatMaterial(0.48, 0.36, 0.24, roughness: 0.42);
    const collarHeight = 0.42;

    final beach = Node(
      name: 'sand_beach',
      mesh: Mesh(
        RingGeometry(
          innerRadius: IslandDimensions.walkableRadius - 0.55,
          outerRadius: IslandDimensions.topRadius + 0.08,
          segments: 48,
        ),
        dry,
      ),
    )
      ..position = vm.Vector3(0, IslandDimensions.groundY + 0.012, 0)
      ..shadowStatic = true;

    final collar = Node(
      name: 'sand_collar',
      mesh: Mesh(
        CylinderGeometry(
          bottomRadius: IslandDimensions.topRadius - 0.28,
          topRadius: IslandDimensions.topRadius + 0.06,
          height: collarHeight,
          radialSegments: 48,
          bottomCap: false,
          topCap: false,
        ),
        wet,
      ),
    )
      ..position = vm.Vector3(
        0,
        IslandDimensions.groundY - collarHeight / 2 + 0.02,
        0,
      )
      ..shadowStatic = true;

    final root = Node(name: 'ultra_sand')
      ..add(beach)
      ..add(collar)
      ..shadowStatic = true;
    scene.add(root);
    _sandRoot = root;
  }

  List<({Geometry geometry, Material material, vm.Matrix4 local})>
      _flattenMeshPrimitives(Node? root) {
    final out = <({Geometry geometry, Material material, vm.Matrix4 local})>[];
    if (root == null) {
      return out;
    }
    void visit(Node node, vm.Matrix4 parent) {
      final local = parent * node.localTransform;
      final mesh = node.mesh;
      if (mesh != null) {
        for (final primitive in mesh.primitives) {
          out.add((
            geometry: primitive.geometry,
            material: primitive.material,
            local: local.clone(),
          ));
        }
      }
      for (final child in node.children) {
        visit(child, local);
      }
    }

    visit(root, vm.Matrix4.identity());
    return out;
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

  Future<void> _buildNpc() async {
    final model = await loadScene('assets/models/character.glb');
    _relightImportedMaterials(model);

    final inner = Node(name: 'npc_model')
      ..add(model)
      ..scale = vm.Vector3.all(_characterScale)
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);

    final pivot = Node(name: 'npc')..add(inner);
    pivot.position = vm.Vector3(
      npcSteering.position.x,
      IslandDimensions.groundY,
      npcSteering.position.z,
    );
    pivot.visible = false;
    scene.add(pivot);
    _npcPivot = pivot;

    final idle = model.findAnimationByName('idle');
    final walk = model.findAnimationByName('walk');
    if (idle != null) {
      _npcIdleClip = model.createAnimationClip(idle)
        ..loop = true
        ..weight = 1.0
        ..play();
    }
    if (walk != null) {
      _npcWalkClip = model.createAnimationClip(walk)
        ..loop = true
        ..weight = 0.0
        ..play();
    }
    _npcWander = NpcWanderComponent(
      motion: npcSteering,
      playerPosition: () => walker.position,
      isActive: () => _ultraMode,
      pickTarget: _pickNpcWanderTarget,
      walkableRadius: IslandDimensions.walkableRadius,
      campfire: vm.Vector3(
        IslandDimensions.campfireX,
        IslandDimensions.groundY,
        IslandDimensions.campfireZ,
      ),
      campfireAvoidRadius: 1.4,
      idleClip: _npcIdleClip,
      walkClip: _npcWalkClip,
    )..enabled = false;
    pivot.addComponent(_npcWander!);
  }

  void _syncNpc(bool ultra) {
    final wander = _npcWander;
    final pivot = _npcPivot;
    if (wander == null || pivot == null) {
      return;
    }
    wander.enabled = ultra;
    if (!ultra) {
      wander.stopAndHide();
      return;
    }
    wander.activate();
  }

  void _pickNpcWanderTarget() {
    final target = pickWanderTarget(
      random: _npcRandom,
      walkableRadius: IslandDimensions.walkableRadius,
      avoid: vm.Vector3(
        IslandDimensions.campfireX,
        IslandDimensions.groundY,
        IslandDimensions.campfireZ,
      ),
      avoidRadius: 1.4,
      groundY: IslandDimensions.groundY,
    );
    npcSteering.moveTo(target);
    _npcWander?.wanderTimer = 4.0 + _npcRandom.nextDouble() * 3.0;
  }

  void _syncFlock(bool ultra) {
    if (!ultra) {
      _flockRoot?.detach();
      _flockRoot = null;
      _flock = null;
      return;
    }
    if (_flockRoot != null) {
      return;
    }
    final feather = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.96, 0.97, 1.0, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.55;
    const count = 4;
    final batch = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3(3.2, 0.12, 0.9)),
      material: feather,
    );
    final birds = <FlockBirdMotion>[];
    final phases = <double>[];
    for (var i = 0; i < count; i++) {
      final angle = i / count * math.pi * 2.0;
      final radius = 11.4 + (i % 3) * 0.7;
      final height = 5.2 + (i % 4) * 0.45;
      final origin = vm.Vector3(
        math.sin(angle) * radius,
        height,
        math.cos(angle) * radius,
      );
      final tangent = vm.Vector3(math.cos(angle), 0, -math.sin(angle));
      birds.add(
        FlockBirdMotion(
          position: origin,
          velocity: tangent * 6.2,
          orbitRadius: radius,
          cruiseHeight: height,
        ),
      );
      phases.add(i * 0.9);
      batch.addInstance(
        vm.Matrix4.compose(origin, vm.Quaternion.identity(), vm.Vector3.all(1)),
      );
    }
    _flock = SeagullFlockComponent(
      batch: batch,
      birds: birds,
      phases: phases,
    );
    _flockRoot = Node(name: 'seagull_flock')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(batch))
      ..addComponent(_flock!);
    scene.add(_flockRoot!);
  }

  static const double _characterScale = 0.5;

  /// Performs a punch attack, playing the character's strike animation and
  /// flinging any nearby physics balls forward.
  int punch() {
    _punchTimer = _punchDuration;
    _punchClip?.replay();
    final hits = physicsWorld.handleCharacterPunch(
      characterPosition: walker.position,
      characterYaw: walker.yaw,
    );
    if (_ultraMode) {
      _spawnPunchDebris();
    }
    return hits;
  }

  /// Initiates a jump arc for the character.
  bool jump() {
    return walker.jump();
  }

  void _syncUltraWater(bool ultra) {
    if (!ultra) {
      final water = _waterSurface;
      if (water != null) {
        _waterNode.removeComponent(water);
      }
      final displace = _waterDisplace;
      if (displace != null) {
        _waterNode.removeComponent(displace);
        _waterDisplace = null;
      }
      _waterNode.mesh = Mesh(
        DiscGeometry(radius: IslandDimensions.seaRadius, segments: 64),
        _normalSeaMaterial,
      );
      for (final buoy in _buoys) {
        buoy.root.detach();
      }
      _buoys.clear();
      return;
    }
    _waterSurface ??= WaterSurfaceComponent(
      waves: <GerstnerWave>[
        GerstnerWave(
          direction: vm.Vector2(1.0, 0.2)..normalize(),
          amplitude: 0.16,
          wavelength: 14.0,
          speed: 1.0,
        ),
        GerstnerWave(
          direction: vm.Vector2(0.5, 0.8)..normalize(),
          amplitude: 0.08,
          wavelength: 7.0,
          speed: 1.4,
        ),
      ],
    );
    if (_waterNode.getComponent<WaterSurfaceComponent>() == null) {
      _waterNode.addComponent(_waterSurface!);
    }
    if (_waterDisplace == null) {
      final grid = buildSeaGrid(
        size: IslandDimensions.seaRadius * 2,
        segments: 16,
      );
      _waterDisplace = GerstnerDisplaceComponent(
        geometry: grid.geometry,
        restPositions: grid.rest,
        livePositions: grid.live,
        liveNormals: grid.normals,
      );
      _waterNode
        ..mesh = Mesh(grid.geometry, _ultraSeaMaterial)
        ..addComponent(_waterDisplace!);
    }
    if (_buoys.isNotEmpty) {
      return;
    }
    final crateMat = _flatMaterial(0.42, 0.28, 0.14, roughness: 0.86);
    final crateMesh = Mesh(
      CuboidGeometry(vm.Vector3(0.42, 0.32, 0.5)),
      crateMat,
    );
    const spots = <List<double>>[
      <double>[12.2, 1.8],
      <double>[-11.4, 4.6],
      <double>[8.6, -12.0],
      <double>[-13.0, -5.4],
    ];
    for (var i = 0; i < spots.length; i++) {
      final x = spots[i][0];
      final z = spots[i][1];
      final body = Node(
        name: 'buoy_body_$i',
        mesh: crateMesh,
      )
        ..castsShadows = false
        ..addComponent(
          FloatingMotionComponent(
            hoverAmplitude: 0.05,
            hoverFrequency: 0.55,
            wobbleDegrees: 7.0,
            wobbleFrequency: 0.7,
            spinSpeed: 0.35,
          ),
        );
      final root = Node(name: 'buoy_$i')
        ..position = vm.Vector3(x, IslandDimensions.seaY + 0.18, z)
        ..add(body)
        ..addComponent(
          BuoyFloatComponent(
            waterNode: _waterNode,
            x: x,
            z: z,
            seaY: IslandDimensions.seaY,
          ),
        );
      scene.add(root);
      _buoys.add(_Buoy(root: root));
    }
  }

  void _sitBallsOnWaves() {
    final water = _waterSurface;
    if (!_ultraMode || water == null) {
      return;
    }
    for (final ball in physicsWorld.balls) {
      final radius = math.sqrt(
        ball.position.x * ball.position.x + ball.position.z * ball.position.z,
      );
      if (radius <= IslandDimensions.walkableRadius) {
        continue;
      }
      final sample = water.evaluateAt(
        vm.Vector2(ball.position.x, ball.position.z),
      );
      final minY =
          IslandDimensions.seaY + sample.displacement.y + ball.radius;
      if (ball.position.y < minY) {
        ball.position.y = minY;
        if (ball.velocity.y < 0) {
          ball.velocity.y *= -0.18;
        }
      }
    }
  }

  void _ensureDebrisPool() {
    _debrisRoot ??= Node(name: 'ultra_debris')..castsShadows = false;
    if (_debrisRoot!.parent == null) {
      scene.add(_debrisRoot!);
    }
    _chipMesh ??= Mesh(
      CuboidGeometry(vm.Vector3(0.08, 0.05, 0.07)),
      _flatMaterial(0.38, 0.3, 0.22, roughness: 0.95),
    );
    _debrisPool ??= NodePool(
      () => Node(name: 'punch_chip', mesh: _chipMesh)
        ..castsShadows = false,
      initialSize: 8,
      maxSize: 16,
    );
    _debrisSim ??= DebrisSimComponent(
      debris: _debris,
      pool: () => _debrisPool,
      groundY: IslandDimensions.groundY,
    );
    if (_debrisRoot!.getComponent<DebrisSimComponent>() == null) {
      _debrisRoot!.addComponent(_debrisSim!);
    }
  }

  void _spawnPunchDebris() {
    _ensureDebrisPool();
    final pool = _debrisPool!;
    final parent = _debrisRoot!;
    final origin = vm.Vector3(
      walker.position.x,
      walker.position.y + 0.55,
      walker.position.z,
    );
    final forward = vm.Vector3(math.sin(walker.yaw), 0, math.cos(walker.yaw));
    for (var i = 0; i < 8; i++) {
      final node = pool.spawn(parent: parent);
      final sprayYaw = walker.yaw + (i - 3.5) * 0.18;
      final velocity = vm.Vector3(
        math.sin(sprayYaw) * (3.2 + i * 0.12) + forward.x * 1.4,
        2.4 + (i % 3) * 0.35,
        math.cos(sprayYaw) * (3.2 + i * 0.12) + forward.z * 1.4,
      );
      final motion = DebrisChipMotion(
        position: origin + forward * 0.35,
        velocity: velocity,
      );
      node.visible = true;
      node.position = motion.position;
      node.scale = vm.Vector3.all(0.7 + (i % 3) * 0.15);
      _debris[node] = motion;
    }
  }

  void _clearDebris() {
    final pool = _debrisPool;
    if (pool != null) {
      pool.despawnAll();
    }
    _debris.clear();
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

    // Check if the campfire in the center was tapped.
    final dxCamp = hit.x - IslandDimensions.campfireX;
    final dzCamp = hit.z - IslandDimensions.campfireZ;
    if (math.sqrt(dxCamp * dxCamp + dzCamp * dzCamp) <= 0.85) {
      toggleCampfire();
      _marker?.pingAt(
        vm.Vector3(
          IslandDimensions.campfireX,
          IslandDimensions.groundY,
          IslandDimensions.campfireZ,
        ),
        groundY: IslandDimensions.groundY,
      );
      return hit;
    }

    final point = clampToIsland(hit, radius: IslandDimensions.walkableRadius);
    walker.moveTo(point);
    _marker?.pingAt(point, groundY: IslandDimensions.groundY);
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

  /// Advances game-wide simulation. Per-object behaviour (campfire, NPC,
  /// flock, debris, OTS camera, water, tap marker) lives on Components.
  void tick(double deltaSeconds, {ui.Size? viewportSize}) {
    if (!_loaded) {
      return;
    }
    walker.advance(deltaSeconds);

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

    physicsWorld.update(deltaSeconds);
    physicsWorld.handleCharacterKick(
      characterPosition: walker.position,
      characterRadius: 0.42,
      characterSpeed: walker.isMoving ? walker.speed : 0.0,
    );
    _sitBallsOnWaves();

    if (_cameraMode == IslandCameraMode.overTheShoulder) {
      _cullOffscreenNodes(viewportSize ?? const ui.Size(393, 852));
    }
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
        for (final batch in node.getComponents<InstancedMeshComponent>()) {
          draws += 1;
          triangles +=
              _trianglesOf(batch.instancedMesh.geometry) *
              batch.instancedMesh.instanceCount;
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

class _Buoy {
  const _Buoy({required this.root});

  final Node root;
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

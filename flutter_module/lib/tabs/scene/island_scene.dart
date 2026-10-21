/// The island scene graph, camera rig, and day/night model for tab 5.
///
/// See `docs/island/06-island-scene.md`. Everything that touches
/// `flutter_scene` lives here; the tap-to-move maths is in `tap_to_move.dart`
/// (unit-testable, no GPU) and the 2D particle layer is in `particles.dart`.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/kit.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_module/tabs/scene/ball_physics.dart';
import 'package:flutter_module/tabs/scene/campfire_shadows.dart';
import 'package:flutter_module/tabs/scene/island_components.dart';
import 'package:flutter_module/tabs/scene/super_ultra/lightning.dart';
import 'package:flutter_module/tabs/scene/super_ultra/rain_collision.dart';
import 'package:flutter_module/tabs/scene/super_ultra/sky_path.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_effects.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_rig.dart';
import 'package:flutter_module/tabs/scene/super_ultra/transparency_order.dart';
import 'package:flutter_module/tabs/scene/tap_to_move.dart';
import 'package:flutter_module/tabs/scene/xray.dart';
import 'package:flutter_module/tabs/scene/render/prewarm.dart';
import 'package:flutter_module/tabs/scene/render/shockwave_apply.dart';
import 'package:flutter_module/tabs/scene/render/shockwave_pool.dart';
import 'package:flutter_module/tabs/scene/render/tree_sway.dart';
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

/// How much of the scene is switched on.
enum IslandQuality {
  /// One ball, the hand-placed props. The stage path.
  normal,

  /// Eight balls, scattered props, NPC, flock, buoys, CPU waves.
  ultra,

  /// Everything in [ultra], plus the headroom-spending look: sculpted shore
  /// and seabed, clear reflective water, grass, VFX fire, and a sky with a
  /// visible sun, moon and god rays. See `super_ultra/super_ultra_rig.dart`.
  superUltra,
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

  /// The daylight model [dayNight] aims. Not displayed and not baked into
  /// lighting in any mode (see [_buildEnvironment]); kept so the day/night
  /// component has a sky to steer, and as the reference Super Ultra's own sky
  /// is ported from.
  final PhysicalSkySource sky = PhysicalSkySource();

  /// Reused across every instance of a prop so triangles are counted once per
  /// *instance* but extracted once per *geometry*.
  final Map<Geometry, int> _triangleCache = <Geometry, int>{};

  late final DirectionalLight sunLight;
  late final Node sunNode;

  /// Super Ultra draws the sun on a low arc so it is in frame, but takes the
  /// light's colour and strength from this regular-latitude clock, so noon
  /// still looks like noon. Never mounted; kept in step with [dayNight].
  final DayNightCycleComponent _lightingClock = DayNightCycleComponent(
    timeOfDay: 10.5,
    latitude: _normalLatitude,
    applyLightingToTarget: false,
  );
  static const double _normalLatitude = 26.0;
  static final vm.Vector3 _normalMoonEye = vm.Vector3(-7, 9, 6);
  late final DirectionalLight moonLight;
  late final Node moonNode;
  late final DayNightCycleComponent dayNight;

  late final PointLight campfireLight;
  bool _campfireBuilt = false;
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

  /// Replaced (not mutated) when entering or leaving Super Ultra: the
  /// controller exposes no setters for its framing, so a fresh one is built
  /// at the current pose and eased to the new framing. Read it afresh after
  /// [setQuality].
  late OrbitCameraController orbit;
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
  late final Node _capNode;
  late final Node _coneNode;
  late final PhysicallyBasedMaterial _normalSeaMaterial;
  late final PhysicallyBasedMaterial _ultraSeaMaterial;
  WaterSurfaceComponent? _waterSurface;
  GerstnerDisplaceComponent? _waterDisplace;
  final List<_Buoy> _buoys = <_Buoy>[];

  IslandQuality _quality = IslandQuality.normal;
  IslandQuality get quality => _quality;
  bool get isUltraMode => _quality != IslandQuality.normal;
  bool get isSuperUltra => _quality == IslandQuality.superUltra;

  XrayMode _xray = XrayMode.off;
  double _xrayClock = 0;
  XrayMode get xray => _xray;

  /// Switches the X-ray view. Ultra and Super Ultra only (the button hides in
  /// Normal); leaving those modes switches it off.
  void setXray(XrayMode mode) {
    _xray = mode;
    _xrayClock = 0;
    final d = scene.debug;
    d.overlays.clear();
    d.splitOverlays.clear();
    d.view = switch (mode) {
      XrayMode.normals => const DebugView(
        channel: SurfaceDebugChannel.worldNormal,
      ),
      XrayMode.baseColor => const DebugView(
        channel: SurfaceDebugChannel.baseColor,
      ),
      _ => DebugView.none,
    };
    if (mode == XrayMode.wireframe) d.overlays.add(DebugOverlay.wireframe);
    d.split = mode == XrayMode.off ? null : xraySplit(0);
  }

  late final SuperUltraRig _superRig = SuperUltraRig(
    seaY: IslandDimensions.seaY,
    campfireBase: vm.Vector3(
      IslandDimensions.campfireX,
      IslandDimensions.groundY,
      IslandDimensions.campfireZ,
    ),
    playerPosition: () => walker.position,
    campfireIntensity: () => _campfireFlicker?.intensity ?? 0.0,
  );
  int _qualityRequest = 0;
  bool _buildingSuperUltra = false;

  /// True while Super Ultra's content is being built for the first time.
  bool get isBuildingSuperUltra => _buildingSuperUltra;

  /// Grass tufts on the lawn, for the readout. Zero outside Super Ultra.
  int get grassTufts => isSuperUltra ? _superRig.grassTufts : 0;

  bool _rainWanted = false;
  bool _preparingRain = false;
  bool _stormWanted = true;
  double _baseEnvironmentIntensity = 1.0;
  double _baseRainLight = 1.0;
  double _lastFlash = 0.0;

  /// Debug only (`SCENE_LIGHTNING_HOLD`): hold each strike at its peak for
  /// this many seconds so a screenshot can catch it.
  double debugLightningHoldSeconds = 0.0;

  /// Whether lightning strikes while it rains. On by default; off keeps the
  /// rain without any flashing (for photosensitive audiences, or to read the
  /// rain's cost on its own).
  bool get isStorm => _stormWanted;

  void setStorm(bool on) {
    _stormWanted = on;
    _superRig.lightning?.enabled = on;
  }

  /// How each imported tree material sways in the wind: palms bend more and
  /// their fronds flutter; bark bends with the tree but does not flutter.
  /// Bend and flutter are world metres, so they grow with [_treeScale].
  TreeSwayStyle? _treeSway(Material material) {
    final palm = _treeHeight('palm'), pine = _treeHeight('pine');
    const s = _treeScale;
    return switch (material.name) {
      'leafsGreen' => TreeSwayStyle(height: palm, bend: 0.35 * s, flutter: 0.05 * s),
      'woodBark' => TreeSwayStyle(height: palm, bend: 0.35 * s),
      'leafsDark' => TreeSwayStyle(height: pine, bend: 0.18 * s, flutter: 0.025 * s),
      'woodBarkDark' => TreeSwayStyle(height: pine, bend: 0.18 * s),
      _ => null,
    };
  }

  /// The top of the [kind] prop's meshes, in their own units.
  double _treeHeight(String kind) {
    var top = 0.0;
    void visit(Node n) {
      final bounds = n.mesh?.localBounds;
      if (bounds != null && bounds.max.y > top) top = bounds.max.y;
      n.children.forEach(visit);
    }

    final source = _propSources?[kind];
    if (source != null) visit(source);
    return top > 0 ? top : 3.0;
  }

  /// A short screen ripple per lightning strike in view (Super Ultra's
  /// "Lightning ripple" effect), plus trauma-based camera shake.
  final ShockwavePool _shockwaves = ShockwavePool();
  final CameraShake _cameraShake = CameraShake(
    decayRate: 1.8,
    frequency: 22.0,
    maxTranslation: vm.Vector3(0.09, 0.09, 0.05),
    maxRotation: vm.Vector3(0.018, 0.018, 0.012),
  );
  bool _orbitShakeActive = false;
  ui.Size? _viewport;

  void _onStrike(StrikeEvent event) {
    if (isSuperUltra) {
      final dist = math.sqrt(event.x * event.x + event.z * event.z);
      _cameraShake.addTrauma((0.48 - 0.006 * dist).clamp(0.28, 0.48));
    }
    final viewport = _viewport;
    if (viewport == null ||
        !isSuperUltra ||
        !isEffectOn(SuperUltraEffect.lightningRipple)) {
      return;
    }
    triggerStrike(_shockwaves, event, camera, viewport);
  }

  /// One ripple in the uncovered upper half of the screen (above the Effects
  /// sheet), to check the effect without waiting for a strike.
  void previewShockwave() {
    if (isSuperUltra && isEffectOn(SuperUltraEffect.lightningRipple)) {
      _shockwaves.preview(
        centerX: 0.5,
        centerY: 0.25,
        peakStrength: 0.038,
        pulseThickness: 0.095,
        pulseChromaticAberration: 0.6,
        pulseLifetime: 1.2,
      );
      _cameraShake.addTrauma(0.35);
    }
  }

  /// Drops every ripple and switches the distortion pass off (the scene was
  /// hidden, the rain stopped, the mode or the effect changed).
  void clearShockwaves() => clearSceneShockwaves(scene, _shockwaves);

  /// Lightning strikes so far, for the readout.
  int get lightningStrikes =>
      isSuperUltra ? (_superRig.lightning?.strikes ?? 0) : 0;

  /// 0 (dry) to 1 (full rain), eased toward the toggle over [_rainFade] s so
  /// the sky clouds over and the ground wets gradually.
  double _rainLevel = 0.0;
  static const double _rainFade = 2.5;
  double _skyRebakeIn = 0.0;
  final List<RainProp> _scatterRainProps = <RainProp>[];
  final List<RainProp> _coverRainProps = <RainProp>[];

  /// Whether rain is switched on. Rain only falls in Super Ultra; the choice
  /// is remembered across mode switches.
  bool get isRaining => _rainWanted;

  /// True while the rain is being built for the first time.
  bool get isPreparingRain => _preparingRain;

  /// Drops in flight, for the readout. Zero when it is not raining.
  int get rainDrops => isSuperUltra ? (_superRig.rain?.dropsInFlight ?? 0) : 0;

  /// Drops landing per second, for the readout.
  double get rainHitsPerSecond =>
      isSuperUltra ? (_superRig.rain?.hitsPerSecond ?? 0.0) : 0.0;

  /// Turns rain on or off.
  ///
  /// Only Super Ultra has rain: in other modes the choice is remembered and
  /// takes effect on entering it. The first time, the ground height grid the
  /// drops collide with is built on an isolate. Off fades the shower out and
  /// unmounts every rain node once the last drop has landed, so it then costs
  /// nothing.
  Future<void> setRain(bool on) async {
    _rainWanted = on;
    if (!on) clearShockwaves();
    if (on) {
      await _prepareRain();
    }
  }

  Future<void> _prepareRain() async {
    if (!isSuperUltra || !_superRig.isBuilt) {
      return;
    }
    if (_superRig.rain == null) {
      _preparingRain = true;
      try {
        await _superRig.ensureRain(
          props: <RainProp>[
            for (final placement in _normalPlacements)
              RainProp(placement.kind, placement.x, placement.z, placement.size),
            ..._scatterRainProps,
            ..._coverRainProps,
          ],
          fillDynamics: _fillRainDynamics,
          cameraPose: _cameraPose,
          lightningHoldSeconds: debugLightningHoldSeconds,
        );
        _superRig.lightning
          ?..enabled = _stormWanted
          ..onStrike = _onStrike;
      } finally {
        _preparingRain = false;
      }
    }
    if (_rainWanted && isSuperUltra) {
      _superRig.mountRain();
    }
  }

  /// Where the camera is and where it looks, for placing strikes in view.
  CameraPose _cameraPose() {
    final forward = cameraNode.forward;
    return (
      eye: cameraNode.globalTransform.getTranslation(),
      forward: forward.length2 > 0 ? forward : vm.Vector3(0, 0, 1),
    );
  }

  /// Carries the current lightning flash into the ambient light, the
  /// clouds, and the rain streaks (which briefly catch the light). The
  /// strike's own light and bolt are driven by the lightning itself.
  void _tickLightning() {
    final lightning = _superRig.lightning;
    if (lightning == null || !isSuperUltra) {
      return;
    }
    final flash = lightning.flash;
    if (flash <= 0.0 && _lastFlash <= 0.0) {
      return;
    }
    final lit = flash * lightning.strength;
    scene.environmentIntensity = _baseEnvironmentIntensity + 1.0 * lit;
    _superRig.setSkyFlash(lightning.strikeDirection, flash * (0.5 + 0.5 * lightning.strength));
    _superRig.rain?.setLight(_baseRainLight + 0.9 * lit);
    _lastFlash = flash;
    _applySuperUltraColorGrade(flash: lit);
  }

  /// The moving things rain lands on, refreshed every simulation step:
  /// the player and NPC as 1 m capsules, balls, and the floating crates.
  void _fillRainDynamics(RainDynamics dynamics) {
    dynamics.clear();
    final player = walker.position;
    dynamics.addCapsule(player.x, player.y, player.z, 0.22, 1.0);
    final npc = _npcPivot;
    if (npc != null && npc.visible) {
      final q = npcSteering.position;
      dynamics.addCapsule(q.x, q.y, q.z, 0.22, 1.0);
    }
    for (final ball in physicsWorld.balls) {
      dynamics.addSphere(
        ball.position.x,
        ball.position.y,
        ball.position.z,
        ball.radius,
      );
    }
    for (final buoy in _buoys) {
      final at = buoy.root.position;
      dynamics.addSphere(at.x, at.y, at.z, 0.3);
    }
  }

  /// Eases [_rainLevel] toward the toggle and carries it into the lighting,
  /// the shaders and the spawn rate; unmounts the rain once it has fully
  /// stopped.
  void _tickRain(double deltaSeconds) {
    final rain = _superRig.rain;
    if (rain == null) {
      return;
    }
    final target = _rainWanted && isSuperUltra ? 1.0 : 0.0;
    if (_rainLevel != target) {
      final step = deltaSeconds / _rainFade;
      _rainLevel = target > _rainLevel
          ? math.min(target, _rainLevel + step)
          : math.max(target, _rainLevel - step);
      rain.level = _rainLevel;
      _superRig.weather = _rainLevel;
      _applyLighting();
      // The sky's lighting bake follows the clouds, a few times per fade
      // rather than every frame.
      _skyRebakeIn -= deltaSeconds;
      if (_skyRebakeIn <= 0.0 || _rainLevel == target) {
        scene.skyEnvironment?.invalidate();
        _skyRebakeIn = 0.4;
      }
    }
    if (target == 0.0 && rain.isIdle) {
      _superRig.unmountRain();
    }
  }

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
    _lightingClock.timeOfDay = next;
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
    await Scene.preload(physicalMaterials: true, smaa: true);

    _buildEnvironment();
    _buildTerrain();
    _buildCamera();
    _buildCampfireLighting();
    await _buildProps();
    await _buildCharacter();
    await _buildNpc();
    await _buildFlock();

    physicsWorld.setupBalls(1);
    _ensureBalls();

    final markerMaterial = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..depthLayer = 1
      ..baseColorFactor = vm.Vector4(1.0, 0.95, 0.55, 0.0);
    final markerNode = Node(
      name: 'tap_marker',
      mesh: Mesh(
        RingGeometry(innerRadius: 0.34, outerRadius: 0.42, segments: 48),
        markerMaterial,
      ),
    )
      ..shadowCastingMode = ShadowCastingMode.off
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
    // Normal and Ultra set no skybox and no SkyEnvironment: they are lit by
    // the engine's default studio environment. That is what they have
    // actually shipped with. This method used to assign a physical sky here,
    // but [_applyEnvironmentSettings] replaced it with null on the next line
    // (see [_activeSkybox]), and both modes were tuned against the result.
    // Super Ultra brings its own sky; see `super_ultra_rig.dart`.

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
    moonNode.lookAtFrom(_normalMoonEye, vm.Vector3.zero());

    dayNight = DayNightCycleComponent(
      timeOfDay: 10.5,
      // 0 = presenter-driven. The slider is the clock; nothing runs on its own.
      timeSpeed: 0.0,
      latitude: _normalLatitude,
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
      radius: kCampfireLightRadius,
      shadowMapResolution: kCampfireShadowResolution,
      shadowNear: kCampfireShadowNear,
    );
    _campfireBuilt = true;
    _applyCampfireShadow();
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
    _flameNode.shadowCastingMode = ShadowCastingMode.off;
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
      ..shadowCastingMode = ShadowCastingMode.off
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
      ..shadowCastingMode = ShadowCastingMode.off
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
      ..shadowCastingMode = ShadowCastingMode.off
      ..addComponent(_sparkEmitter!);
    scene.add(_sparkEmitterNode!);

    _campfireFlicker = CampfireFlickerComponent(
      light: campfireLight,
      flameNode: _flameNode,
      flameMaterial: _flameMaterial,
      isLit: () => campfireLit,
      isUltra: () => isUltraMode,
      isSuperUltra: () => isSuperUltra && _superRig.isMounted,
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
        ..roughnessFactor = 0.28
        ..clearcoat = 0.65
        ..clearcoatRoughness = 0.08
        ..ior = 1.48,
    );
    if (_ballRoot == null) {
      _ballRoot = Node(name: 'physics_balls')
        ..shadowCastingMode = ShadowCastingMode.on
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

  /// Switches the scene to [quality].
  ///
  /// Super Ultra builds its content the first time (a second or two, mostly
  /// on background isolates). Until it is ready the scene shows Ultra, so the
  /// switch gives immediate feedback; [isBuildingSuperUltra] is true
  /// meanwhile. A later call supersedes one still waiting on the build.
  Future<void> setQuality(IslandQuality quality) async {
    final request = ++_qualityRequest;
    if (quality == IslandQuality.superUltra && !_superRig.isBuilt) {
      _applyQuality(IslandQuality.ultra);
      _buildingSuperUltra = true;
      try {
        // Built after Ultra's scatter exists, so the lawn avoids its props.
        await _superRig.ensureBuilt(obstacles: physicsWorld.obstacles);
      } finally {
        _buildingSuperUltra = false;
      }
      if (request != _qualityRequest) {
        return;
      }
    }
    _applyQuality(quality);
  }

  void _applyQuality(IslandQuality quality) {
    if (_quality == quality) {
      return;
    }
    final wasUltra = isUltraMode;
    final wasSuper = isSuperUltra;
    _quality = quality;
    clearShockwaves();
    if (quality == IslandQuality.normal && _xray != XrayMode.off) {
      setXray(XrayMode.off);
    }
    final ultra = isUltraMode;
    if (ultra != wasUltra) {
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
    }
    if (isSuperUltra != wasSuper) {
      _syncSuperUltra(isSuperUltra);
    }
    _applyEnvironmentSettings();
    if (isSuperUltra != wasSuper) {
      // The sky that comes back may have been baked for another hour.
      scene.skyEnvironment?.invalidate();
    }
    _applyLighting();
    if (isSuperUltra && !wasSuper) {
      // Super Ultra swaps in its own materials (sea, grass, firepit stones,
      // fire); compile them now, not on the frame each first shows up.
      unawaited(prewarmPipelines(scene, camera));
    }
    _recount();
  }

  /// Mounts or unmounts the Super Ultra content and swaps what it replaces:
  /// the cylinder landmass, the Ultra sea and sand, the sky, the sun path,
  /// the buoy spots and the camera framing.
  void _syncSuperUltra(bool on) {
    if (on) {
      _superRig.mount(scene);
      if (_rainWanted) {
        unawaited(_prepareRain());
      }
    } else {
      _superRig.unmount();
      // The firepit stones and the trees go back to the imported materials.
      if (_superRig.isBuilt) {
        _superRig.stones.release();
        _superRig.trees.release();
      }
      // Rain stops with the mode, dry, so coming back does not replay a
      // shower frozen mid-air.
      _superRig.rain?.reset();
      _superRig.lightning?.reset();
      _superRig.unmountRain();
      _rainLevel = 0.0;
      _superRig.weather = 0.0;
    }
    _capNode.visible = !on;
    _coneNode.visible = !on;
    _sandRoot?.visible = !on;
    _waterNode.visible = !on;
    dayNight.latitude = on ? kSuperUltraSunLatitude : _normalLatitude;
    if (!on) {
      moonNode.lookAtFrom(_normalMoonEye, vm.Vector3.zero());
    }
    // Buoys move out past the new beach so they float in water, not sand.
    for (final buoy in _buoys) {
      buoy.float.x = buoy.x * (on ? 1.45 : 1.0);
      buoy.float.z = buoy.z * (on ? 1.45 : 1.0);
    }
    dayNight.update(0.0);
    _reframeCamera(superUltra: on);
  }

  void resetBalls() {
    physicsWorld.setupBalls(isUltraMode ? 8 : 1);
    _syncBallInstances();
  }

  /// The sky the current mode shows and bakes its lighting from, or null for
  /// none (Normal and Ultra, which use the default studio environment).
  ///
  /// Every [EnvironmentSettings] literal below must carry these: assigning
  /// `scene.environmentSettings` applies the whole look, sky included, and a
  /// literal that leaves them out sets `scene.skybox` and
  /// `scene.skyEnvironment` to null. That is how a physical sky assigned in
  /// [_buildEnvironment] never reached the screen in any mode, which is why
  /// the sun was never visible.
  Skybox? get _activeSkybox =>
      isSuperUltra && _superRig.isBuilt ? _superRig.skybox : null;
  SkyEnvironment? get _activeSkyEnvironment =>
      isSuperUltra && _superRig.isBuilt ? _superRig.skyEnvironment : null;

  void _applyCampfireShadow() {
    final casts = campfireCastsShadow(
      ultraOrAbove: isSuperUltra,
      effectOn: isEffectOn(SuperUltraEffect.fireShadows),
      godRaysOn: _godRaysOn,
    );
    if (campfireLight.castsShadow != casts) {
      campfireLight.castsShadow = casts;
    }
  }

  /// God rays are Super Ultra's by day. At night the campfire's shadow
  /// takes the atlas instead (see [campfireCastsShadow]): it matters more
  /// than faint moon shafts.
  bool get _godRaysOn =>
      isSuperUltra &&
      isEffectOn(SuperUltraEffect.godRays) &&
      !moonIsKeyLight(nightBlend);

  void _applyEnvironmentSettings() {
    // The first call (from [_buildEnvironment]) runs before the campfire
    // exists; [_buildCampfireLighting] applies it once it does.
    if (_campfireBuilt) {
      _applyCampfireShadow();
    }
    if (isSuperUltra) {
      _applySuperUltraLook();
      return;
    }
    // Allow 2 GPU frames in flight in Normal and Ultra so Android Impeller
    // Vulkan's asynchronous fence completion callback does not pace every
    // other vsync when the frame easily fits the 16.6 ms budget.
    scene.maxGpuFramesInFlight = 2;
    scene.renderQuality.adaptive = false;
    scene.sceneColorCaptureBatches = null;
    sunLight.shadowCascadeCount = 1;
    sunLight.shadowMapResolution = 512;
    sunLight.shadowMaxDistance = 24.0;
    sunLight.shadowFilter = DirectionalShadowFilter.rotatedPoisson;
    sunLight.contactShadows = false;
    if (isUltraMode) {
      scene.renderScale = 0.85;
      scene.antiAliasingMode = AntiAliasingMode.fxaa;
      scene.environmentSettings = EnvironmentSettings(
        skybox: _activeSkybox,
        skyEnvironment: _activeSkyEnvironment,
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
      // Normal mode skips the multi-pass Bloom mip chain (11 command buffers)
      // and DepthPrepass + SSAO (4 command buffers) so it runs in 3 passes
      // (ShadowPass, ScenePass, ResolvePass+FXAA) at a steady 60 fps on mobile.
      scene.renderScale = 0.75;
      scene.antiAliasingMode = AntiAliasingMode.fxaa;
      scene.environmentSettings = EnvironmentSettings(
        skybox: _activeSkybox,
        skyEnvironment: _activeSkyEnvironment,
        toneMapping: ToneMappingMode.aces,
        colorGradingEnabled: true,
        saturation: 1.25,
        contrast: 1.1,
        brightness: 1.05,
        temperature: 0.1,
        bloomEnabled: false,
        vignetteEnabled: true,
        vignetteIntensity: 0.2,
        exposure: 0.8,
        ambientOcclusionEnabled: false,
      );
    }
  }

  /// One coherent look for Super Ultra, after the looks skill: `showcase`
  /// grounding (GTAO with bent normals) plus the atmospheric half of `moody`
  /// (fog with sun in-scatter, god rays, a touch of grain), under a sun you
  /// can now see (lens flare). SSR stays off: the water's planar reflection
  /// replaces it and the two would double up.
  void _applySuperUltraLook() {
    sunLight
      ..shadowCascadeCount = 2
      ..shadowMapResolution = 2048
      ..shadowMaxDistance = 42.0
      ..shadowFilter = DirectionalShadowFilter.pcss
      ..contactShadows = true;
    // SMAA at 85% by default, not MSAA at 100%: the sea reads the scene
    // behind it, which splits the scene pass, and with MSAA that split writes
    // the 4x depth buffer out to memory and reads it back every frame.
    scene.renderScale = _renderScale.scale;
    scene.renderQuality
      ..adaptive = _renderScale.adaptive
      ..targetFrameRate = 60
      ..minRenderScale = 0.6
      ..maxRenderScale = 1.0;
    scene.sceneColorCaptureBatches = _sceneCopies.batches;
    scene.maxGpuFramesInFlight = _gpuPacing.frames;
    scene.antiAliasingMode = _antiAliasing.mode;
    scene.environmentSettings = EnvironmentSettings(
      skybox: _activeSkybox,
      skyEnvironment: _activeSkyEnvironment,
      toneMapping: ToneMappingMode.aces,
      exposure: 0.85,
      autoExposureEnabled: true,
      autoExposureStrength: 0.42,
      autoExposureMinEv: -1.6,
      autoExposureMaxEv: 1.4,
      autoExposureSpeedUp: 2.4,
      autoExposureSpeedDown: 1.1,
      colorGradingEnabled: true,
      saturation: 1.18,
      contrast: 1.08,
      temperature: 0.04,
      bloomEnabled: true,
      bloomThreshold: 1.0,
      bloomIntensity: 0.16,
      bloomScatter: 0.72,
      lensFlareEnabled: true,
      lensFlareIntensity: 0.35,
      lensFlareHaloIntensity: 0.22,
      vignetteEnabled: true,
      vignetteIntensity: 0.22,
      filmGrainEnabled: true,
      filmGrainIntensity: 0.035,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      ambientOcclusionHalfResolution: true,
      ambientOcclusionIntensity: 0.9,
      fogEnabled: true,
      fogMode: FogMode.exponential,
      fogDensity: 0.003,
      fogHeight: IslandDimensions.seaY + 1.8,
      fogHeightFalloff: 0.28,
      fogSkyColorInfluence: 1.0,
      fogSunInScatter: 0.3,
      fogSunInScatterExponent: 12.0,
      godRaysEnabled: true,
      godRaysIntensity: 0.8,
      godRaysDensity: 0.15,
      godRaysAnisotropy: 0.75,
      godRaysStepCount: 24,
      // Refitted every frame by _fitGodRaysMarch.
      godRaysMaxDistance: 43.0,
      depthOfFieldBladeCount: 6,
    );
    _applyEffectsMenu();
  }

  // ------------------------------------------------------ effects menu

  final Set<SuperUltraEffect> _effectsOff = <SuperUltraEffect>{};
  SuperUltraAntiAliasing _antiAliasing = SuperUltraAntiAliasing.initial;
  SuperUltraRenderScale _renderScale = SuperUltraRenderScale.initial;
  SuperUltraGpuPacing _gpuPacing = SuperUltraGpuPacing.initial;
  SuperUltraFrameCap _frameCap = SuperUltraFrameCap.initial;
  SuperUltraSceneCopies _sceneCopies = SuperUltraSceneCopies.initial;

  /// Whether the effects menu has [effect] on (all are, by default).
  bool isEffectOn(SuperUltraEffect effect) => !_effectsOff.contains(effect);

  /// The effects menu's anti-aliasing pick.
  SuperUltraAntiAliasing get antiAliasing => _antiAliasing;

  /// The effects menu's render-scale pick.
  SuperUltraRenderScale get renderScale => _renderScale;

  /// The effects menu's GPU-pacing pick.
  SuperUltraGpuPacing get gpuPacing => _gpuPacing;

  /// The effects menu's frame-cap pick (`SceneView.maxFrameRate`).
  SuperUltraFrameCap get frameCap => _frameCap;

  /// The effects menu's scene-copies pick.
  SuperUltraSceneCopies get sceneCopies => _sceneCopies;

  /// How many menu entries differ from their default: effects switched off,
  /// plus each image-quality pick that has been changed.
  int get effectsMenuChanges =>
      _effectsOff.length +
      (_antiAliasing == SuperUltraAntiAliasing.initial ? 0 : 1) +
      (_renderScale == SuperUltraRenderScale.initial ? 0 : 1) +
      (_gpuPacing == SuperUltraGpuPacing.initial ? 0 : 1) +
      (_frameCap == SuperUltraFrameCap.initial ? 0 : 1) +
      (_sceneCopies == SuperUltraSceneCopies.initial ? 0 : 1);

  /// Switches one Super Ultra feature on or off, to read its cost off the
  /// frame times. Kept across mode switches until [resetEffects].
  void setEffect(SuperUltraEffect effect, bool on) {
    if (on ? !_effectsOff.remove(effect) : !_effectsOff.add(effect)) {
      return;
    }
    _refreshEffects();
  }

  /// Picks Super Ultra's anti-aliasing. Kept until [resetEffects].
  void setAntiAliasing(SuperUltraAntiAliasing value) {
    if (value == _antiAliasing) {
      return;
    }
    _antiAliasing = value;
    _refreshEffects();
  }

  /// Picks Super Ultra's render scale. Kept until [resetEffects].
  void setRenderScale(SuperUltraRenderScale value) {
    if (value == _renderScale) {
      return;
    }
    _renderScale = value;
    _refreshEffects();
  }

  /// Picks how many GPU frames may queue before the scene re-presents its
  /// last image. Kept until [resetEffects].
  void setGpuPacing(SuperUltraGpuPacing value) {
    if (value == _gpuPacing) {
      return;
    }
    _gpuPacing = value;
    _refreshEffects();
  }

  /// Picks how often the scene may render. Kept until [resetEffects]; the
  /// scene screen passes it to `SceneView.maxFrameRate`.
  void setFrameCap(SuperUltraFrameCap value) {
    if (value == _frameCap) {
      return;
    }
    _frameCap = value;
    _refreshEffects();
  }

  /// Picks how many scene-colour copies the sea and haze may take. Kept
  /// until [resetEffects].
  void setSceneCopies(SuperUltraSceneCopies value) {
    if (value == _sceneCopies) {
      return;
    }
    _sceneCopies = value;
    _refreshEffects();
  }

  /// Every effect back on and every image-quality pick back to default.
  void resetEffects() {
    if (effectsMenuChanges == 0) {
      return;
    }
    _effectsOff.clear();
    _antiAliasing = SuperUltraAntiAliasing.initial;
    _renderScale = SuperUltraRenderScale.initial;
    _gpuPacing = SuperUltraGpuPacing.initial;
    _frameCap = SuperUltraFrameCap.initial;
    _sceneCopies = SuperUltraSceneCopies.initial;
    _refreshEffects();
  }

  void _refreshEffects() {
    if (isSuperUltra) {
      // The full look first, which ends by applying the menu.
      _applyEnvironmentSettings();
      _applyLighting();
    }
  }

  /// Applies the effects menu over the Super Ultra look, which has just set
  /// everything on.
  void _applyEffectsMenu() {
    bool off(SuperUltraEffect effect) => _effectsOff.contains(effect);
    final rig = _superRig;
    if (rig.isBuilt) {
      void mount(Node node, bool on) {
        if (on && node.parent == null) {
          rig.root.add(node);
        } else if (!on && node.parent != null) {
          node.detach();
        }
      }

      mount(rig.oceanNode, !off(SuperUltraEffect.sea));
      mount(rig.simpleSeaNode, off(SuperUltraEffect.sea));
      mount(rig.grassNode, !off(SuperUltraEffect.grass));
      mount(rig.fire.root, !off(SuperUltraEffect.fireVfx));
      rig.fireflies.setEnabled(!off(SuperUltraEffect.fireflies));
      final decalsOn = !off(SuperUltraEffect.decals);
      rig.decals.root.visible = decalsOn;
      mount(rig.decals.root, decalsOn);
      for (final reflector
          in rig.oceanNode.getComponents<PlanarReflectorComponent>()) {
        reflector.enabled = !off(SuperUltraEffect.planarReflection);
      }
      if (off(SuperUltraEffect.lightningRipple)) clearShockwaves();
      rig
        ..grassLevel = (() => qualityLevelFor(scene.effectiveRenderQualityTier))
        ..grassFullDensity = off(SuperUltraEffect.grassThinning);
      rig.fire.setCoreGlow(
          off(SuperUltraEffect.glowCard) ? CoreGlowMode.sprite : CoreGlowMode.card);
      final windOn = !off(SuperUltraEffect.wind);
      mount(rig.flag.root, windOn);
      if (windOn) {
        rig.trees.bind([
          for (final prop in _props) prop.node,
          ?_ultraScatterRoot,
        ], _treeSway);
      } else {
        rig.trees.release();
      }
      if (off(SuperUltraEffect.stoneIndirect)) {
        rig.stones.release();
      } else {
        rig.stones.bind([for (final prop in _props) prop.node]);
      }
    }
    final post = scene.postProcess;
    if (off(SuperUltraEffect.godRays)) scene.godRays.enabled = false;
    if (off(SuperUltraEffect.ambientOcclusion)) {
      scene.ambientOcclusion.enabled = false;
    }
    if (off(SuperUltraEffect.contactShadows)) sunLight.contactShadows = false;
    if (off(SuperUltraEffect.secondCascade)) sunLight.shadowCascadeCount = 1;
    if (off(SuperUltraEffect.softShadows)) {
      sunLight.shadowFilter = DirectionalShadowFilter.rotatedPoisson;
    }
    if (off(SuperUltraEffect.bloom)) post.bloom.enabled = false;
    if (off(SuperUltraEffect.bloom) || off(SuperUltraEffect.lensFlare)) {
      post.bloom.lensFlare.enabled = false;
    }
    if (off(SuperUltraEffect.fog)) scene.fog.enabled = false;
    if (off(SuperUltraEffect.filmFinish)) {
      post.vignette.enabled = false;
      post.filmGrain.enabled = false;
      post.colorGrading.enabled = false;
    }
    if (off(SuperUltraEffect.autoExposure)) {
      scene.autoExposure.enabled = false;
    }
    _syncSuperUltraDof();
  }

  /// Syncs Depth of Field with the active camera mode and distance, following
  /// the `flutter_scene-looks` rule: active for hero close-ups and
  /// over-the-shoulder, off for wide island overviews (>= 25 m).
  void _syncSuperUltraDof() {
    if (!isSuperUltra || !isEffectOn(SuperUltraEffect.depthOfField)) {
      scene.depthOfField.enabled = false;
      return;
    }
    final eye = cameraNode.globalTransform.getTranslation();
    final ots = _cameraMode == IslandCameraMode.overTheShoulder;
    final target = ots
        ? walker.position + vm.Vector3(0, 0.85, 0)
        : _orbitTarget;
    final dist = (eye - target).length;
    final focus = superUltraDofFocus(
      overTheShoulder: ots,
      cameraToTargetDistance: dist,
    );
    final dof = scene.depthOfField;
    dof.enabled = focus.enabled;
    if (focus.enabled) {
      final tier = scene.effectiveRenderQualityTier;
      dof
        ..focusDistance = focus.focalDistance
        ..fStop = focus.fStop
        ..maxForegroundBlur = focus.maxBlurRadius
        ..maxBackgroundBlur = focus.maxBlurRadius * 1.15
        ..quality = tier == RenderQualityTier.high
            ? DepthOfFieldQuality.medium
            : DepthOfFieldQuality.low;
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
    final cap = _capNode = Node(
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

    final cone = _coneNode = Node(
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

    final initialSeaMat = isUltraMode ? _ultraSeaMaterial : _normalSeaMaterial;
    _waterNode = Node(
      name: 'sea',
      mesh: Mesh(
        DiscGeometry(radius: IslandDimensions.seaRadius, segments: 64),
        initialSeaMat,
      ),
    )..position = vm.Vector3(0, IslandDimensions.seaY, 0);
    _waterNode.shadowCastingMode = ShadowCastingMode.off;
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
      shake: _cameraShake,
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
      orbit.target = _orbitTarget;
      orbit.update(0.0);
    }
  }

  vm.Vector3 get _orbitTarget =>
      isSuperUltra ? vm.Vector3(0, 3.4, 0) : vm.Vector3(0, 0.2, 0);

  /// Super Ultra frames the island from just above the horizon, wide, and
  /// facing the key light, so the sun (or moon) and the sky are in shot and
  /// the palms stand against them. Everything else keeps the high overview.
  ///
  /// When the orbit camera is live the new controller starts exactly where
  /// the camera is and eases to the new framing, so the switch is a camera
  /// move rather than a cut.
  void _reframeCamera({required bool superUltra}) {
    _cameraComponent.projection = PerspectiveProjection(
      fovRadiansY: (superUltra ? 58 : 45) * vm.degrees2Radians,
      near: 0.15,
      far: superUltra ? 640.0 : 220.0,
    );
    final target = _orbitTarget;
    final double wantPolar = superUltra ? 0.07 : 0.62;
    final double wantDistance = superUltra ? 32.0 : 40.0;
    final live = _isOrbitAttached;

    var distance = wantDistance;
    var polar = wantPolar;
    var azimuth = 0.55;
    if (live) {
      final offset = cameraNode.globalTransform.getTranslation() - target;
      if (offset.length > 1e-3) {
        distance = offset.length;
        polar = math.asin((offset.y / distance).clamp(-1.0, 1.0));
        azimuth = math.atan2(-offset.x, -offset.z);
      }
    }
    final wantAzimuth = superUltra
        ? orbitAzimuthFacing(_keyLightDirection())
        : azimuth;

    final next = OrbitCameraController(
      target: target,
      distance: distance,
      azimuth: live ? azimuth : wantAzimuth,
      polar: live ? polar : wantPolar,
      minDistance: superUltra ? 14.0 : 20.0,
      maxDistance: superUltra ? 80.0 : 70.0,
      // Super Ultra may dip just below the target to look up at the sky.
      minPolar: superUltra ? -0.06 : 0.12,
      maxPolar: 1.15,
      panSpeed: 0.0,
      smoothing: superUltra ? 0.45 : 0.18,
    );
    if (live) {
      final turn = math.atan2(
        math.sin(wantAzimuth - azimuth),
        math.cos(wantAzimuth - azimuth),
      );
      next
        ..orbitBy(turn, wantPolar - polar)
        ..dollyBy(-math.log(wantDistance / distance) / next.dollySpeed);
    }
    if (live) {
      cameraNode.removeComponent(orbit);
    }
    orbit = next;
    if (live) {
      cameraNode.addComponent(orbit);
      orbit.update(0.0);
    }
  }

  /// Debug tour only: re-aim the Super Ultra framing at the current key
  /// light, so each stop of `SCENE_TOUR` has the sun or moon in shot.
  void debugFaceKeyLight() {
    if (isSuperUltra && _cameraMode == IslandCameraMode.orbit) {
      _reframeCamera(superUltra: true);
    }
  }

  /// Debug ablation only (`SCENE_ABLATION`): Super Ultra with effects-menu
  /// entries switched off, another image-quality pick, or rain added, so
  /// each cost shows as a frame-time delta. The first step is the untouched
  /// baseline.
  static final Map<String, _AblationStep> _ablation = <String, _AblationStep>{
    'all on': _ablationStep(),
    for (final effect in SuperUltraEffect.values)
      '${effect.label} off': _ablationStep(off: <SuperUltraEffect>{effect}),
    for (final aa in SuperUltraAntiAliasing.values)
      if (aa != SuperUltraAntiAliasing.initial)
        'AA ${aa.label}': _ablationStep(antiAliasing: aa),
    for (final scale in SuperUltraRenderScale.values)
      if (scale != SuperUltraRenderScale.initial)
        'scale ${scale.label}': _ablationStep(renderScale: scale),
    'MSAA at 100% (old default)': _ablationStep(
      antiAliasing: SuperUltraAntiAliasing.msaa,
      renderScale: SuperUltraRenderScale.percent100,
    ),
    'all post off': _ablationStep(
      off: const <SuperUltraEffect>{
        SuperUltraEffect.godRays,
        SuperUltraEffect.ambientOcclusion,
        SuperUltraEffect.contactShadows,
        SuperUltraEffect.bloom,
        SuperUltraEffect.lensFlare,
        SuperUltraEffect.fog,
        SuperUltraEffect.filmFinish,
        SuperUltraEffect.depthOfField,
        SuperUltraEffect.autoExposure,
      },
    ),
    '+ rain & storm': _ablationStep(),
  };

  static _AblationStep _ablationStep({
    Set<SuperUltraEffect> off = const <SuperUltraEffect>{},
    SuperUltraAntiAliasing antiAliasing = SuperUltraAntiAliasing.initial,
    SuperUltraRenderScale renderScale = SuperUltraRenderScale.initial,
  }) =>
      (off: off, antiAliasing: antiAliasing, renderScale: renderScale);

  static List<String> get debugAblationSteps => _ablation.keys.toList();

  /// Debug ablation only: applies [step] from [debugAblationSteps].
  Future<void> debugAblate(String step) async {
    if (!isSuperUltra) {
      return;
    }
    final rain = step == '+ rain & storm';
    if (rain != isRaining) {
      await setRain(rain);
    }
    final settings = _ablation[step] ?? _ablationStep();
    _effectsOff
      ..clear()
      ..addAll(settings.off);
    _antiAliasing = settings.antiAliasing;
    _renderScale = settings.renderScale;
    _gpuPacing = SuperUltraGpuPacing.initial;
    _frameCap = SuperUltraFrameCap.initial;
    _sceneCopies = SuperUltraSceneCopies.initial;
    _refreshEffects();
  }

  /// Toward whichever light casts shadows right now.
  vm.Vector3 _keyLightDirection() {
    if (isSuperUltra && moonIsKeyLight(nightBlend)) {
      return moonDirectionFor(timeOfDay);
    }
    return dayNight.sunDirection;
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
    if (isUltraMode) {
      _applyEnvironmentSettings();
      _applyLighting();
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

  /// Rotates the over-the-shoulder camera around the character by dragging:
  /// sideways turns it, up and down tilts the view (up to about 55 degrees
  /// above level, to look up through the treetops at the sun).
  void rotateOtsCamera(double deltaX, double deltaY) {
    if (_cameraMode != IslandCameraMode.overTheShoulder) return;
    _otsOrbitAngle -= deltaX * 0.007;
    _otsPitch = (_otsPitch - deltaY * 0.005).clamp(-0.45, 1.05);
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
      ..scale = vm.Vector3.all(placement.size);
    // shadowStatic is per mesh-bearing node, not inherited by glTF child nodes.
    _forEachNode(instance, (node) => node.shadowStatic = true);
    scene.add(instance);

    final (heightOffset, radius) = switch (placement.kind) {
      'palm' => (1.8 * placement.size, 2.6 * placement.size),
      'pine' => (1.4 * placement.size, 2.2 * placement.size),
      'rockLarge' => (0.6 * placement.size, 1.8 * placement.size),
      'rockSmall' => (0.3 * placement.size, 1.2 * placement.size),
      'campfire' => (0.35 * placement.size, 1.3 * placement.size),
      _ => (0.5 * placement.size, 1.4 * placement.size),
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
    _scatterRainProps.clear();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final kind = _ultraScatterKinds[i % _ultraScatterKinds.length];
      final yaw = (i * 2.399) % (math.pi * 2.0);
      final placement =
          _Placement(kind, point.x, point.y, yaw, 0.82 + (i % 5) * 0.06);
      byKind.putIfAbsent(kind, () => <_Placement>[]).add(placement);
      _scatterRainProps.add(RainProp(kind, point.x, point.y, placement.size));
      hulls.add(
        IslandObstacle(
          name: 'ultra_$i',
          x: point.x,
          z: point.y,
          radius: switch (kind) {
            'rockLarge' => 0.6,
            'rockSmall' => 0.4,
            'palm' || 'pine' => 0.45,
            _ => 0.35,
          },
        ),
      );
    }

    // Separate swaying trees from static rocks/bushes so TreeSway.bind only
    // clears shadowStatic on the vertex-displaced tree batches.
    final staticScatter = Node(name: 'ultra_scatter_static')
      ..shadowStatic = true;
    final treeScatter = Node(name: 'ultra_scatter_trees')
      ..shadowStatic = true;
    for (final entry in byKind.entries) {
      final isTree = entry.key == 'palm' || entry.key == 'pine';
      _addInstancedKind(
        isTree ? treeScatter : staticScatter,
        entry.key,
        entry.value,
      );
    }
    final root = Node(name: 'ultra_scatter')
      ..shadowStatic = true
      ..add(staticScatter)
      ..add(treeScatter);
    scene.add(root);
    _ultraScatterRoot = root;

    for (final entry in byKind.entries) {
      for (final placement in entry.value) {
        final (heightOffset, radiusHull) = switch (placement.kind) {
          'palm' => (1.8 * placement.size, 2.6 * placement.size),
          'pine' => (1.4 * placement.size, 2.2 * placement.size),
          'rockLarge' => (0.6 * placement.size, 1.8 * placement.size),
          'rockSmall' => (0.3 * placement.size, 1.2 * placement.size),
          _ => (0.5 * placement.size, 1.4 * placement.size),
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
          vm.Vector3.all(placement.size),
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

    _coverRainProps
      ..clear()
      ..addAll(<RainProp>[
        for (var i = 0; i < points.length; i++)
          RainProp('bush', points[i].x, points[i].y, 0.42 + (i % 5) * 0.055),
      ]);

    final root = Node(name: 'ultra_ground_cover')
      ..layers = kSuperUltraNoReflectLayer
      ..shadowStatic = true
      ..shadowCastingMode = ShadowCastingMode.off;

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

    final dry = _flatMaterial(0.74, 0.60, 0.40, roughness: 0.84)
      ..depthLayer = 1;
    final wet = _flatMaterial(0.42, 0.34, 0.25, roughness: 0.22);
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
      isActive: () => isUltraMode,
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

  /// Birds in the Ultra flock.
  static const int _flockSize = 4;

  /// The seagull model is 4.13 units wingtip to wingtip; this gives a 1.8 m
  /// span, which reads against the sky from the orbit camera.
  static const double _birdScale = 0.44;

  /// Builds the flock once, off-screen; [_syncFlock] mounts it in Ultra.
  Future<void> _buildFlock() async {
    final nodes = <Node>[];
    final wingbeats = <AnimationClip?>[];
    final birds = <FlockBirdMotion>[];
    for (var i = 0; i < _flockSize; i++) {
      final model = await _loadProp('assets/models/seagull.glb');
      // Not inherited by children, so every node of the model.
      _forEachNode(model, (node) => node.shadowCastingMode = ShadowCastingMode.off);
      final flight = model.findAnimationByName('Fast_Flying');
      AnimationClip? wingbeat;
      if (flight != null) {
        // Slightly different rates and start points, so four birds never
        // beat their wings in step.
        wingbeat = model.createAnimationClip(flight)
          ..loop = true
          ..playbackTimeScale = 0.9 + 0.07 * i
          ..seek(i * 0.19)
          ..play();
      }
      wingbeats.add(wingbeat);
      // The import turns the glTF's +Z-facing model to face -Z (the
      // character gets the same half turn); turn it back so the beak leads
      // along +Z, the way [FlockBirdMotion.attitude] flies it. The body
      // sits about 2.25 units up and 0.2 back in the model; centre it on the
      // bird's position so climb and bank pivot about it.
      final inner = Node(name: 'seagull_model_$i')
        ..scale = vm.Vector3.all(_birdScale)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi)
        ..position = vm.Vector3(0, -2.25 * _birdScale, 0.2 * _birdScale)
        ..add(model);
      nodes.add(Node(name: 'seagull_$i')..add(inner));

      // Above the 4-5 m palms and pines, whose crowns reach past the rim
      // the flock circles.
      final angle = i / _flockSize * math.pi * 2.0;
      final radius = 11.4 + (i % 3) * 0.7;
      final height = 7.4 + (i % 4) * 0.45;
      final tangent = vm.Vector3(math.cos(angle), 0, -math.sin(angle));
      birds.add(
        FlockBirdMotion(
          position: vm.Vector3(
            math.sin(angle) * radius,
            height,
            math.cos(angle) * radius,
          ),
          velocity: tangent * 6.2,
          orbitRadius: radius,
          cruiseHeight: height,
          minHeight: 6.2,
          maxHeight: 10.5,
        ),
      );
    }
    final root = Node(name: 'seagull_flock')
      ..addComponent(
        SeagullFlockComponent(nodes: nodes, birds: birds, wingbeats: wingbeats),
      );
    for (final node in nodes) {
      root.add(node);
    }
    _flockRoot = root;
    // In case Ultra was chosen while the birds were still loading.
    _syncFlock(isUltraMode);
  }

  void _syncFlock(bool ultra) {
    final root = _flockRoot;
    if (root == null) {
      return;
    }
    if (!ultra) {
      root.detach();
    } else if (root.parent == null) {
      scene.add(root);
    }
  }

  static void _forEachNode(Node node, void Function(Node node) visit) {
    visit(node);
    for (final child in node.children) {
      _forEachNode(child, visit);
    }
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
    _cameraShake.addTrauma(hits > 0 ? 0.30 : 0.14);
    if (isUltraMode) {
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
    final crateMat = _flatMaterial(0.42, 0.28, 0.14, roughness: 0.78)
      ..clearcoat = 0.55
      ..clearcoatRoughness = 0.16;
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
        ..shadowCastingMode = ShadowCastingMode.off
        ..addComponent(
          FloatingMotionComponent(
            hoverAmplitude: 0.05,
            hoverFrequency: 0.55,
            wobbleDegrees: 7.0,
            wobbleFrequency: 0.7,
            spinSpeed: 0.35,
          ),
        );
      final float = BuoyFloatComponent(
        sampleWater: _sampleWater,
        x: x,
        z: z,
        seaY: IslandDimensions.seaY,
      );
      final root = Node(name: 'buoy_$i')
        ..position = vm.Vector3(x, IslandDimensions.seaY + 0.18, z)
        ..add(body)
        ..addComponent(float);
      scene.add(root);
      _buoys.add(_Buoy(root: root, float: float, x: x, z: z));
    }
  }

  /// The sea surface at [at], from whichever sea is showing: Super Ultra's
  /// GPU waves (on the clock the shader runs on) or Ultra's CPU waves.
  ({vm.Vector3 displacement, vm.Vector3 normal})? _sampleWater(vm.Vector2 at) {
    if (isSuperUltra && _superRig.isBuilt) {
      return _superRig.waterSurface.evaluateAt(at, _superRig.oceanTime);
    }
    return _waterSurface?.evaluateAt(at);
  }

  void _sitBallsOnWaves() {
    if (!isUltraMode) {
      return;
    }
    for (final ball in physicsWorld.balls) {
      final radius = math.sqrt(
        ball.position.x * ball.position.x + ball.position.z * ball.position.z,
      );
      if (radius <= IslandDimensions.walkableRadius) {
        continue;
      }
      final sample = _sampleWater(
        vm.Vector2(ball.position.x, ball.position.z),
      );
      if (sample == null) {
        continue;
      }
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
    _debrisRoot ??= Node(name: 'ultra_debris')..shadowCastingMode = ShadowCastingMode.off;
    if (_debrisRoot!.parent == null) {
      scene.add(_debrisRoot!);
    }
    _chipMesh ??= Mesh(
      CuboidGeometry(vm.Vector3(0.08, 0.05, 0.07)),
      _flatMaterial(0.38, 0.3, 0.22, roughness: 0.95),
    );
    _debrisPool ??= NodePool(
      () => Node(name: 'punch_chip', mesh: _chipMesh)
        ..shadowCastingMode = ShadowCastingMode.off,
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
    _viewport = viewportSize;
    if (!_shockwaves.isEmpty || scene.screenDistortion.enabled) {
      _shockwaves.update(deltaSeconds);
      applyShockwaves(scene, _shockwaves);
    }
    if (_xray != XrayMode.off) {
      _xrayClock += deltaSeconds;
      scene.debug.split = xraySplit(_xrayClock);
    }
    walker.advance(deltaSeconds);
    if (isSuperUltra && _superRig.isMounted) {
      _superRig.decals.tick(
        deltaSeconds,
        walker.position.x,
        walker.position.z,
        walker.yaw,
      );
    }

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
    _tickRain(deltaSeconds);
    _tickLightning();
    if (_cameraMode == IslandCameraMode.orbit && _isOrbitAttached) {
      if (_cameraShake.trauma > 0.0) {
        orbit.update(0.0);
        final offset = _cameraShake.update(deltaSeconds);
        cameraNode.localTransform =
            cameraNode.localTransform * offset.toMatrix4();
        _orbitShakeActive = true;
      } else if (_orbitShakeActive) {
        orbit.update(0.0);
        _orbitShakeActive = false;
      }
    }
    if (isSuperUltra) {
      _fitGodRaysMarch();
      _syncSuperUltraDof();
    }

    if (_cameraMode == IslandCameraMode.overTheShoulder) {
      _cullOffscreenNodes(viewportSize ?? const ui.Size(393, 852));
    }
  }

  /// Ends the god-ray march at the island's far shore. A shaft is the share
  /// of a pixel's march that lies in a tree's shadow; open air past the
  /// island is lit everywhere, so marching it only thins the shafts into an
  /// even glow around the sun.
  void _fitGodRaysMarch() {
    final eye = cameraNode.globalTransform.getTranslation();
    scene.godRays.maxDistance =
        math.sqrt(eye.x * eye.x + eye.z * eye.z) + IslandDimensions.topRadius;
  }

  /// Releases cross-frame render targets, shadow caches, punctual light
  /// textures, and TAA/SSGI history immediately (`Scene.dispose()` in 0.24.2+).
  void dispose() {
    scene.dispose();
  }

  /// Applies the day/night model's evaluated lighting, with two departures
  /// from what `DayNightCycleComponent` would do on its own: the ambient term
  /// keeps a floor so dusk does not fall off a cliff, and the moon fades in as
  /// the sun goes down.
  void _applyLighting() {
    final superUltra = isSuperUltra && _superRig.isBuilt;
    final lighting = superUltra
        ? _lightingClock.evaluateLighting()
        : dayNight.evaluateLighting();
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
    if (superUltra) {
      _applySuperUltraLighting(lighting);
    }
  }

  /// Super Ultra's additions to [_applyLighting]: the visible moon, the moon
  /// taking over the one shadow-casting light at night (moon shadows), god
  /// rays by day and the campfire's shadow by night, fog tint following the
  /// key light, and the light the self-shading materials need.
  void _applySuperUltraLighting(AtmosphericLighting lighting) {
    final night = nightBlend;
    final sunDirection = dayNight.sunDirection;
    final moonDirection = moonDirectionFor(timeOfDay);
    moonNode.lookAtFrom(moonDirection * 100.0, vm.Vector3.zero());

    final vm.Vector3 keyDirection;
    final vm.Vector3 keyRadiance;
    if (moonIsKeyLight(night)) {
      // [timeOfDay] ran dayNight.update() first, which aimed the sun node at
      // the (set) sun; turn it to the moon instead.
      sunNode.lookAtFrom(moonDirection * 100.0, vm.Vector3.zero());
      // Brighter than the Normal/Ultra moon: this sky really is dark at
      // night (its lighting bake follows it), where Normal/Ultra fall back
      // to a floor of generic ambient.
      sunLight
        ..color = moonLight.color
        ..intensity = 1.6 * night
        ..castsShadow = true
        ..shadowAmbientStrength = 0.55;
      scene.environmentIntensity = math.max(scene.environmentIntensity, 0.45);
      moonLight.intensity = 0.0;
      keyDirection = moonDirection;
      keyRadiance = moonLight.color * sunLight.intensity;
    } else {
      final golden = goldenHourFactor(sunDirection.y);
      final warmColor = vm.Vector3(
        lighting.sunColor.x,
        lighting.sunColor.y * (1.0 - 0.12 * golden) + 0.64 * (0.12 * golden),
        lighting.sunColor.z * (1.0 - 0.28 * golden) + 0.24 * (0.28 * golden),
      );
      final warmBoost = 1.0 + 0.28 * golden;
      sunLight
        ..color = warmColor
        ..intensity = lighting.sunIntensity * warmBoost;
      keyDirection = sunDirection;
      keyRadiance = warmColor * sunLight.intensity;
    }

    // Rain clouds: a dimmer key light, almost no shafts, thicker grey haze.
    final rain = _rainLevel;
    final dim = 1.0 - 0.6 * rain;
    sunLight.intensity *= dim;

    final shaftColor = sunLight.color.clone();
    scene.godRays
      ..enabled = _godRaysOn
      ..color = shaftColor
      ..intensity = 0.8 * (1.0 - 0.85 * rain);
    if (_campfireBuilt) {
      _applyCampfireShadow();
    }
    // Horizon haze follows the light: blue-grey by day, warm at golden hour,
    // navy at night. The sky-colour influence does most of the work; this is
    // the fallback where the environment is dark.
    final golden = goldenHourFactor(sunDirection.y) * (1.0 - night);
    final warm = math.max(
      (1.0 - (sunDirection.y / 0.45).clamp(0.0, 1.0)) * (1.0 - night),
      golden,
    );
    final clearFog = vm.Vector3(0.52, 0.62, 0.74) * (1.0 - night) * (1.0 - warm) +
        vm.Vector3(0.88, 0.56, 0.34) * warm +
        vm.Vector3(0.02, 0.035, 0.07) * night;
    final rainFog = vm.Vector3(0.36, 0.39, 0.43) * (1.0 - night) +
        vm.Vector3(0.02, 0.025, 0.035) * night;
    scene.fog
      ..color = clearFog * (1.0 - rain) + rainFog * rain
      ..density = 0.003 + 0.013 * rain
      ..sunInScatter = (0.3 + 0.18 * golden) * (1.0 - rain);
    _applySuperUltraColorGrade(flash: _lastFlash);

    _superRig.applyLighting(
      sunDirection: sunDirection,
      moonDirection: moonDirection,
      night: night,
      keyDirection: keyDirection,
      keyRadiance: keyRadiance * dim,
      ambient: scene.environmentIntensity,
    );
    final keyLuma = (keyRadiance * dim).dot(vm.Vector3(0.2126, 0.7152, 0.0722));
    _baseRainLight = 0.1 + 0.3 * keyLuma + 0.35 * scene.environmentIntensity;
    _baseEnvironmentIntensity = scene.environmentIntensity;
    _superRig.rain?.setLight(_baseRainLight);
    _superRig.lightning?.strength = 0.3 + 0.7 * night;
  }

  void _applySuperUltraColorGrade({required double flash}) {
    if (!isSuperUltra) {
      return;
    }
    final night = nightBlend;
    final golden = goldenHourFactor(dayNight.sunDirection.y) * (1.0 - night);
    final grade = superUltraColorGrade(
      golden: golden,
      night: night,
      rain: _rainLevel,
      flash: flash,
    );
    scene.exposure = 0.85 + grade.exposureBias;
    if (!isEffectOn(SuperUltraEffect.filmFinish)) {
      return;
    }
    final cg = scene.postProcess.colorGrading;
    cg
      ..enabled = true
      ..contrast = grade.contrast
      ..saturation = grade.saturation
      ..temperature = grade.colorTemperature
      ..tint = grade.colorTint
      ..lift.setValues(
        (grade.shadowTint.x - 1.0) * 0.06,
        (grade.shadowTint.y - 1.0) * 0.06,
        (grade.shadowTint.z - 1.0) * 0.06,
      )
      ..gamma.setFrom(grade.midtoneTint)
      ..gain.setFrom(grade.highlightTint);
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

  final Map<UnlitMaterial, PhysicallyBasedMaterial> _relitUnlitCache =
      <UnlitMaterial, PhysicallyBasedMaterial>{};

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
          primitive.material = _relitUnlitCache.putIfAbsent(
            material,
            () => PhysicallyBasedMaterial()
              ..baseColorTexture = material.baseColorTexture
              ..baseColorFactor = material.baseColorFactor
              ..metallicFactor = 0.0
              ..roughnessFactor = 0.85,
          );
        }
      }
    }
    for (final child in node.children) {
      _relightImportedMaterials(child);
    }
  }
}

/// One step of the debug ablation: the effects-menu state it measures.
typedef _AblationStep = ({
  Set<SuperUltraEffect> off,
  SuperUltraAntiAliasing antiAliasing,
  SuperUltraRenderScale renderScale,
});

class _Placement {
  const _Placement(this.kind, this.x, this.z, this.yaw, this.scale);

  final String kind;
  final double x;
  final double z;
  final double yaw;

  /// This instance's variation on its kind's size.
  final double scale;

  /// The uniform scale the model is drawn at.
  double get size => scale * (kind == 'palm' || kind == 'pine' ? _treeScale : 1.0);
}

/// The palm and pine models are 1.36 and 1.25 units tall. At this scale they
/// stand 4-5 m over the 1 m character, so from the shoulder camera you look
/// up through their crowns at the sun and its shafts.
const double _treeScale = 3.6;

class _Buoy {
  const _Buoy({
    required this.root,
    required this.float,
    required this.x,
    required this.z,
  });

  final Node root;
  final BuoyFloatComponent float;

  /// The Ultra spot; Super Ultra pushes it further out.
  final double x;
  final double z;
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

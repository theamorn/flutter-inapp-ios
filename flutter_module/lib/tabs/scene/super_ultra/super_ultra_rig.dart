/// Builds, mounts and drives everything Super Ultra adds to the island: the
/// sculpted terrain and its ground material, clear reflective water, a lawn of
/// swaying grass, the VFX campfire, and a sky with a visible sun, moon and
/// stars.
///
/// Built lazily the first time Super Ultra is switched on, with the CPU-heavy
/// parts (texture baking, meshing) on background isolates. [IslandScene] owns
/// the mode switch; this class only knows how to build its content, mount it,
/// and keep its shader clocks and light parameters current.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_module/tabs/scene/ball_physics.dart';
import 'package:flutter_module/tabs/scene/super_ultra/island_terrain.dart';
import 'package:flutter_module/tabs/scene/super_ultra/lightning.dart';
import 'package:flutter_module/tabs/scene/super_ultra/ocean_waves.dart';
import 'package:flutter_module/tabs/scene/super_ultra/procedural_textures.dart';
import 'package:flutter_module/tabs/scene/super_ultra/rain_collision.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_fire.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_rain.dart';
import 'package:flutter_module/tabs/scene/water_bump.dart';
import 'package:flutter_scene/gpu.dart' show SamplerAddressMode;
import 'package:flutter_scene/kit.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Render layer for content the water's planar reflection skips. Node layers
/// are not inherited, so set it on every node that should stay out.
const int kSuperUltraNoReflectLayer = 1 << 1;

/// Angular radii the sky draws the sun and moon at. Both are drawn about
/// four times their real size so they read on a phone.
const double kSunDiscRadius = 0.028;
const double kMoonDiscRadius = 0.034;

class SuperUltraRig {
  SuperUltraRig({
    required this.seaY,
    required this.campfireBase,
    required this.playerPosition,
    required this.campfireIntensity,
  });

  final double seaY;
  final vm.Vector3 campfireBase;
  final vm.Vector3 Function() playerPosition;
  final double Function() campfireIntensity;

  /// The CPU twin of the GPU waves. Never mounted: it is only asked
  /// [WaterSurfaceComponent.evaluateAt] with [oceanTime], the clock the
  /// shader runs on.
  final WaterSurfaceComponent waterSurface =
      WaterSurfaceComponent(waves: superUltraWaves());

  /// Seconds the sea has been animating. Shared by the shader and the CPU.
  double oceanTime = 0.0;
  double _time = 0.0;

  final Node root = Node(name: 'super_ultra');
  late final Node terrainNode;
  late final Node oceanNode;

  /// The effects menu's cheap sea, mounted instead of [oceanNode] when the
  /// full sea is switched off. Not mounted by the build.
  late final Node simpleSeaNode;
  late final Node grassNode;
  late final SuperUltraFire fire;
  late final PreprocessedSky sky;
  late final Skybox skybox;
  late final SkyEnvironment skyEnvironment;
  late final IslandTerrain terrain;

  late final PreprocessedMaterial _ground;
  late final PreprocessedMaterial _ocean;
  late final PreprocessedMaterial _simpleSea;
  late final PreprocessedMaterial _grass;

  int grassTufts = 0;

  /// 0 (dry) to 1 (raining). Wets the ground and grass, rings the sea with
  /// raindrops, clouds the sky over and gusts the wind. Set it, then call
  /// [applyLighting] so the change reaches the shaders.
  double weather = 0.0;

  /// The rain effect, built the first time rain is asked for.
  SuperUltraRain? rain;

  /// Thunderstorm lightning, built with the rain and mounted under it.
  SuperUltraLightning? lightning;
  Future<SuperUltraRain>? _rainBuilding;
  late final Texture2D _dot;

  Future<void>? _building;
  bool _built = false;
  bool get isBuilt => _built;

  /// Builds on first call; later calls return the same future.
  Future<void> ensureBuilt({required List<IslandObstacle> obstacles}) =>
      _building ??= _build(List<IslandObstacle>.of(obstacles));

  Future<void> _build(List<IslandObstacle> obstacles) async {
    final stopwatch = Stopwatch()..start();
    // CPU work off the render isolate, in parallel with the material loads.
    final texturesFuture = compute(generateSuperUltraTextures, 7);
    final terrainFuture = compute(buildIslandTerrainMeshData, 5);
    final oceanFuture = compute(buildOceanMeshDataIsolate, 224);
    final simpleSeaFuture = compute(buildSimpleSeaMeshDataIsolate, 5);
    final rippleFuture = compute(_wavePixels, 256);

    final materials = await Future.wait(<Future<PreprocessedMaterial>>[
      loadFmatMaterial('assets/materials/island_ground.fmat'),
      loadFmatMaterial('assets/materials/ocean.fmat'),
      loadFmatMaterial('assets/materials/grass.fmat'),
      loadFmatMaterial('assets/materials/ember_bed.fmat'),
      loadFmatMaterial('assets/materials/heat_haze.fmat'),
      loadFmatMaterial('assets/materials/ocean_simple.fmat'),
    ]);
    _ground = materials[0];
    _ocean = materials[1];
    _grass = materials[2];
    _simpleSea = materials[5];
    sky = await loadFmatSky('assets/materials/island_sky.fmat');
    skybox = Skybox(sky);
    skyEnvironment = SkyEnvironment(
      sky,
      refresh: SkyEnvironmentRefresh.manual,
      faceResolution: 64,
      equirectWidth: 256,
    );

    final textures = await texturesFuture;
    final ripplePixels = await rippleFuture;
    final flameTexture = _upload(
      textures.flameAtlas,
      TextureContent.color,
      // 128 px cells: stop at 8 px so a frame never blends into its neighbour.
      maxMips: 5,
      clamp: true,
    );
    final smokeTexture =
        _upload(textures.smokeAtlas, TextureContent.color, maxMips: 5, clamp: true);
    _dot = _upload(textures.softDot, TextureContent.color, clamp: true);
    final groundDetail = _upload(textures.groundDetail, TextureContent.normal);
    final sandRipples = _upload(textures.sandRipples, TextureContent.normal);
    final groundMasks = _upload(textures.groundMasks, TextureContent.data);
    final rippleNormal = _upload(
      PixelImage(ripplePixels, 256, 256),
      TextureContent.normal,
    );

    _ground.parameters
      ..setVec4('water', vm.Vector4(seaY, 0.5, 1.0, 0.0))
      ..setTexture('detail_normal', groundDetail.gpuTexture,
          sampler: groundDetail.sampledSampler)
      ..setTexture('sand_normal', sandRipples.gpuTexture,
          sampler: sandRipples.sampledSampler)
      ..setTexture('masks', groundMasks.gpuTexture,
          sampler: groundMasks.sampledSampler);

    final packed = packOceanWaves(waterSurface.waves);
    _ocean.parameters
      ..setMat4('wave_shape', packed.shape)
      ..setMat4('wave_motion', packed.motion)
      ..setVec4(
        'fade',
        vm.Vector4(kOceanWaveFadeStart, kOceanWaveFadeEnd, 250.0, 318.0),
      )
      ..setTexture('ripple_normal', rippleNormal.gpuTexture,
          sampler: rippleNormal.sampledSampler)
      ..setTexture('foam_texture', groundMasks.gpuTexture,
          sampler: groundMasks.sampledSampler);
    _simpleSea.parameters
      ..setMat4('wave_shape', packed.shape)
      ..setMat4('wave_motion', packed.motion)
      ..setVec4(
        'fade',
        vm.Vector4(kOceanWaveFadeStart, kOceanWaveFadeEnd, 250.0, 318.0),
      )
      ..setVec4('seabed', vm.Vector4(0.55, 0.5, 0.36, kSimpleSeaDepthScale))
      ..setTexture('ripple_normal', rippleNormal.gpuTexture,
          sampler: rippleNormal.sampledSampler)
      ..setTexture('foam_texture', groundMasks.gpuTexture,
          sampler: groundMasks.sampledSampler);

    terrain = IslandTerrain(seed: 5, seaLevel: seaY);
    final terrainData = await terrainFuture;
    terrainNode = Node(
      name: 'su_terrain',
      mesh: Mesh(MeshGeometry.fromMeshData(terrainData), _ground),
    )..shadowStatic = true;

    final oceanData = await oceanFuture;
    oceanNode = Node(
      name: 'su_ocean',
      mesh: Mesh(MeshGeometry.fromMeshData(oceanData), _ocean),
    )
      ..position = vm.Vector3(0, seaY, 0)
      ..castsShadows = false
      // The GPU displaces it, so its flat bounds would be a lie; it is always
      // on screen anyway.
      ..frustumCulled = false
      // Out of its own mirror. The capture clips at the flat sea plane, but
      // the vertex shader lifts wave crests above it, so without this the
      // whole sea (and the scene colour and depth copies its refraction
      // needs) is drawn again every frame just to leave stray crest patches
      // in the reflection.
      ..layers = kSuperUltraNoReflectLayer
      ..addComponent(
        PlanarReflectorComponent(
          resolutionScale: 0.5,
          layerMask: kRenderLayerAll & ~kSuperUltraNoReflectLayer,
        ),
      );

    final simpleSeaData = await simpleSeaFuture;
    simpleSeaNode = Node(
      name: 'su_simple_sea',
      mesh: Mesh(MeshGeometry.fromMeshData(simpleSeaData), _simpleSea),
    )
      ..position = vm.Vector3(0, seaY, 0)
      ..castsShadows = false
      ..frustumCulled = false
      ..layers = kSuperUltraNoReflectLayer;

    final grass = _buildGrass(obstacles);
    grassTufts = grass.instanceCount;
    grassNode = Node(name: 'su_grass')
      ..castsShadows = false
      ..layers = kSuperUltraNoReflectLayer
      ..addComponent(InstancedMeshComponent(grass));

    fire = SuperUltraFire(
      textures: FireTextures(
        flames: flameTexture,
        smoke: smokeTexture,
        dot: _dot,
      ),
      emberMaterial: materials[3],
      hazeMaterial: materials[4],
      base: campfireBase,
    );

    root
      ..add(terrainNode)
      ..add(oceanNode)
      ..add(grassNode)
      ..add(fire.root)
      ..addComponent(_SuperUltraTick(this));
    _built = true;
    debugPrint(
      'super ultra: built in ${stopwatch.elapsedMilliseconds} ms '
      '(${terrainData.triangleCount} terrain tris, '
      '${oceanData.triangleCount} sea tris, $grassTufts grass tufts)',
    );
  }

  static Uint8List _wavePixels(int size) =>
      generateWaveNormalPixels(size: size);

  Texture2D _upload(
    PixelImage image,
    TextureContent content, {
    int? maxMips,
    bool clamp = false,
  }) {
    return Texture2D.fromPixels(
      image.pixels,
      image.width,
      image.height,
      content: content,
      sampling: TextureSampling(
        maxMipmapLevels: maxMips,
        addressMode: clamp
            ? SamplerAddressMode.clampToEdge
            : SamplerAddressMode.repeat,
      ),
    );
  }

  void mount(Scene scene) {
    if (root.parent == null) {
      scene.add(root);
    }
  }

  void unmount() {
    if (root.parent != null) {
      root.detach();
    }
  }

  bool get isMounted => root.parent != null;

  /// Builds the rain on first call (the ground height grid is sampled on an
  /// isolate); later calls return the same rain. [props] are the static
  /// obstacles; [fillDynamics] rewrites the moving ones every step.
  Future<SuperUltraRain> ensureRain({
    required List<RainProp> props,
    required void Function(RainDynamics dynamics) fillDynamics,
    required CameraPose Function() cameraPose,
    double lightningHoldSeconds = 0.0,
  }) =>
      _rainBuilding ??=
          _buildRain(props, fillDynamics, cameraPose, lightningHoldSeconds);

  Future<SuperUltraRain> _buildRain(
    List<RainProp> props,
    void Function(RainDynamics dynamics) fillDynamics,
    CameraPose Function() cameraPose,
    double lightningHoldSeconds,
  ) async {
    final grid = await compute(buildRainHeightGrid, seaY);
    final collider = RainCollider(
      grid: grid,
      seaLevel: seaY,
      props: props,
      fireX: campfireBase.x,
      fireZ: campfireBase.z,
    );
    debugPrint(
      'super ultra: rain ready (${collider.shapeCount} prop shapes, '
      'props up to ${collider.propTop.toStringAsFixed(2)} m)',
    );
    final built = rain = SuperUltraRain(
      collider: collider,
      dot: _dot,
      fillDynamics: fillDynamics,
      waterHeightAt: (x, z) =>
          seaY +
          waterSurface
              .evaluateAt(vm.Vector2(x, z), oceanTime)
              .displacement
              .y,
    );
    final storm = lightning = SuperUltraLightning(
      cameraPose: cameraPose,
      rainLevel: () => built.level,
      seaLevel: seaY,
      debugHoldSeconds: lightningHoldSeconds,
    );
    built.root.add(storm.root);
    return built;
  }

  /// Lights the clouds around a strike toward [direction] by [flash] (0..1).
  /// Only the visible sky: the lighting bake is not redone per flash, the
  /// ambient pulse comes from `environmentIntensity` instead.
  void setSkyFlash(vm.Vector3 direction, double flash) {
    if (!_built) {
      return;
    }
    sky.parameters.setVec4(
      'flash',
      vm.Vector4(direction.x, direction.y, direction.z, flash),
    );
  }

  void mountRain() {
    final effect = rain;
    if (effect != null && effect.root.parent == null) {
      root.add(effect.root);
      debugPrint('super ultra: rain on');
    }
  }

  void unmountRain() {
    final effect = rain;
    if (effect != null && effect.root.parent != null) {
      effect.root.detach();
      debugPrint('super ultra: rain off, unmounted');
    }
  }

  /// Pushes the current lighting into the sky and the materials that shade
  /// themselves. Call whenever the clock moves.
  ///
  /// [keyDirection] points toward whichever light casts shadows (the sun by
  /// day, the moon by night); [keyRadiance] is that light's colour times
  /// intensity.
  void applyLighting({
    required vm.Vector3 sunDirection,
    required vm.Vector3 moonDirection,
    required double night,
    required vm.Vector3 keyDirection,
    required vm.Vector3 keyRadiance,
    required double ambient,
  }) {
    if (!_built) {
      return;
    }
    final sun = sunDirection.normalized();
    final moon = moonDirection.normalized();
    sky.parameters
      ..setVec4('sun_direction', vm.Vector4(sun.x, sun.y, sun.z, kSunDiscRadius))
      ..setVec4(
        'moon_direction',
        vm.Vector4(moon.x, moon.y, moon.z, kMoonDiscRadius),
      )
      // Turbidity 3 rather than the physical sky's hazy 10: the camera looks
      // toward a low sun here, and a hazy sky turns the whole upper frame
      // into one white Mie glare with the sun lost inside it.
      ..setVec4('sky_params', vm.Vector4(3.0, 0.72, 1.0, night))
      ..setVec4('mie', vm.Vector4(0.69, 0.73, 0.81, 0.004))
      // z: how overcast (rain clouds hide the sun, moon and stars).
      ..setVec4('grade', vm.Vector4(0.5, 0.9, weather, 0.0));

    final key = keyDirection.normalized();
    _grass.parameters
      // w: how wet the blades are.
      ..setVec4('sun_dir', vm.Vector4(key.x, key.y, key.z, weather))
      ..setVec4(
        'sun_color',
        vm.Vector4(keyRadiance.x, keyRadiance.y, keyRadiance.z, 0.0),
      );

    // Light that reaches the water body and scatters back out of it: a share
    // of the key light plus the sky's ambient.
    final elevation = math.max(key.y, 0.0);
    final skyTint = vm.Vector3(0.55, 0.66, 0.78) * (ambient * 0.9);
    final water = keyRadiance * (0.12 + 0.2 * elevation) + skyTint;
    _ocean.parameters
      ..setVec4('water_light', vm.Vector4(water.x, water.y, water.z, 1.0))
      // w: raindrop rings across the whole sea; rain also roughens the
      // mirror.
      ..setVec4('ripple', vm.Vector4(0.34, 0.06, 0.018 * (1.0 + weather), weather));
    _simpleSea.parameters
        .setVec4('water_light', vm.Vector4(water.x, water.y, water.z, 1.0));
    // Moonlight is far too weak to throw visible caustics.
    final caustic = keyRadiance * (0.35 + 0.65 * elevation) * (1.0 - 0.85 * night);
    _ground.parameters
      ..setVec4('caustic_light', vm.Vector4(caustic.x, caustic.y, caustic.z, 1.0))
      // w: wetness (darker, shinier ground, puddles).
      ..setVec4('water', vm.Vector4(seaY, 0.5 * (1.0 - 0.7 * weather), 1.0, weather));
  }

  void _tick(double deltaSeconds) {
    if (deltaSeconds <= 0.0) {
      return;
    }
    oceanTime += deltaSeconds;
    _time += deltaSeconds;
    _ocean.parameters.setFloat('time', oceanTime);
    _simpleSea.parameters.setFloat('time', oceanTime);
    _ground.parameters.setFloat('time', _time);
    final player = playerPosition();
    final gust = 1.0 + 1.3 * weather;
    _grass.parameters
      ..setFloat('time', _time)
      ..setVec4('player', vm.Vector4(player.x, player.y, player.z, 0.85))
      ..setVec4('wind', vm.Vector4(0.16 * gust, 0.07 * gust, 1.0 + 0.6 * weather, 0.0));
    fire.update(intensity: campfireIntensity(), time: _time);
    sky.parameters.setVec4('extras', vm.Vector4(_time, 2.2, 1.0, 1.0));
  }

  /// A jittered-grid lawn over the flat top, thinned by a low-frequency
  /// density field so it clumps like real turf, and kept off the trail, the
  /// campfire clearing and every prop's footprint.
  InstancedMesh _buildGrass(List<IslandObstacle> obstacles) {
    final batch = InstancedMesh(geometry: _tuftGeometry(), material: _grass);
    final noise = TileableNoise(19);
    final random = math.Random(29);
    const spacing = 0.27;
    final radius = terrain.flatRadius - 0.2;
    for (var gz = -radius; gz <= radius; gz += spacing) {
      for (var gx = -radius; gx <= radius; gx += spacing) {
        final x = gx + (random.nextDouble() - 0.5) * spacing * 0.9;
        final z = gz + (random.nextDouble() - 0.5) * spacing * 0.9;
        final roll = random.nextDouble();
        final pick = random.nextDouble();
        final yaw = random.nextDouble() * math.pi * 2.0;
        if (x * x + z * z > radius * radius) {
          continue;
        }
        if (terrain.dirtMask(x, z) > 0.12) {
          continue;
        }
        var blocked = false;
        for (final obstacle in obstacles) {
          final dx = x - obstacle.x;
          final dz = z - obstacle.z;
          final keepOut = obstacle.radius + 0.12;
          if (dx * dx + dz * dz < keepOut * keepOut) {
            blocked = true;
            break;
          }
        }
        if (blocked) {
          continue;
        }
        final density =
            0.5 + 0.5 * noise.fbm(x / 48.0 + 0.5, z / 48.0 + 0.5, period: 6, octaves: 2);
        if (roll > _smoothstep(0.2, 0.62, density) + 0.12) {
          continue;
        }
        final scale = (0.62 + 0.62 * pick) * (0.7 + 0.45 * density);
        final dryness = _smoothstep(
          0.42,
          0.78,
          0.5 + 0.5 * noise.fbm(x / 20.0 + 0.3, z / 20.0 + 0.7, period: 4, octaves: 2),
        );
        final shade = 0.82 + 0.34 * pick;
        final tint = vm.Vector3(
          (1.0 + 0.45 * dryness) * shade,
          (1.0 + 0.05 * dryness) * shade,
          (1.0 - 0.3 * dryness) * shade,
        );
        batch.addInstance(
          vm.Matrix4.compose(
            vm.Vector3(x, 0.0, z),
            vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw),
            vm.Vector3.all(scale),
          ),
          color: vm.Vector4(tint.x, tint.y, tint.z, 1.0),
        );
      }
    }
    return batch;
  }

  /// Three tapered, leaning blades. Normals are authored mostly up so the
  /// tuft shades like turf rather than like cards; colour runs dark at the
  /// root to bright at the tip.
  static MeshGeometry _tuftGeometry() {
    final builder = GeometryBuilder(deduplicate: false);
    final random = math.Random(3);
    final base = vm.Vector4(0.028, 0.07, 0.016, 1.0);
    final middle = vm.Vector4(0.07, 0.18, 0.038, 1.0);
    final tip = vm.Vector4(0.2, 0.29, 0.075, 1.0);
    for (var i = 0; i < 3; i++) {
      final angle = i * 2.0 * math.pi / 3.0 + random.nextDouble() * 0.6;
      final out = vm.Vector3(math.cos(angle), 0, math.sin(angle));
      final side = vm.Vector3(-math.sin(angle), 0, math.cos(angle));
      final height = 0.36 + 0.2 * random.nextDouble();
      final lean = 0.1 + 0.12 * random.nextDouble();
      final width = 0.05 + 0.015 * random.nextDouble();
      final root = out * (0.02 + 0.03 * random.nextDouble());
      final normal = (vm.Vector3(0, 1, 0) * 0.8 + out * 0.35)..normalize();
      builder.normal(normal);

      final baseLeft = root - side * (width / 2);
      final baseRight = root + side * (width / 2);
      final midCentre = root + out * (lean * 0.35) + vm.Vector3(0, height * 0.5, 0);
      final midLeft = midCentre - side * (width * 0.36);
      final midRight = midCentre + side * (width * 0.36);
      final tipPoint = root + out * lean + vm.Vector3(0, height, 0);

      builder.color(base);
      final a = builder.addVertex(baseLeft);
      final b = builder.addVertex(baseRight);
      builder.color(middle);
      final c = builder.addVertex(midRight);
      final d = builder.addVertex(midLeft);
      builder.color(tip);
      final e = builder.addVertex(tipPoint);
      builder
        ..addTriangle(a, b, c)
        ..addTriangle(a, c, d)
        ..addTriangle(d, c, e);
    }
    return builder.build();
  }
}

class _SuperUltraTick extends Component {
  _SuperUltraTick(this.rig);

  final SuperUltraRig rig;

  @override
  void update(double deltaSeconds) => rig._tick(deltaSeconds);
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

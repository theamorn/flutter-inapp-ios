/// Super Ultra rain: falling streaks that collide with the island, and a
/// splash wherever one lands.
///
/// * **Drops** are one CPU particle system (velocity-stretched billboards)
///   falling through a box over the island. A custom module tests each drop
///   that has fallen low enough against [RainCollider] (terrain, sea, props,
///   player, NPC, balls, crates) and kills it on contact.
/// * **Splashes** are a second particle system with no spawner of its own. A
///   module injects particles at each queued hit point: a spray of droplets
///   and a brief impact flash.
/// * **Steam** puffs off the campfire where rain hits the flames.
/// * **Ripples** are a pooled `InstancedMesh` of flat rings on the water.
///
/// The ocean, ground, grass and sky shaders add the cheap GPU half (rain
/// rings over the whole sea, wet ground, an overcast sky); see
/// `SuperUltraRig.weather`. Everything here is off and unmounted when the
/// toggle is off.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_module/tabs/scene/super_ultra/rain_collision.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class SuperUltraRain {
  SuperUltraRain({
    required this.collider,
    required Texture2D dot,
    required this.fillDynamics,
    required this.waterHeightAt,
  }) {
    _dropModule = _RainDropModule(this);
    _drops = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 4200,
        shape: BoxEmitterShape(
          halfExtents: vm.Vector3(kAreaHalfSize, 0.8, kAreaHalfSize),
          direction: vm.Vector3(0.1, -1.0, 0.04),
        ),
        spawner: Spawner(rate: 0),
        modules: <ParticleModule>[_dropModule],
        lifetime: const ConstantFloat(2.4),
        startSpeed: const UniformFloat(10.5, 13.0),
        startSize: const UniformFloat(0.014, 0.024),
        startColor: ConstantColor(vm.Vector4(0.8, 0.85, 0.94, 0.55)),
        gravity: vm.Vector3(0, -2.5, 0),
        seed: 17,
      ),
      material: SpriteMaterial(colorTexture: dot)
        ..blendMode = SpriteBlendMode.alpha
        ..cameraNearFade = 0.6,
    )
      ..facing = BillboardFacing.velocityStretched
      ..velocityStretch = 0.055;

    _splashes = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 1400,
        shape: PointEmitterShape(),
        spawner: Spawner(rate: 0),
        modules: <ParticleModule>[
          _splashModule,
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(0.92, 0.95, 1.0, 0.85)),
                ColorStop(0.6, vm.Vector4(0.85, 0.9, 0.98, 0.5)),
                ColorStop(1.0, vm.Vector4(0.8, 0.86, 0.95, 0.0)),
              ]),
            ),
          ),
        ],
        gravity: vm.Vector3(0, -9.8, 0),
        seed: 19,
      ),
      material: SpriteMaterial(colorTexture: dot)
        ..blendMode = SpriteBlendMode.alpha,
    )
      ..facing = BillboardFacing.velocityStretched
      ..velocityStretch = 0.02;

    _steam = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 60,
        shape: PointEmitterShape(),
        spawner: Spawner(rate: 0),
        modules: <ParticleModule>[
          _steamModule,
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(0.8, 0.8, 0.82, 0.0)),
                ColorStop(0.2, vm.Vector4(0.8, 0.8, 0.82, 0.32)),
                ColorStop(1.0, vm.Vector4(0.7, 0.7, 0.74, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(CurveFloat(ParticleCurve.linear(from: 1.0, to: 3.0))),
        ],
        gravity: vm.Vector3(0, 0.5, 0),
        seed: 23,
      ),
      material: SpriteMaterial(colorTexture: dot)
        ..blendMode = SpriteBlendMode.alpha
        ..softDepthFade = 0.2,
    );

    _ripples = InstancedMesh(
      geometry: RingGeometry(innerRadius: 0.86, outerRadius: 1.0, segments: 20),
      material: UnlitMaterial()
        ..alphaMode = AlphaMode.blend
        ..baseColorFactor = vm.Vector4(0.86, 0.92, 1.0, 1.0),
    );
    for (var i = 0; i < kRippleCount; i++) {
      _ripples.addInstance(_hidden, color: vm.Vector4(1, 1, 1, 0));
      _rippleAge[i] = kRippleLife;
    }

    Node emitterNode(String name, ParticleEmitterComponent emitter) =>
        Node(name: name)
          ..castsShadows = false
          ..addComponent(emitter);
    root
      ..add(emitterNode('su_rain_drops', _drops))
      ..add(emitterNode('su_rain_splashes', _splashes))
      ..add(emitterNode('su_rain_steam', _steam))
      ..add(
        Node(name: 'su_rain_ripples')
          ..castsShadows = false
          ..addComponent(InstancedMeshComponent(_ripples)),
      )
      ..addComponent(_RainTick(this));
  }

  /// Half the side of the square the rain falls over, centred on the island.
  static const double kAreaHalfSize = 27.0;

  /// Height the drops start at: above the top of the Super Ultra frame.
  static const double kRainTop = 18.0;

  /// Drops spawned per second at full strength.
  static const double kFullRate = 2300.0;

  /// Share of drops spawned over the characters instead of the whole island.
  /// Uniform rain over ~2,900 m² lands on a character about once every eight
  /// seconds, so hits on the player and NPC would never be seen; aiming a
  /// share of the (real, colliding) drops at them makes their splashes read
  /// without raising the total.
  static const double kFocusShare = 0.3;

  /// Half the side of the square over each character that focus drops fall
  /// in, and how far upwind they start so the wind carries them onto it.
  static const double kFocusHalfSize = 3.0;
  static final vm.Vector2 kWindDrift = vm.Vector2(-1.7, -0.7);

  static const int kRippleCount = 128;
  static const double kRippleLife = 0.75;

  final RainCollider collider;

  /// Rewrites the moving obstacles; called once per simulation step.
  final void Function(RainDynamics dynamics) fillDynamics;

  /// The visible sea surface height at (x, z).
  final double Function(double x, double z) waterHeightAt;

  final Node root = Node(name: 'su_rain');
  final RainDynamics dynamics = RainDynamics();

  late final _RainDropModule _dropModule;
  late final ParticleEmitterComponent _drops;
  late final ParticleEmitterComponent _splashes;
  late final ParticleEmitterComponent _steam;
  final _SplashModule _splashModule = _SplashModule();
  final _SteamModule _steamModule = _SteamModule();
  late final InstancedMesh _ripples;
  final Float32List _rippleAge = Float32List(kRippleCount);
  final Float32List _ripplePos = Float32List(kRippleCount * 3);
  int _nextRipple = 0;
  final math.Random _random = math.Random(29);

  /// 0 (dry) to 1 (full rain), eased by the owner. Scales the spawn rate.
  double level = 0.0;

  int _hitsThisWindow = 0;
  double _window = 0.0;

  /// Drops currently falling.
  int get dropsInFlight => _drops.system.storage.aliveCount;

  /// Splash particles currently alive.
  int get splashParticles => _splashes.system.storage.aliveCount;

  /// Drops that hit something per second, averaged over the last second.
  double hitsPerSecond = 0.0;

  /// True once the rain has stopped and every drop and splash has landed.
  bool get isIdle =>
      level <= 0.0 &&
      dropsInFlight == 0 &&
      splashParticles == 0 &&
      _steam.system.storage.aliveCount == 0;

  /// How much light falls on the rain, 0..1. Drops, splashes, steam and
  /// ripples are unlit (sprites and an unlit ring), so without this they
  /// glow white at night.
  void setLight(double brightness) {
    final b = brightness.clamp(0.05, 1.0);
    final tint = vm.Vector4(b, b, b, 1.0);
    _drops.material.tint = tint;
    _splashes.material.tint = tint;
    _steam.material.tint = tint;
    (_ripples.material as UnlitMaterial).baseColorFactor =
        vm.Vector4(0.86 * b, 0.92 * b, b, 1.0);
  }

  /// Drops everything in flight, for when Super Ultra is left mid-shower.
  void reset() {
    level = 0.0;
    _drops.system.reset();
    _splashes.system.reset();
    _steam.system.reset();
    for (var i = 0; i < kRippleCount; i++) {
      _rippleAge[i] = kRippleLife;
    }
    _ripplesDirty = true;
    hitsPerSecond = 0.0;
  }

  void _onHit(RainHit hit) {
    _hitsThisWindow++;
    switch (hit.surface) {
      case RainSurface.fire:
        if (_random.nextDouble() < 0.5) {
          _steamModule.queue(hit.x, hit.y, hit.z);
        }
      case RainSurface.water:
        // Most of the sea's rain is drawn by the ocean shader's rain rings;
        // only a share of the real hits gets a particle splash and a ring.
        final roll = _random.nextDouble();
        if (roll < 0.2) {
          final y = waterHeightAt(hit.x, hit.z);
          _splashModule.queue(hit.x, y, hit.z, hit.surface);
          if (roll < 0.08) {
            _addRipple(hit.x, y, hit.z);
          }
        }
      case RainSurface.ground:
        // A splash for every drop turns bare ground into snow; an eighth of
        // them reads as rain landing.
        if (_random.nextDouble() < 0.12) {
          _splashModule.queue(hit.x, hit.y, hit.z, hit.surface);
        }
      case RainSurface.prop:
      case RainSurface.character:
      case RainSurface.ball:
        _splashModule.queue(hit.x, hit.y, hit.z, hit.surface);
    }
  }

  void _addRipple(double x, double y, double z) {
    final i = _nextRipple;
    _nextRipple = (_nextRipple + 1) % kRippleCount;
    _rippleAge[i] = 0.0;
    _ripplePos[i * 3] = x;
    _ripplePos[i * 3 + 1] = y + 0.012;
    _ripplePos[i * 3 + 2] = z;
  }

  void _tick(double dt) {
    _drops.system.spawner.rate = kFullRate * level;

    _window += dt;
    if (_window >= 0.5) {
      hitsPerSecond = hitsPerSecond * 0.5 + (_hitsThisWindow / _window) * 0.5;
      _hitsThisWindow = 0;
      _window = 0.0;
    }

    var anyRipple = false;
    for (var i = 0; i < kRippleCount; i++) {
      if (_rippleAge[i] < kRippleLife) {
        _rippleAge[i] += dt;
        anyRipple = true;
      }
    }
    if (!anyRipple && !_ripplesDirty) {
      return;
    }
    _ripplesDirty = anyRipple;
    _ripples.updateInstanceTransforms((matrices) {
      for (var i = 0; i < kRippleCount; i++) {
        final age = _rippleAge[i];
        final m = matrices[i];
        if (age >= kRippleLife) {
          m.setFrom(_hidden);
          continue;
        }
        final t = age / kRippleLife;
        final radius = 0.05 + 0.42 * math.pow(t, 0.7);
        m
          ..setZero()
          ..setEntry(0, 0, radius)
          ..setEntry(1, 1, 1.0)
          ..setEntry(2, 2, radius)
          ..setEntry(3, 3, 1.0)
          ..setTranslationRaw(
            _ripplePos[i * 3],
            _ripplePos[i * 3 + 1],
            _ripplePos[i * 3 + 2],
          );
      }
    }, recomputeWinding: false);
    for (var i = 0; i < kRippleCount; i++) {
      final age = _rippleAge[i];
      final t = (age / kRippleLife).clamp(0.0, 1.0);
      final alpha = age >= kRippleLife ? 0.0 : 0.3 * (1.0 - t) * (1.0 - t);
      _ripples.setInstanceColor(i, vm.Vector4(1, 1, 1, alpha));
    }
  }

  bool _ripplesDirty = false;

  /// Where an idle ripple instance waits: shrunk to nothing, under the sea.
  static final vm.Matrix4 _hidden =
      vm.Matrix4.diagonal3Values(1e-4, 1.0, 1e-4)..setTranslationRaw(0, -50, 0);
}

class _RainTick extends Component {
  _RainTick(this.rain);

  final SuperUltraRain rain;

  @override
  void update(double deltaSeconds) => rain._tick(deltaSeconds);
}

/// Lifts spawned drops to the top of the rain box, and kills every drop that
/// has reached a surface, handing the hit to the splash systems.
class _RainDropModule extends ParticleModule {
  _RainDropModule(this.rain);

  final SuperUltraRain rain;

  @override
  void spawn(ParticleStorage storage, int index) {
    storage.posY[index] += SuperUltraRain.kRainTop;
    final dynamics = rain.dynamics;
    final targets = dynamics.capsuleCount;
    final random = rain._random;
    if (targets > 0 && random.nextDouble() < SuperUltraRain.kFocusShare) {
      final k = random.nextInt(targets);
      const half = SuperUltraRain.kFocusHalfSize;
      storage.posX[index] = dynamics.capsuleX(k) +
          SuperUltraRain.kWindDrift.x +
          (random.nextDouble() * 2.0 - 1.0) * half;
      storage.posZ[index] = dynamics.capsuleZ(k) +
          SuperUltraRain.kWindDrift.y +
          (random.nextDouble() * 2.0 - 1.0) * half;
    }
  }

  @override
  void update(ParticleStorage storage, double dt) {
    final dynamics = rain.dynamics;
    rain.fillDynamics(dynamics);
    final collider = rain.collider;
    // Nothing static reaches above the tallest prop; only moving things
    // (a punched ball) can, and those are few.
    final testBelow = math.max(collider.propTop, dynamics.highestPoint) + 0.3;
    for (var i = storage.aliveCount - 1; i >= 0; i--) {
      final y = storage.posY[i];
      if (y > testBelow) {
        continue;
      }
      final hit = collider.test(storage.posX[i], y, storage.posZ[i], dynamics);
      if (hit != null) {
        rain._onHit(hit);
        storage.age[i] = storage.lifetime[i];
      }
    }
  }
}

/// Injects splash particles at queued hit points. The system it rides on has
/// no spawner; every particle comes from here.
class _SplashModule extends ParticleModule {
  static const int _capacity = 512;
  final Float32List _events = Float32List(_capacity * 4);
  int _count = 0;
  final math.Random _random = math.Random(31);

  void queue(double x, double y, double z, RainSurface surface) {
    if (_count >= _capacity) {
      return;
    }
    final o = _count * 4;
    _events[o] = x;
    _events[o + 1] = y;
    _events[o + 2] = z;
    _events[o + 3] = surface.index.toDouble();
    _count++;
  }

  @override
  void update(ParticleStorage storage, double dt) {
    for (var e = 0; e < _count; e++) {
      final o = e * 4;
      final x = _events[o];
      final y = _events[o + 1];
      final z = _events[o + 2];
      final surface = RainSurface.values[_events[o + 3].toInt()];
      final water = surface == RainSurface.water;
      final solid = surface == RainSurface.prop ||
          surface == RainSurface.character ||
          surface == RainSurface.ball;
      // Hits on things (a palm, a shoulder, a ball) get the biggest splash so
      // the collision reads; bare ground the smallest.
      final droplets = water || solid ? 3 : 2;
      for (var d = 0; d < droplets; d++) {
        final angle = _random.nextDouble() * math.pi * 2.0;
        final out = water
            ? 0.2 + 0.4 * _random.nextDouble()
            : 0.3 + 0.6 * _random.nextDouble();
        final kick = _random.nextDouble();
        // Water throws a taller crown than soil; a leaf or a shoulder barely
        // bounces the drop.
        final up = water
            ? 1.3 + 1.2 * kick
            : (solid ? 0.5 + 0.8 * kick : 0.9 + 1.1 * kick);
        _emit(
          storage,
          x,
          y + 0.01,
          z,
          math.cos(angle) * out,
          up,
          math.sin(angle) * out,
          lifetime: 0.22 + 0.2 * _random.nextDouble(),
          size: 0.016 + 0.012 * _random.nextDouble(),
        );
      }
      // The impact itself: a small bright flash at the contact point.
      _emit(storage, x, y + 0.02, z, 0.0, 0.05, 0.0,
          lifetime: solid ? 0.1 : 0.07,
          size: solid ? 0.06 : (water ? 0.04 : 0.035));
    }
    _count = 0;
  }

  void _emit(
    ParticleStorage s,
    double x,
    double y,
    double z,
    double vx,
    double vy,
    double vz, {
    required double lifetime,
    required double size,
  }) {
    final i = s.spawn();
    if (i < 0) {
      return;
    }
    _initParticle(s, i, x, y, z, vx, vy, vz, lifetime, size, _random);
  }
}

/// Injects steam puffs where rain hits the campfire.
class _SteamModule extends ParticleModule {
  static const int _capacity = 32;
  final Float32List _events = Float32List(_capacity * 3);
  int _count = 0;
  final math.Random _random = math.Random(37);

  void queue(double x, double y, double z) {
    if (_count >= _capacity) {
      return;
    }
    final o = _count * 3;
    _events[o] = x;
    _events[o + 1] = y;
    _events[o + 2] = z;
    _count++;
  }

  @override
  void update(ParticleStorage storage, double dt) {
    for (var e = 0; e < _count; e++) {
      final o = e * 3;
      final i = storage.spawn();
      if (i < 0) {
        break;
      }
      _initParticle(
        storage,
        i,
        _events[o] + (_random.nextDouble() - 0.5) * 0.2,
        _events[o + 1] + 0.15,
        _events[o + 2] + (_random.nextDouble() - 0.5) * 0.2,
        (_random.nextDouble() - 0.5) * 0.15,
        0.35 + 0.3 * _random.nextDouble(),
        (_random.nextDouble() - 0.5) * 0.15,
        0.9 + 0.5 * _random.nextDouble(),
        0.1 + 0.08 * _random.nextDouble(),
        _random,
      );
    }
    _count = 0;
  }
}

/// Writes every column a particle system would at spawn, for particles
/// created by hand (the system's own spawn path is not involved).
void _initParticle(
  ParticleStorage s,
  int i,
  double x,
  double y,
  double z,
  double vx,
  double vy,
  double vz,
  double lifetime,
  double size,
  math.Random random,
) {
  s.posX[i] = x;
  s.posY[i] = y;
  s.posZ[i] = z;
  s.velX[i] = vx;
  s.velY[i] = vy;
  s.velZ[i] = vz;
  s.age[i] = 0.0;
  s.lifetime[i] = lifetime;
  s.size[i] = size;
  s.baseSize[i] = size;
  s.rotation[i] = 0.0;
  s.angularVelocity[i] = 0.0;
  s.colorR[i] = 1.0;
  s.colorG[i] = 1.0;
  s.colorB[i] = 1.0;
  s.colorA[i] = 1.0;
  s.frame[i] = 0.0;
  s.axisX[i] = 0.0;
  s.axisY[i] = 1.0;
  s.axisZ[i] = 0.0;
  s.random01[i] = random.nextDouble();
}

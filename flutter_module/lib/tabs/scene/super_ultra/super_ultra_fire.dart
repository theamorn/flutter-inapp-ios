/// The Super Ultra campfire.
///
/// Ultra's fire is three untextured sprite emitters, which read as glowing
/// blobs. This one is built the way game VFX fire is:
///
/// * flame tongues from a baked flipbook ([generateFlameAtlas]), upright
///   (`axisLocked`), licked sideways by curl-noise turbulence, and HDR hot so
///   bloom finds the core;
/// * a bright core glow, long-lived turbulent embers streaking with their
///   velocity, and occasional spark pops;
/// * smoke from a puff atlas, warm at the base and grey above;
/// * a bed of glowing coals under the logs (`ember_bed.fmat`);
/// * heat shimmer above the flames (`heat_haze.fmat`).
library;

import 'package:flutter_module/tabs/scene/super_ultra/procedural_textures.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Textures the fire samples. Uploaded once by the rig.
class FireTextures {
  const FireTextures({
    required this.flames,
    required this.smoke,
    required this.dot,
  });

  final Texture2D flames;
  final Texture2D smoke;
  final Texture2D dot;
}

class SuperUltraFire {
  SuperUltraFire({
    required FireTextures textures,
    required this.emberMaterial,
    required this.hazeMaterial,
    required vm.Vector3 base,
  })  : _bedCentre = vm.Vector2(base.x, base.z),
        root = Node(name: 'super_ultra_fire') {
    _flames = _emitter(
      name: 'su_flames',
      at: base + vm.Vector3(0, 0.1, 0),
      system: ParticleSystem(
        maxParticles: 44,
        shape: const ConeEmitterShape(angle: 0.2, radius: 0.15),
        spawner: Spawner(rate: 34),
        modules: <ParticleModule>[
          const FlipbookModule(frameCount: kFlameAtlasColumns * kFlameAtlasRows),
          TurbulenceModule(
            strength: 1.2,
            frequency: 1.7,
            scroll: vm.Vector3(0, 1.5, 0),
            seed: 71,
          ),
          const RotationModule(),
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(3.6, 2.5, 1.2, 0.0)),
                ColorStop(0.08, vm.Vector4(3.4, 2.0, 0.75, 1.0)),
                ColorStop(0.4, vm.Vector4(2.6, 1.05, 0.22, 0.95)),
                ColorStop(0.75, vm.Vector4(1.2, 0.3, 0.05, 0.6)),
                ColorStop(1.0, vm.Vector4(0.25, 0.04, 0.01, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(
              ParticleCurve(<ParticleKeyframe>[
                ParticleKeyframe(0.0, 0.7),
                ParticleKeyframe(0.35, 1.05),
                ParticleKeyframe(1.0, 0.8),
              ]),
            ),
          ),
        ],
        lifetime: const UniformFloat(0.55, 0.95),
        startSpeed: const UniformFloat(0.45, 0.9),
        startSize: const UniformFloat(0.34, 0.54),
        startRotation: const UniformFloat(-0.25, 0.25),
        startAngularVelocity: const UniformFloat(-0.6, 0.6),
        gravity: vm.Vector3(0, 1.0, 0),
        prewarm: 1.0,
        seed: 3,
      ),
      material: SpriteMaterial(colorTexture: textures.flames)
        ..blendMode = SpriteBlendMode.additive
        ..softDepthFade = 0.14,
      configure: (emitter) => emitter
        ..facing = BillboardFacing.axisLocked
        ..flipbookColumns = kFlameAtlasColumns
        ..flipbookRows = kFlameAtlasRows
        ..flipbookBlend = true,
    );

    _core = _emitter(
      name: 'su_fire_core',
      at: base + vm.Vector3(0, 0.22, 0),
      system: ParticleSystem(
        maxParticles: 6,
        shape: const SphereEmitterShape(radius: 0.08),
        spawner: Spawner(rate: 10),
        modules: <ParticleModule>[
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(2.8, 1.3, 0.35, 0.0)),
                ColorStop(0.3, vm.Vector4(2.8, 1.3, 0.35, 0.4)),
                ColorStop(1.0, vm.Vector4(1.6, 0.5, 0.1, 0.0)),
              ]),
            ),
          ),
        ],
        lifetime: const UniformFloat(0.25, 0.45),
        startSpeed: const UniformFloat(0.05, 0.2),
        startSize: const UniformFloat(0.7, 0.95),
        prewarm: 0.5,
        seed: 5,
      ),
      material: SpriteMaterial(colorTexture: textures.dot)
        ..blendMode = SpriteBlendMode.additive
        ..softDepthFade = 0.25,
    );

    _embers = _emitter(
      name: 'su_embers',
      at: base + vm.Vector3(0, 0.3, 0),
      system: ParticleSystem(
        maxParticles: 70,
        shape: const ConeEmitterShape(angle: 0.45, radius: 0.18),
        spawner: Spawner(rate: 22),
        modules: <ParticleModule>[
          TurbulenceModule(
            strength: 2.6,
            frequency: 0.9,
            scroll: vm.Vector3(0, 0.8, 0),
            seed: 73,
          ),
          LinearDragModule(0.6),
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(6.0, 2.6, 0.7, 1.0)),
                ColorStop(0.45, vm.Vector4(4.0, 1.2, 0.2, 0.9)),
                ColorStop(1.0, vm.Vector4(1.0, 0.15, 0.02, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(ParticleCurve.linear(from: 1.0, to: 0.4)),
          ),
        ],
        lifetime: const UniformFloat(1.4, 2.8),
        startSpeed: const UniformFloat(1.1, 2.3),
        startSize: const UniformFloat(0.022, 0.042),
        gravity: vm.Vector3(0, 0.55, 0),
        prewarm: 2.0,
        seed: 7,
      ),
      material: SpriteMaterial(colorTexture: textures.dot)
        ..blendMode = SpriteBlendMode.additive,
      configure: (emitter) => emitter
        ..facing = BillboardFacing.velocityStretched
        ..velocityStretch = 0.035,
    );

    _sparks = _emitter(
      name: 'su_sparks',
      at: base + vm.Vector3(0, 0.25, 0),
      system: ParticleSystem(
        maxParticles: 36,
        shape: const ConeEmitterShape(angle: 0.65, radius: 0.1),
        spawner: Spawner(
          rate: 2,
          bursts: const <ParticleBurst>[
            ParticleBurst(time: 0.4, count: 9, interval: 2.3),
            ParticleBurst(time: 1.7, count: 6, interval: 3.1),
          ],
        ),
        modules: <ParticleModule>[
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(8.0, 5.0, 1.6, 1.0)),
                ColorStop(0.5, vm.Vector4(5.0, 1.8, 0.3, 0.9)),
                ColorStop(1.0, vm.Vector4(1.5, 0.2, 0.02, 0.0)),
              ]),
            ),
          ),
        ],
        lifetime: const UniformFloat(0.35, 0.75),
        startSpeed: const UniformFloat(2.4, 4.6),
        startSize: const UniformFloat(0.018, 0.03),
        gravity: vm.Vector3(0, -3.2, 0),
        duration: 6.2,
        seed: 11,
      ),
      material: SpriteMaterial(colorTexture: textures.dot)
        ..blendMode = SpriteBlendMode.additive,
      configure: (emitter) => emitter
        ..facing = BillboardFacing.velocityStretched
        ..velocityStretch = 0.06,
    );

    _smoke = _emitter(
      name: 'su_smoke',
      at: base + vm.Vector3(0, 0.75, 0),
      system: ParticleSystem(
        maxParticles: 28,
        shape: const ConeEmitterShape(angle: 0.18, radius: 0.12),
        spawner: Spawner(rate: 8),
        modules: <ParticleModule>[
          const FlipbookModule(
            frameCount: kSmokeAtlasColumns * kSmokeAtlasRows,
            framesPerSecond: 0.01,
            randomStartFrame: true,
          ),
          TurbulenceModule(
            strength: 0.55,
            frequency: 0.55,
            scroll: vm.Vector3(0, 0.6, 0),
            seed: 79,
          ),
          LinearDragModule(0.35),
          const RotationModule(),
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(0.62, 0.38, 0.22, 0.0)),
                ColorStop(0.12, vm.Vector4(0.44, 0.38, 0.34, 0.34)),
                ColorStop(0.55, vm.Vector4(0.34, 0.34, 0.36, 0.2)),
                ColorStop(1.0, vm.Vector4(0.3, 0.3, 0.33, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(ParticleCurve.linear(from: 0.8, to: 3.4)),
          ),
        ],
        lifetime: const UniformFloat(2.2, 3.4),
        startSpeed: const UniformFloat(0.35, 0.6),
        startSize: const UniformFloat(0.34, 0.52),
        startRotation: const UniformFloat(-3.14, 3.14),
        startAngularVelocity: const UniformFloat(-0.4, 0.4),
        gravity: vm.Vector3(0, 0.4, 0),
        prewarm: 3.0,
        seed: 13,
      ),
      material: SpriteMaterial(colorTexture: textures.smoke)
        ..blendMode = SpriteBlendMode.alpha
        ..softDepthFade = 0.35
        ..cameraNearFade = 1.2,
      configure: (emitter) => emitter
        ..flipbookColumns = kSmokeAtlasColumns
        ..flipbookRows = kSmokeAtlasRows,
    );

    emberMaterial.parameters
        .setVec4('bed', vm.Vector4(base.x, base.z, _bedRadius, 1.0));
    final emberBed = Node(
      name: 'su_ember_bed',
      mesh: Mesh(
        DiscGeometry(radius: _bedRadius, segments: 40),
        emberMaterial,
      ),
    )
      ..position = base + vm.Vector3(0, 0.012, 0)
      ..castsShadows = false;
    root.add(emberBed);

    final hazeNode = Node(
      name: 'su_heat_haze',
      mesh: Mesh(_hazeQuad(width: 1.1, height: 1.9), hazeMaterial),
    )
      ..position = base + vm.Vector3(0, 0.45, 0)
      ..castsShadows = false;
    root.add(hazeNode);
  }

  static const double _bedRadius = 0.46;

  final Node root;
  final vm.Vector2 _bedCentre;
  final PreprocessedMaterial emberMaterial;
  final PreprocessedMaterial hazeMaterial;
  late final ParticleEmitterComponent _flames;
  late final ParticleEmitterComponent _core;
  late final ParticleEmitterComponent _embers;
  late final ParticleEmitterComponent _sparks;
  late final ParticleEmitterComponent _smoke;

  List<ParticleEmitterComponent> get _emitters =>
      <ParticleEmitterComponent>[_flames, _core, _embers, _sparks, _smoke];

  ParticleEmitterComponent _emitter({
    required String name,
    required vm.Vector3 at,
    required ParticleSystem system,
    required SpriteMaterial material,
    void Function(ParticleEmitterComponent emitter)? configure,
  }) {
    final emitter = ParticleEmitterComponent(system: system, material: material);
    configure?.call(emitter);
    root.add(
      Node(name: name)
        ..position = at
        ..castsShadows = false
        ..addComponent(emitter),
    );
    return emitter;
  }

  /// Drives the fire from the campfire's flicker. [intensity] is 0 (out) to
  /// about 1.3 (flaring); [time] is seconds since the rig was built.
  void update({required double intensity, required double time}) {
    final lit = intensity > 0.02;
    for (final emitter in _emitters) {
      emitter.paused = !lit;
      emitter.node.visible = lit;
    }
    final strength = intensity.clamp(0.0, 1.4);
    _flames.material.tint = vm.Vector4(1, 1, 1, strength.clamp(0.0, 1.0));
    _core.material.tint = vm.Vector4.all(strength);
    // The coals never go fully dark: a doused fire still smoulders.
    emberMaterial.parameters
      ..setFloat('time', time)
      ..setVec4(
        'bed',
        vm.Vector4(
          _bedCentre.x,
          _bedCentre.y,
          _bedRadius,
          0.18 + 0.82 * strength.clamp(0.0, 1.2),
        ),
      );
    hazeMaterial.parameters
      ..setFloat('time', time)
      ..setVec4('haze', vm.Vector4(0.006, strength.clamp(0.0, 1.0), 0, 0));
  }

  /// An XY quad with its base on y = 0 and uv.y = 0 at the bottom, for
  /// `heat_haze.fmat` to turn toward the camera.
  static MeshGeometry _hazeQuad({required double width, required double height}) {
    final builder = GeometryBuilder(deduplicate: false)
      ..normal(vm.Vector3(0, 0, 1));
    final half = width / 2;
    builder.texCoord(vm.Vector2(0, 0));
    final a = builder.addVertex(vm.Vector3(-half, 0, 0));
    builder.texCoord(vm.Vector2(1, 0));
    final b = builder.addVertex(vm.Vector3(half, 0, 0));
    builder.texCoord(vm.Vector2(1, 1));
    final c = builder.addVertex(vm.Vector3(half, height, 0));
    builder.texCoord(vm.Vector2(0, 1));
    final d = builder.addVertex(vm.Vector3(-half, height, 0));
    builder
      ..addTriangle(a, b, c)
      ..addTriangle(a, c, d);
    return builder.build();
  }
}

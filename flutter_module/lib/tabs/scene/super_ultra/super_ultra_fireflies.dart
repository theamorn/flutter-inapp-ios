/// Nocturnal curl-noise fireflies drifting across the island's grassy clearing
/// on clear evenings and nights.
///
/// Uses a single 36-particle `ParticleSystem` driven by `TurbulenceModule` and
/// `LinearDragModule`, with a two-pulse HDR chartreuse-gold
/// `ColorOverLifeModule` that bloom catches softly. Automatically pauses and
/// hides during the day or in rain so daytime/storm frames pay zero CPU or GPU
/// cost.
library;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Smooth 0..1 visibility and emission weight for fireflies from [night]
/// (0 = day, 1 = night) and [weather] (0 = clear, 1 = storm).
double fireflyActivityFor({required double night, required double weather}) {
  final n = night.isNaN ? 0.0 : night.clamp(0.0, 1.0);
  final w = weather.isNaN ? 0.0 : weather.clamp(0.0, 1.0);
  final duskRise = ((n - 0.35) / (0.82 - 0.35)).clamp(0.0, 1.0);
  final nightCurve = duskRise * duskRise * (3.0 - 2.0 * duskRise);
  final dry = (1.0 - w * 1.4).clamp(0.0, 1.0);
  return (nightCurve * dry).clamp(0.0, 1.0);
}

class SuperUltraFireflies {
  SuperUltraFireflies({required Texture2D dot, required int layerMask})
    : root = Node(name: 'su_fireflies') {
    _emitter = ParticleEmitterComponent(
      system: ParticleSystem(
        maxParticles: 36,
        shape: BoxEmitterShape(
          halfExtents: vm.Vector3(10.5, 0.95, 10.5),
          direction: vm.Vector3(0, 1, 0),
        ),
        spawner: Spawner(rate: 8.5),
        modules: <ParticleModule>[
          TurbulenceModule(
            strength: 0.75,
            frequency: 0.48,
            scroll: vm.Vector3(0.12, 0.08, 0.10),
            seed: 89,
          ),
          LinearDragModule(0.85),
          ColorOverLifeModule(
            GradientColor(
              ColorGradient(<ColorStop>[
                ColorStop(0.0, vm.Vector4(2.4, 3.2, 0.45, 0.0)),
                ColorStop(0.18, vm.Vector4(3.2, 4.1, 0.62, 0.95)),
                ColorStop(0.45, vm.Vector4(1.6, 2.2, 0.32, 0.22)),
                ColorStop(0.74, vm.Vector4(3.0, 3.8, 0.56, 0.90)),
                ColorStop(1.0, vm.Vector4(1.8, 2.4, 0.35, 0.0)),
              ]),
            ),
          ),
          SizeOverLifeModule(
            CurveFloat(
              ParticleCurve(<ParticleKeyframe>[
                ParticleKeyframe(0.0, 0.4),
                ParticleKeyframe(0.20, 1.1),
                ParticleKeyframe(0.48, 0.65),
                ParticleKeyframe(0.75, 1.05),
                ParticleKeyframe(1.0, 0.3),
              ]),
            ),
          ),
        ],
        lifetime: const UniformFloat(3.4, 5.6),
        startSpeed: const UniformFloat(0.08, 0.26),
        startSize: const UniformFloat(0.075, 0.135),
        gravity: vm.Vector3(0, 0.02, 0),
        prewarm: 4.0,
        seed: 23,
      ),
      material: SpriteMaterial(colorTexture: dot)
        ..blendMode = SpriteBlendMode.additive
        ..softDepthFade = 0.25
        ..cameraNearFade = 0.8,
    );
    root
      ..position = vm.Vector3(0, 1.15, 0)
      ..layers = layerMask
      ..shadowCastingMode = ShadowCastingMode.off
      ..visible = false
      ..addComponent(_emitter);
    _emitter.paused = true;
  }

  final Node root;
  late final ParticleEmitterComponent _emitter;
  bool _enabled = true;
  double _night = 0.0;
  double _weather = 0.0;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
    _sync();
  }

  void update({required double night, required double weather}) {
    _night = night;
    _weather = weather;
    _sync();
  }

  void _sync() {
    final activity = _enabled
        ? fireflyActivityFor(night: _night, weather: _weather)
        : 0.0;
    final active = activity > 0.02;
    _emitter.paused = !active;
    root.visible = active;
    if (active) {
      _emitter.material.tint = vm.Vector4(1.0, 1.0, 1.0, activity);
    }
  }
}

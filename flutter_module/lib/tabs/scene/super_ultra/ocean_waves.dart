/// The Super Ultra sea's wave table, shared by the GPU and the CPU.
///
/// `assets/materials/ocean.fmat` displaces the sea in its `vertex { }` block;
/// buoys and balls ask [WaterSurfaceComponent.evaluateAt] on the CPU. Both read
/// the waves from here and are driven by the same clock, so a crate never bobs
/// out of phase with the water it sits in. The GPU formula is transliterated
/// in [oceanDisplacementFromPacked] so a unit test can hold the two together.
library;

import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show GerstnerWave;
import 'package:vector_math/vector_math.dart' as vm;

/// The ocean shader evaluates exactly this many waves: one `mat4` column each.
const int kOceanWaveCount = 4;

/// Gravity used by `WaterSurfaceComponent` for the deep-water dispersion
/// relation. Must match the engine, or the GPU and CPU drift apart over time.
const double kOceanGravity = 9.81;

/// Radius where the GPU starts fading the waves out. Beyond it the sea mesh is
/// too coarse to carry them, and a 2 m wave on a 10 m grid aliases into noise.
/// Every CPU sample point (buoys, balls) sits well inside it.
const double kOceanWaveFadeStart = 70.0;
const double kOceanWaveFadeEnd = 150.0;

/// Four directional Gerstner waves, longest first. Kept small: this is a
/// sheltered lagoon, and a big swell would bury the shallow seabed that the
/// clear water is there to show.
List<GerstnerWave> superUltraWaves() => <GerstnerWave>[
      GerstnerWave(
        direction: vm.Vector2(1.0, 0.25)..normalize(),
        amplitude: 0.16,
        wavelength: 16.0,
        speed: 0.9,
        steepness: 0.55,
      ),
      GerstnerWave(
        direction: vm.Vector2(0.45, 0.9)..normalize(),
        amplitude: 0.085,
        wavelength: 8.5,
        speed: 1.0,
        steepness: 0.6,
      ),
      GerstnerWave(
        direction: vm.Vector2(-0.6, 0.8)..normalize(),
        amplitude: 0.045,
        wavelength: 4.2,
        speed: 1.1,
        steepness: 0.5,
      ),
      GerstnerWave(
        direction: vm.Vector2(0.85, -0.5)..normalize(),
        amplitude: 0.022,
        wavelength: 2.3,
        speed: 1.2,
        steepness: 0.45,
      ),
    ];

/// Packs [waves] into the two `mat4` parameters `ocean.fmat` reads.
///
/// Column `i` of `shape` is `(dir.x, dir.z, amplitude, k)` and column `i` of
/// `motion` is `(omega, q * amplitude, q * k * amplitude, 0)`, where
/// `k = 2π / wavelength`, `omega = speed * sqrt(g / k) * k`, and
/// `q = steepness / (k * amplitude * waveCount)` — the exact terms
/// `WaterSurfaceComponent.evaluateAt` uses, precomputed so the vertex shader
/// does no square roots.
({vm.Matrix4 shape, vm.Matrix4 motion}) packOceanWaves(
  List<GerstnerWave> waves,
) {
  if (waves.length > kOceanWaveCount) {
    throw ArgumentError.value(
      waves.length,
      'waves',
      'the ocean shader evaluates at most $kOceanWaveCount waves',
    );
  }
  final shape = vm.Matrix4.zero();
  final motion = vm.Matrix4.zero();
  final count = waves.length;
  for (var i = 0; i < count; i++) {
    final wave = waves[i];
    if (wave.amplitude <= 0.0 || wave.wavelength <= 0.0) {
      continue;
    }
    final k = 2 * math.pi / wave.wavelength;
    final omega = wave.speed * math.sqrt(kOceanGravity / k) * k;
    final q = wave.steepness / (k * wave.amplitude * count);
    shape.setColumn(
      i,
      vm.Vector4(wave.direction.x, wave.direction.y, wave.amplitude, k),
    );
    motion.setColumn(
      i,
      vm.Vector4(omega, q * wave.amplitude, q * k * wave.amplitude, 0.0),
    );
  }
  return (shape: shape, motion: motion);
}

/// The ocean shader's displacement, in Dart. Test-only: it exists so a test
/// can prove the packed parameters reproduce `WaterSurfaceComponent`.
///
/// Ignores the far-field fade, which starts at [kOceanWaveFadeStart].
vm.Vector3 oceanDisplacementFromPacked(
  vm.Matrix4 shape,
  vm.Matrix4 motion,
  vm.Vector2 position,
  double time,
) {
  final displacement = vm.Vector3.zero();
  for (var i = 0; i < kOceanWaveCount; i++) {
    final s = shape.getColumn(i);
    final m = motion.getColumn(i);
    if (s.z <= 0.0) {
      continue;
    }
    final phase = s.w * (s.x * position.x + s.y * position.y) - m.x * time;
    final c = math.cos(phase);
    final sn = math.sin(phase);
    displacement.x += m.y * s.x * c;
    displacement.y += s.z * sn;
    displacement.z += m.y * s.y * c;
  }
  return displacement;
}

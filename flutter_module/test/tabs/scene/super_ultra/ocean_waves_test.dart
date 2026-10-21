import 'package:flutter_module/tabs/scene/super_ultra/ocean_waves.dart';
import 'package:flutter_scene/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('packOceanWaves', () {
    test('the shader formula reproduces WaterSurfaceComponent exactly', () {
      final waves = superUltraWaves();
      final packed = packOceanWaves(waves);
      final surface = WaterSurfaceComponent(waves: waves);
      for (final time in <double>[0.0, 0.37, 4.2, 61.5, 600.0]) {
        for (final point in <vm.Vector2>[
          vm.Vector2(12.2, 1.8),
          vm.Vector2(-16.0, 6.0),
          vm.Vector2(3.0, -40.0),
          vm.Vector2(55.0, 20.0),
        ]) {
          final cpu = surface.evaluateAt(point, time).displacement;
          final gpu = oceanDisplacementFromPacked(
            packed.shape,
            packed.motion,
            point,
            time,
          );
          // float32 storage in Matrix4/Vector3: compare at float precision.
          expect(gpu.x, closeTo(cpu.x, 2e-4), reason: 'x at $point t=$time');
          expect(gpu.y, closeTo(cpu.y, 2e-4), reason: 'y at $point t=$time');
          expect(gpu.z, closeTo(cpu.z, 2e-4), reason: 'z at $point t=$time');
        }
      }
    });

    test('fills one column per wave and leaves the rest zero', () {
      final packed = packOceanWaves(superUltraWaves().take(3).toList());
      expect(packed.shape.getColumn(3), vm.Vector4.zero());
      expect(packed.motion.getColumn(3), vm.Vector4.zero());
      expect(packed.shape.getColumn(0).z, greaterThan(0));
    });

    test('rejects more waves than the shader evaluates', () {
      final waves = <GerstnerWave>[
        ...superUltraWaves(),
        GerstnerWave(direction: vm.Vector2(1, 0)),
      ];
      expect(() => packOceanWaves(waves), throwsArgumentError);
    });

    test('every wave stays inside the shader budget and is gentle', () {
      final waves = superUltraWaves();
      expect(waves.length, kOceanWaveCount);
      final crest = waves.fold<double>(0, (sum, w) => sum + w.amplitude);
      // A lagoon, not a swell: the seabed has to stay readable.
      expect(crest, lessThan(0.4));
    });
  });
}

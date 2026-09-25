import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/super_ultra/sky_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('moonDirectionFor', () {
    test('is a unit vector at every hour', () {
      for (var hour = 0.0; hour < 24.0; hour += 0.25) {
        expect(moonDirectionFor(hour).length, closeTo(1.0, 1e-5));
      }
    });

    test('is up all night and down at midday', () {
      for (final hour in <double>[20.5, 22.0, 0.0, 1.5, 3.0, 5.0]) {
        expect(moonDirectionFor(hour).y, greaterThan(0.05), reason: '$hour h');
      }
      for (final hour in <double>[10.0, 12.0, 14.0]) {
        expect(moonDirectionFor(hour).y, lessThan(0.0), reason: '$hour h');
      }
    });

    test('never climbs out of frame', () {
      for (var hour = 0.0; hour < 24.0; hour += 0.1) {
        expect(
          elevationOf(moonDirectionFor(hour)),
          lessThanOrEqualTo(kMoonPeakElevation + 1e-6),
        );
      }
      expect(
        elevationOf(moonDirectionFor(kMoonTransitHour)),
        closeTo(kMoonPeakElevation, 1e-5),
      );
    });

    test('rises in the east (-x) and sets in the west (+x)', () {
      final rise = moonDirectionFor(kMoonTransitHour - 6.0 + 24.0);
      final set = moonDirectionFor(kMoonTransitHour + 6.0);
      expect(rise.x, lessThan(-0.9));
      expect(set.x, greaterThan(0.9));
      // At transit it sits opposite the noon sun, which is toward +z.
      expect(moonDirectionFor(kMoonTransitHour).z, lessThan(-0.8));
    });
  });

  test('orbitAzimuthFacing points the camera at the heading', () {
    for (final angle in <double>[-2.5, -0.4, 0.0, 0.9, 3.0]) {
      final heading = vm.Vector3(math.sin(angle), 0.3, math.cos(angle));
      final azimuth = orbitAzimuthFacing(heading);
      // OrbitCameraController looks along +(sin a, cos a). Vector3 is
      // float32, so compare at float precision.
      expect(math.sin(azimuth), closeTo(math.sin(angle), 1e-6));
      expect(math.cos(azimuth), closeTo(math.cos(angle), 1e-6));
    }
  });

  test('the key light swaps to the moon past mid-twilight', () {
    expect(moonIsKeyLight(0.2), isFalse);
    expect(moonIsKeyLight(0.8), isTrue);
  });
}

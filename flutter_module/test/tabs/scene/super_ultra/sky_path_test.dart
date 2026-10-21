import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/super_ultra/sky_path.dart';
import 'package:flutter_module/tabs/scene/super_ultra/super_ultra_fireflies.dart';
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

  test('goldenHourFactor peaks at low sun elevation and vanishes at noon/night', () {
    expect(goldenHourFactor(-0.15), 0.0);
    expect(goldenHourFactor(0.10), closeTo(1.0, 1e-5));
    expect(goldenHourFactor(0.35), 0.0);
  });

  group('superUltraColorGrade', () {
    test('warms highlights and temperature at golden hour', () {
      final day = superUltraColorGrade(
        golden: 0.0,
        night: 0.0,
        rain: 0.0,
        flash: 0.0,
      );
      final golden = superUltraColorGrade(
        golden: 1.0,
        night: 0.0,
        rain: 0.0,
        flash: 0.0,
      );
      expect(golden.colorTemperature, greaterThan(day.colorTemperature));
      expect(golden.saturation, greaterThan(day.saturation));
      expect(golden.highlightTint.x, greaterThan(day.highlightTint.x));
    });

    test('shifts shadows to indigo while keeping warm fire highlights at night', () {
      final day = superUltraColorGrade(
        golden: 0.0,
        night: 0.0,
        rain: 0.0,
        flash: 0.0,
      );
      final night = superUltraColorGrade(
        golden: 0.0,
        night: 1.0,
        rain: 0.0,
        flash: 0.0,
      );
      expect(night.shadowTint.z, greaterThan(night.shadowTint.x));
      expect(night.colorTemperature, lessThan(day.colorTemperature));
      expect(night.highlightTint.x, greaterThan(1.05));
    });

    test('desaturates and cools in heavy rain, and boosts exposure on flash', () {
      final clear = superUltraColorGrade(
        golden: 0.0,
        night: 0.0,
        rain: 0.0,
        flash: 0.0,
      );
      final storm = superUltraColorGrade(
        golden: 0.0,
        night: 0.0,
        rain: 1.0,
        flash: 0.0,
      );
      final flash = superUltraColorGrade(
        golden: 0.0,
        night: 0.0,
        rain: 1.0,
        flash: 1.0,
      );
      expect(storm.saturation, lessThan(clear.saturation));
      expect(storm.colorTemperature, lessThan(clear.colorTemperature));
      expect(flash.exposureBias, greaterThan(storm.exposureBias));
    });
  });

  group('superUltraDofFocus', () {
    test('enables hero-shot bokeh in over-the-shoulder and close orbit', () {
      final ots = superUltraDofFocus(
        overTheShoulder: true,
        cameraToTargetDistance: 6.2,
      );
      expect(ots.enabled, isTrue);
      expect(ots.focalDistance, closeTo(6.2, 1e-5));
      expect(ots.fStop, closeTo(3.2, 1e-5));

      final closeOrbit = superUltraDofFocus(
        overTheShoulder: false,
        cameraToTargetDistance: 14.0,
      );
      expect(closeOrbit.enabled, isTrue);
      expect(closeOrbit.focalDistance, closeTo(14.0, 1e-5));
      expect(closeOrbit.maxBlurRadius, greaterThan(3.0));
    });

    test('disables DoF in wide orbit overviews (>= 25 m) for sharp horizon', () {
      final wideOrbit = superUltraDofFocus(
        overTheShoulder: false,
        cameraToTargetDistance: 36.0,
      );
      expect(wideOrbit.enabled, isFalse);
      expect(wideOrbit.maxBlurRadius, 0.0);
    });
  });

  group('fireflyActivityFor', () {
    test('is zero during the day and in heavy rain, and peaks on clear nights', () {
      expect(fireflyActivityFor(night: 0.0, weather: 0.0), 0.0);
      expect(fireflyActivityFor(night: 1.0, weather: 0.0), closeTo(1.0, 1e-5));
      expect(fireflyActivityFor(night: 1.0, weather: 1.0), 0.0);
      expect(
        fireflyActivityFor(night: 0.6, weather: 0.0),
        inInclusiveRange(0.2, 0.8),
      );
    });
  });
}

/// Where the Super Ultra sun and moon sit, as pure functions of the clock.
///
/// Super Ultra puts the sun and moon *in frame*. The orbit camera frames the
/// island from a few degrees above the horizon, so a body higher than ~25°
/// is off the top of the screen. The sun therefore follows a high-latitude
/// arc (it never climbs far), and the moon follows its own low arc. Lighting
/// intensity is still taken from the regular clock, so noon is bright even
/// though the sun is low.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// Latitude the Super Ultra sun path is evaluated at. With
/// `DayNightCycleComponent`'s model, 68° peaks near 22° at noon.
const double kSuperUltraSunLatitude = 68.0;

/// Highest the moon climbs, in radians.
const double kMoonPeakElevation = 20.0 * math.pi / 180.0;

/// Hour the moon crosses its highest point. Offset from midnight so it is
/// not exactly opposite the sun, which shows a waxing gibbous phase rather
/// than a flat full disc.
const double kMoonTransitHour = 1.5;

/// Unit vector toward the moon at [timeOfDay] (0..24).
///
/// It rises low in the east (-x) around dusk, crosses the -z sky (opposite
/// the noon sun, which sits toward +z) at [kMoonTransitHour] at
/// [kMoonPeakElevation], and sets in the west (+x). In daytime it is below
/// the horizon.
vm.Vector3 moonDirectionFor(double timeOfDay) {
  var hourAngle = (timeOfDay - kMoonTransitHour) / 24.0 * 2.0 * math.pi;
  hourAngle = math.atan2(math.sin(hourAngle), math.cos(hourAngle));
  final elevation = kMoonPeakElevation * math.cos(hourAngle);
  final azimuth = math.pi - hourAngle;
  return vm.Vector3(
    math.cos(elevation) * math.sin(azimuth),
    math.sin(elevation),
    math.cos(elevation) * math.cos(azimuth),
  );
}

/// Whether the moon, rather than the sun, should drive the one
/// shadow-casting light. Swapped at the midpoint of twilight, when both are
/// dim enough that the jump in shadow direction is not visible.
bool moonIsKeyLight(double nightBlend) => nightBlend > 0.5;

/// The orbit-controller azimuth that points the camera toward [direction]'s
/// horizontal heading. `OrbitCameraController` places the eye at
/// `-(sin a, 0, cos a)` from its target, so it looks along `+(sin a, cos a)`.
double orbitAzimuthFacing(vm.Vector3 direction) =>
    math.atan2(direction.x, direction.z);

/// Elevation of [direction] above the horizon, in radians.
double elevationOf(vm.Vector3 direction) {
  final length = direction.length;
  if (length == 0.0) {
    return 0.0;
  }
  return math.asin((direction.y / length).clamp(-1.0, 1.0));
}

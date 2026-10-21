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

/// Smooth 0..1 weight for the low-sun golden-hour band.
///
/// In Super Ultra the sun peaks near sin(22°) ≈ 0.375 at noon, and sets
/// across y ≈ 0.0. This rises as the sun drops below y = 0.28, peaks around
/// y = 0.06..0.14, and fades out after sunset (y < -0.04).
double goldenHourFactor(double sunElevationY) {
  final rise = _smoothstep(-0.04, 0.07, sunElevationY);
  final fall = 1.0 - _smoothstep(0.14, 0.29, sunElevationY);
  return (rise * fall).clamp(0.0, 1.0);
}

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

double _mix(double a, double b, double t) => a + (b - a) * t;

vm.Vector3 _mix3(vm.Vector3 a, vm.Vector3 b, double t) => vm.Vector3(
  _mix(a.x, b.x, t),
  _mix(a.y, b.y, t),
  _mix(a.z, b.z, t),
);

/// 3-way colour grading and tonal balance parameters for `PostProcessSettings`.
class SuperUltraColorGrade {
  const SuperUltraColorGrade({
    required this.shadowTint,
    required this.midtoneTint,
    required this.highlightTint,
    required this.contrast,
    required this.saturation,
    required this.colorTemperature,
    required this.colorTint,
    required this.exposureBias,
  });

  final vm.Vector3 shadowTint;
  final vm.Vector3 midtoneTint;
  final vm.Vector3 highlightTint;
  final double contrast;
  final double saturation;
  final double colorTemperature;
  final double colorTint;
  final double exposureBias;
}

/// Computes time-of-day and weather-reactive 3-way colour grading.
///
/// Shifts smoothly between crisp tropical daylight, amber-violet golden hour,
/// indigo-and-ember night, overcast storm desaturation, and lightning flashes.
SuperUltraColorGrade superUltraColorGrade({
  required double golden,
  required double night,
  required double rain,
  required double flash,
}) {
  final g = golden.clamp(0.0, 1.0);
  final n = night.clamp(0.0, 1.0);
  final r = rain.clamp(0.0, 1.0);
  final f = flash.clamp(0.0, 1.0);

  // Daylight baseline: cool ocean-teal shadows, warm sunlight highlights.
  var shadow = vm.Vector3(0.90, 0.96, 1.08);
  var midtone = vm.Vector3(1.01, 1.00, 0.98);
  var highlight = vm.Vector3(1.06, 1.01, 0.92);
  var contrast = 1.07;
  var saturation = 1.12;
  var temperature = 0.06;
  var tint = -0.02;

  // Golden hour: amber-violet shadows and rich copper-gold highlights.
  shadow = _mix3(shadow, vm.Vector3(0.94, 0.84, 1.12), g);
  midtone = _mix3(midtone, vm.Vector3(1.06, 0.97, 0.90), g);
  highlight = _mix3(highlight, vm.Vector3(1.18, 0.98, 0.78), g);
  contrast = _mix(contrast, 1.11, g);
  saturation = _mix(saturation, 1.18, g);
  temperature = _mix(temperature, 0.26, g);
  tint = _mix(tint, 0.05, g);

  // Night: deep indigo shadows, silver-blue midtones, warm fire highlights.
  shadow = _mix3(shadow, vm.Vector3(0.76, 0.88, 1.18), n);
  midtone = _mix3(midtone, vm.Vector3(0.90, 0.96, 1.08), n);
  highlight = _mix3(highlight, vm.Vector3(1.12, 0.96, 0.80), n);
  contrast = _mix(contrast, 1.10, n);
  saturation = _mix(saturation, 0.94, n);
  temperature = _mix(temperature, -0.18, n);
  tint = _mix(tint, -0.03, n);

  // Rain / storm: cooler, desaturated slate tones and softer contrast.
  shadow = _mix3(shadow, vm.Vector3(0.84, 0.90, 1.02), r * 0.65);
  midtone = _mix3(midtone, vm.Vector3(0.94, 0.97, 1.02), r * 0.65);
  highlight = _mix3(highlight, vm.Vector3(0.94, 0.98, 1.06), r * 0.70);
  contrast = _mix(contrast, 1.03, r * 0.75);
  saturation = _mix(saturation, 0.86, r * 0.80);
  temperature -= 0.14 * r;

  // Lightning flash: electric blue-white highlight kick and exposure boost.
  highlight = _mix3(highlight, vm.Vector3(1.15, 1.20, 1.32), f * 0.65);
  final exposureBias = 0.35 * f;

  return SuperUltraColorGrade(
    shadowTint: shadow,
    midtoneTint: midtone,
    highlightTint: highlight,
    contrast: contrast,
    saturation: saturation,
    colorTemperature: temperature,
    colorTint: tint,
    exposureBias: exposureBias,
  );
}

/// Camera-mode-aware Depth of Field focus parameters.
class SuperUltraDofFocus {
  const SuperUltraDofFocus({
    required this.enabled,
    required this.focalDistance,
    required this.focalRange,
    required this.fStop,
    required this.maxBlurRadius,
  });

  final bool enabled;
  final double focalDistance;
  final double focalRange;
  final double fStop;
  final double maxBlurRadius;
}

/// Distance threshold (in metres) above which Orbit mode disables Depth of
/// Field so wide island overviews stay sharp and pay zero DoF GPU cost.
const double kSuperUltraDofOrbitMaxDistance = 25.0;

/// Computes Depth of Field settings for the active camera mode and target
/// distance, following the `flutter_scene-looks` hero-shot rule.
SuperUltraDofFocus superUltraDofFocus({
  required bool overTheShoulder,
  required double cameraToTargetDistance,
}) {
  final dist = cameraToTargetDistance.clamp(1.0, 200.0);
  if (overTheShoulder) {
    return SuperUltraDofFocus(
      enabled: true,
      focalDistance: dist.clamp(2.5, 14.0),
      focalRange: 4.5,
      fStop: 3.2,
      maxBlurRadius: 7.0,
    );
  }
  if (dist < kSuperUltraDofOrbitMaxDistance) {
    final fade = 1.0 - _smoothstep(12.0, kSuperUltraDofOrbitMaxDistance, dist);
    return SuperUltraDofFocus(
      enabled: true,
      focalDistance: dist.clamp(3.0, kSuperUltraDofOrbitMaxDistance),
      focalRange: (dist * 0.48).clamp(4.0, 12.0),
      fStop: 3.5,
      maxBlurRadius: _mix(1.5, 7.0, fade),
    );
  }
  return SuperUltraDofFocus(
    enabled: false,
    focalDistance: dist,
    focalRange: 14.0,
    fStop: 5.6,
    maxBlurRadius: 0.0,
  );
}

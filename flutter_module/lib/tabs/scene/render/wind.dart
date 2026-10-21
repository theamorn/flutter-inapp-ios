/// One wind for the island's grass, flag, trees, and rain.
///
/// It blows the way the Super Ultra grass always bent (and the island rain
/// drifts): toward +X and a little +Z. Fair weather is a breeze; a storm
/// blows harder, and gusts come and go on a slow, smooth clock. Shaders get
/// it as one vec4 ([Wind.shaderParams]) and add their own small-scale motion.
///
/// Pure (no GPU), so it is unit-tested.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// The horizontal direction the wind blows toward (x, z), unit length.
final Vector2 kWindDirection = Vector2(0.16, 0.07)..normalize();

/// The wind at one moment.
class Wind {
  const Wind({required this.speed, required this.gust, required this.time});

  /// Relative strength: about 0.35 in fair weather, 1 in a full storm.
  final double speed;

  /// How hard the current gust is, 0 (lull) to 1.
  final double gust;

  /// Seconds on the wind clock, for the shaders' own waves.
  final double time;

  /// xy = direction (x, z) times [speed], z = [gust], w = [time].
  Vector4 get shaderParams =>
      Vector4(kWindDirection.x * speed, kWindDirection.y * speed, gust, time);
}

double _finite(double v, double fallback) => v.isFinite ? v : fallback;

/// The wind for a [weather] (0 dry .. 1 storm) at [time] seconds.
Wind windFor({required double weather, required double time}) {
  final w = _finite(weather, 0).clamp(0.0, 1.0);
  final t = _finite(time, 0);
  // Two incommensurate slow waves: gusts that never repeat on a beat.
  final swell = 0.6 * math.sin(t * 0.9) + 0.4 * math.sin(t * 2.3 + 1.7);
  final gust = (0.5 + 0.5 * swell).clamp(0.0, 1.0);
  return Wind(speed: 0.35 + 0.65 * w, gust: gust, time: t);
}

/// The Super Ultra grass's `wind` parameter for a [weather], unchanged from
/// before the shared model (xy = tip travel in metres, z = sway speed).
Vector4 grassWindVector(double weather) {
  final w = _finite(weather, 0).clamp(0.0, 1.0);
  final gust = 1.0 + 1.3 * w;
  return Vector4(0.16 * gust, 0.07 * gust, 1.0 + 0.6 * w, 0.0);
}

/// How far rain drops on a window pane drift along its u axis per unit they
/// slide down its v axis (`rain_glass.fmat`'s `wind_skew`): the part of the
/// wind that blows along [uAxis], the world direction in which the pane's u
/// grows, scaled by the wind's strength. A pane with its u the other way
/// gets the opposite skew, so its drops still drift downwind.
double rainGlassSkew(Wind wind, {required Vector3 uAxis}) {
  final u = Vector2(uAxis.x, uAxis.z);
  if (u.length2 < 1e-12) return 0;
  u.normalize();
  return 0.6 * kWindDirection.dot(u) * wind.speed * (0.7 + 0.3 * wind.gust);
}

/// The sideways acceleration (m/s², y always 0) that drifts falling rain
/// downwind: a gentle lean in fair weather, a clear slant in a storm.
Vector3 rainDriftAcceleration(Wind wind) {
  final a = 4.5 * wind.speed * (0.75 + 0.25 * wind.gust);
  return Vector3(kWindDirection.x * a, 0, kWindDirection.y * a);
}

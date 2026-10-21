/// A short screen-space ripple for each lightning strike, bounded in count
/// and life, for flutter_scene 0.24's `Scene.screenDistortion`.
///
/// One pulse per new strike (not per flash of its envelope): each strike
/// carries a [StrikeId], and the pool keeps only the last accepted id as a
/// watermark, so a repeated or older id is ignored without remembering every
/// id ever seen. At most [ShockwavePool.capacity] pulses live at once; the
/// oldest makes room. A strike that projects off screen gets no pulse at all,
/// never one clamped to the screen edge.
///
/// Pure (no GPU): unit-tested. `shockwave_apply.dart` hands the samples to
/// the scene.
library;

import 'dart:math' as math;

/// A lightning scheduler's generation (bumped when the scheduler is replaced,
/// say on a remount) and the strike's number within it.
class StrikeId {
  const StrikeId({required this.generation, required this.number});

  final int generation;
  final int number;

  /// Whether this strike came after [other].
  bool isAfter(StrikeId other) =>
      generation > other.generation ||
      (generation == other.generation && number > other.number);

  @override
  bool operator ==(Object other) =>
      other is StrikeId && other.generation == generation && other.number == number;

  @override
  int get hashCode => Object.hash(generation, number);

  @override
  String toString() => 'StrikeId($generation, $number)';
}

/// Numbers one scheduler's strikes, and starts a new generation when the
/// scheduler is replaced.
class StrikeCounter {
  int _generation = 1;
  int _number = 0;

  /// The id of a new strike.
  StrikeId next() => StrikeId(generation: _generation, number: ++_number);

  /// A new scheduler: later ids start again at 1, in a newer generation.
  void replaceScheduler() {
    _generation++;
    _number = 0;
  }
}

/// A strike as it happens: its id and where it struck, in world space.
class StrikeEvent {
  const StrikeEvent(this.id, this.x, this.y, this.z);

  final StrikeId id;
  final double x, y, z;
}

/// One live ripple, in screen UV (origin top-left).
class ShockwaveSample {
  const ShockwaveSample({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.thickness,
    required this.strength,
    required this.chromaticAberration,
  });

  final double centerX, centerY;
  final double radius, thickness, strength, chromaticAberration;
}

class _Pulse {
  _Pulse(
    this.centerX,
    this.centerY, {
    required this.peakStrength,
    required this.pulseThickness,
    required this.pulseChromaticAberration,
    required this.pulseLifetime,
  });
  final double centerX, centerY;
  final double peakStrength;
  final double pulseThickness;
  final double pulseChromaticAberration;
  final double pulseLifetime;
  double age = 0;
}

class ShockwavePool {
  static const int capacity = 4;
  static const double lifetime = 0.65;
  static const double maxRadius = 0.6;
  static const double thickness = 0.06;
  static const double strength = 0.008;
  static const double chromaticAberration = 0.15;

  final List<_Pulse> _pulses = [];
  StrikeId? _watermark;

  /// Starts a ripple for strike [id] centred at ([centerX], [centerY]) in
  /// screen UV. Returns false, changing nothing, for a repeated or older id
  /// or a centre off screen (or not finite).
  bool trigger(StrikeId id, double centerX, double centerY) {
    final watermark = _watermark;
    if (watermark != null && !id.isAfter(watermark)) return false;
    if (!_onScreen(centerX) || !_onScreen(centerY)) return false;
    _watermark = id;
    _start(centerX, centerY);
    return true;
  }

  /// One centred ripple for a visual check, outside the strike ids.
  void preview({
    double centerX = 0.5,
    double centerY = 0.5,
    double peakStrength = strength,
    double pulseThickness = thickness,
    double pulseChromaticAberration = chromaticAberration,
    double pulseLifetime = lifetime,
  }) =>
      _start(
        centerX,
        centerY,
        peakStrength: peakStrength,
        pulseThickness: pulseThickness,
        pulseChromaticAberration: pulseChromaticAberration,
        pulseLifetime: pulseLifetime,
      );

  void _start(
    double x,
    double y, {
    double peakStrength = strength,
    double pulseThickness = thickness,
    double pulseChromaticAberration = chromaticAberration,
    double pulseLifetime = lifetime,
  }) {
    if (_pulses.length >= capacity) _pulses.removeAt(0);
    _pulses.add(
      _Pulse(
        x,
        y,
        peakStrength: peakStrength,
        pulseThickness: pulseThickness,
        pulseChromaticAberration: pulseChromaticAberration,
        pulseLifetime: pulseLifetime,
      ),
    );
  }

  /// Ages every ripple by [dt] seconds and drops the finished ones. A
  /// negative or non-finite step does nothing.
  void update(double dt) {
    if (!dt.isFinite || dt <= 0) return;
    for (final p in _pulses) {
      p.age += dt;
    }
    _pulses.removeWhere((p) => p.age >= p.pulseLifetime);
  }

  /// Drops every ripple and forgets the watermark (the storm stopped, the
  /// scene was hidden, the mode changed).
  void clear() {
    _pulses.clear();
    _watermark = null;
  }

  bool get isEmpty => _pulses.isEmpty;

  /// The live ripples, oldest first: radius grows linearly to [maxRadius]
  /// and strength falls as (1 - t)^2 over the pulse's lifetime.
  List<ShockwaveSample> get samples => [
        for (final p in _pulses)
          () {
            final t = (p.age / p.pulseLifetime).clamp(0.0, 1.0);
            return ShockwaveSample(
              centerX: p.centerX,
              centerY: p.centerY,
              radius: maxRadius * t,
              thickness: p.pulseThickness,
              strength: p.peakStrength * math.pow(1 - t, 2),
              chromaticAberration: p.pulseChromaticAberration,
            );
          }(),
      ];

  static bool _onScreen(double v) => v.isFinite && v >= 0 && v <= 1;
}

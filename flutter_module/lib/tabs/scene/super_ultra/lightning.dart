/// Thunderstorm lightning for the Super Ultra rain.
///
/// While it rains hard, a strike every few seconds:
///
/// * a jagged, branching bolt ([generateLightningBolt]) drawn as HDR tubes, so
///   bloom turns it into a glow and the sea's planar mirror reflects it;
/// * a cold directional light from the strike (no shadow, so the static
///   shadow cache is untouched);
/// * a flash envelope ([LightningEnvelope]) of two or three quick pulses. The
///   owner also lights the clouds around the bolt and lifts the ambient light
///   with it.
///
/// **Flashing.** Each strike stays within three flashes in any one second
/// and strikes are at least [kMinStrikeInterval] apart, per the usual
/// photosensitivity guidance (no more than three flashes a second). The
/// island's storm toggle turns lightning off while keeping the rain.
///
/// The bolt shape and the envelope are pure, and unit-tested.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Shortest gap between two strikes, in seconds.
const double kMinStrikeInterval = 4.5;

/// A bolt as polylines: the main channel first, then its branches.
typedef LightningBolt = List<List<vm.Vector3>>;

/// Builds a bolt from [top] to [bottom] by midpoint displacement: each pass
/// splits every segment and kicks the midpoint sideways by a fraction of the
/// segment's length, so the channel is jagged at every scale. A few branches
/// fork off the upper part, heading down and outward.
LightningBolt generateLightningBolt(
  math.Random random,
  vm.Vector3 top,
  vm.Vector3 bottom, {
  int detail = 5,
  int maxBranches = 4,
}) {
  final main = _displace(random, top, bottom, detail, 0.26);
  final bolt = <List<vm.Vector3>>[main];
  final branches = 1 + random.nextInt(maxBranches);
  for (var b = 0; b < branches; b++) {
    // Fork from the upper two thirds of the channel.
    final at = 2 + random.nextInt(math.max(1, (main.length * 0.62).floor() - 2));
    final start = main[at];
    final remaining = start.y - bottom.y;
    final length = remaining * (0.25 + 0.3 * random.nextDouble());
    final angle = random.nextDouble() * 2 * math.pi;
    final end = start +
        vm.Vector3(
          math.cos(angle) * length * 0.55,
          -length,
          math.sin(angle) * length * 0.55,
        );
    bolt.add(_displace(random, start, end, detail - 2, 0.3));
  }
  return bolt;
}

List<vm.Vector3> _displace(
  math.Random random,
  vm.Vector3 a,
  vm.Vector3 b,
  int passes,
  double roughness,
) {
  var points = <vm.Vector3>[a.clone(), b.clone()];
  for (var pass = 0; pass < passes; pass++) {
    final next = <vm.Vector3>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final q = points[i + 1];
      final length = (q - p).length;
      final kick = length * roughness;
      final mid = (p + q) * 0.5 +
          vm.Vector3(
            (random.nextDouble() * 2 - 1) * kick,
            (random.nextDouble() * 2 - 1) * kick * 0.25,
            (random.nextDouble() * 2 - 1) * kick,
          );
      next
        ..add(mid)
        ..add(q);
    }
    points = next;
  }
  return points;
}

/// The brightness of one strike over time: a dim leader, the main return
/// stroke, and sometimes a re-strike, each decaying in a few tens of
/// milliseconds.
class LightningEnvelope {
  LightningEnvelope(this.times, this.peaks)
      : assert(times.length == peaks.length && times.isNotEmpty);

  /// A randomised strike: two or three pulses within half a second.
  factory LightningEnvelope.random(math.Random random) {
    final main = 0.06 + 0.04 * random.nextDouble();
    final times = <double>[0.0, main];
    final peaks = <double>[0.3, 1.0];
    if (random.nextDouble() < 0.7) {
      times.add(main + 0.14 + 0.1 * random.nextDouble());
      peaks.add(0.5 + 0.3 * random.nextDouble());
    }
    return LightningEnvelope(times, peaks);
  }

  final List<double> times;
  final List<double> peaks;

  static const double _rise = 0.012;
  static const double _decay = 0.055;

  /// Seconds after which the strike is dark again.
  double get duration => times.last + 0.4;

  /// When the main (brightest) pulse peaks.
  double get mainPeakTime {
    var best = 0;
    for (var i = 1; i < peaks.length; i++) {
      if (peaks[i] > peaks[best]) {
        best = i;
      }
    }
    return times[best] + _rise;
  }

  double valueAt(double t) {
    var value = 0.0;
    for (var i = 0; i < times.length; i++) {
      final dt = t - times[i];
      if (dt < 0.0) {
        continue;
      }
      final pulse = dt < _rise ? dt / _rise : math.exp(-(dt - _rise) / _decay);
      value = math.max(value, peaks[i] * pulse);
    }
    return value;
  }
}

/// Where the camera is and which way it looks, for placing strikes in view.
typedef CameraPose = ({vm.Vector3 eye, vm.Vector3 forward});

class SuperUltraLightning {
  SuperUltraLightning({
    required this.cameraPose,
    required this.rainLevel,
    required this.seaLevel,
    this.debugHoldSeconds = 0.0,
  }) {
    lightNode = Node(name: 'su_lightning_light')
      ..addComponent(DirectionalLightComponent(light));
    root
      ..add(lightNode)
      ..addComponent(_LightningTick(this));
  }

  final CameraPose Function() cameraPose;
  final double Function() rainLevel;
  final double seaLevel;

  /// Debug only: hold each strike at its main peak this long, so a screenshot
  /// can catch it. Zero in every shipped build.
  final double debugHoldSeconds;

  final Node root = Node(name: 'su_lightning');
  final DirectionalLight light = DirectionalLight(
    color: vm.Vector3(0.72, 0.8, 1.0),
    intensity: 0.0,
  );
  late final Node lightNode;
  final UnlitMaterial _boltMaterial = UnlitMaterial();
  Node? _boltNode;

  /// Whether new strikes happen. A strike already under way finishes.
  bool enabled = true;

  /// Current flash brightness, 0 (dark) to about 1.
  double flash = 0.0;

  /// How much a flash lights the scene, 0..1: full at night, weak by day,
  /// when real lightning barely registers against the daylight. The bolt
  /// itself stays bright either way.
  double strength = 1.0;

  /// Unit direction from the island toward the current strike, for lighting
  /// the clouds around it.
  vm.Vector3 strikeDirection = vm.Vector3(0, 0.6, -0.8);

  /// Strikes so far, for the readout.
  int strikes = 0;

  final math.Random _random = math.Random(41);
  double _untilNext = 3.0;
  double _age = -1.0;
  LightningEnvelope? _envelope;

  void _tick(double dt) {
    final envelope = _envelope;
    if (envelope != null) {
      _age += dt;
      var t = _age;
      if (debugHoldSeconds > 0.0) {
        final peak = envelope.mainPeakTime;
        if (t > peak) {
          t = t < peak + debugHoldSeconds ? peak : t - debugHoldSeconds;
        }
      }
      flash = envelope.valueAt(t);
      if (t >= envelope.duration) {
        _endStrike();
      }
    } else {
      flash = 0.0;
    }
    light.intensity = 7.0 * flash * strength;
    _boltMaterial.baseColorFactor =
        vm.Vector4(9.0 * flash, 10.0 * flash, 14.0 * flash, 1.0);
    // Between pulses the channel is dark; an opaque unlit tube would draw as
    // a black line, so hide it rather than dim it to black.
    _boltNode?.visible = flash > 0.04;

    // Strikes only in a proper downpour, not while the rain is fading in.
    if (enabled && rainLevel() > 0.7 && _envelope == null) {
      _untilNext -= dt;
      if (_untilNext <= 0.0) {
        _strike();
        _untilNext = kMinStrikeInterval + _random.nextDouble() * 8.0;
      }
    }
  }

  void _strike() {
    final pose = cameraPose();
    final eye = pose.eye;
    final heading = math.atan2(pose.forward.x, pose.forward.z);
    double x;
    double z;
    if (_random.nextDouble() < 0.75) {
      // In view: a portrait frame is only about ±14° wide.
      final angle = heading + (_random.nextDouble() * 2 - 1) * 0.2;
      final distance = 45.0 + _random.nextDouble() * 40.0;
      x = eye.x + math.sin(angle) * distance;
      z = eye.z + math.cos(angle) * distance;
    } else {
      // Off screen: only the flash shows.
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = 40.0 + _random.nextDouble() * 80.0;
      x = math.sin(angle) * distance;
      z = math.cos(angle) * distance;
    }
    // Never on the island itself.
    final r = math.sqrt(x * x + z * z);
    if (r < 22.0) {
      final push = 22.0 / math.max(r, 0.001);
      x *= push;
      z *= push;
    }
    final top = vm.Vector3(x, 40.0 + _random.nextDouble() * 12.0, z);
    final bottom = vm.Vector3(
      x + (_random.nextDouble() * 2 - 1) * 6.0,
      seaLevel,
      z + (_random.nextDouble() * 2 - 1) * 6.0,
    );
    final bolt = generateLightningBolt(_random, top, bottom);

    _boltNode?.detach();
    final primitives = <MeshPrimitive>[
      for (var i = 0; i < bolt.length; i++)
        MeshPrimitive(
          TubeGeometry(
            PolylinePath(bolt[i]),
            radius: i == 0 ? 0.22 : 0.1,
            radialSegments: 5,
            stations: bolt[i].length,
            caps: false,
          ),
          _boltMaterial,
        ),
    ];
    _boltNode = Node(
      name: 'su_lightning_bolt',
      mesh: Mesh.primitives(primitives: primitives),
    )..castsShadows = false;
    root.add(_boltNode!);

    lightNode.lookAtFrom(top, vm.Vector3.zero());
    strikeDirection = top.normalized();
    _envelope = LightningEnvelope.random(_random);
    _age = 0.0;
    strikes++;
    if (kDebugMode) {
      debugPrint('island lightning: strike ${top.x.toStringAsFixed(0)}, '
          '${top.z.toStringAsFixed(0)}');
    }
  }

  void _endStrike() {
    _envelope = null;
    flash = 0.0;
    _boltNode?.detach();
    _boltNode = null;
  }

  /// Ends any strike at once, for when the rain stops or the mode is left.
  void reset() {
    _endStrike();
    light.intensity = 0.0;
    _untilNext = 3.0;
  }
}

class _LightningTick extends Component {
  _LightningTick(this.lightning);

  final SuperUltraLightning lightning;

  @override
  void update(double deltaSeconds) => lightning._tick(deltaSeconds);
}

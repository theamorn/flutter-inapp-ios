import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_module/tabs/scene/render/material_binding_policy.dart';
import 'package:flutter_module/tabs/scene/render/shockwave_apply.dart';
import 'package:flutter_module/tabs/scene/render/shockwave_pool.dart';
import 'package:flutter_module/tabs/scene/render/wind.dart';
import 'package:flutter_module/tabs/scene/scene_frame_meter.dart';
import 'package:flutter_scene/scene.dart'
    show PerspectiveCamera, RenderFrameStats, RenderViewStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

class _Target {
  _Target(this.name);
  final String name;
  @override
  String toString() => name;
}

StrikeId _id(int generation, int number) =>
    StrikeId(generation: generation, number: number);

int _feed(
  SceneFrameMeter m, {
  required int startMicros,
  required double seconds,
  required double hz,
  required double sceneHz,
  required List<int> counters,
}) {
  final n = (seconds * hz).round();
  var t = startMicros;
  for (var i = 1; i <= n; i++) {
    t = startMicros + (i * 1e6 / hz).round();
    final scene = (counters[0] + i * sceneHz / hz).floor();
    final paced = (counters[1] + i * (hz - sceneHz) / hz).floor();
    m.add(t, sceneFrames: scene, pacedFrames: paced);
  }
  counters[0] += (seconds * sceneHz).round();
  counters[1] += (seconds * (hz - sceneHz)).round();
  return t;
}

void main() {
  group('MaterialBindingPolicy', () {
    test('binds each wanted target once and restores originals on releaseAll', () {
      final a = _Target('a'), b = _Target('b');
      final policy = MaterialBindingPolicy<_Target, String>();
      final first = policy.reconcile([a, b]);
      expect(first.bind, [a, b]);
      expect(first.release, isEmpty);
      policy
        ..bind(a, 'mesh a')
        ..bind(b, 'mesh b');
      final again = policy.reconcile([a, b]);
      expect(again.bind, isEmpty);
      expect(again.release, isEmpty);
      expect(policy.releaseAll(), [(a, 'mesh a'), (b, 'mesh b')]);
      expect(policy.releaseAll(), isEmpty);
    });

    test('binding a bound target again keeps the true original', () {
      final a = _Target('a');
      final policy = MaterialBindingPolicy<_Target, String>()
        ..bind(a, 'authored mesh')
        ..bind(a, 'already swapped mesh');
      expect(policy.releaseAll(), [(a, 'authored mesh')]);
    });
  });

  group('ShockwavePool & strikeScreenUv', () {
    test('one strike makes one pulse; the same id again makes none', () {
      final pool = ShockwavePool();
      expect(pool.trigger(_id(1, 1), 0.5, 0.5), isTrue);
      expect(pool.trigger(_id(1, 1), 0.5, 0.5), isFalse);
      expect(pool.samples, hasLength(1));
    });

    test('a pulse grows and fades on the spec envelope, then expires', () {
      final pool = ShockwavePool()..trigger(_id(1, 1), 0.3, 0.4);
      var s = pool.samples.single;
      expect(s.centerX, 0.3);
      expect(s.centerY, 0.4);
      expect(s.radius, 0);
      expect(s.strength, closeTo(0.008, 1e-12));
      pool.update(0.325);
      s = pool.samples.single;
      expect(s.radius, closeTo(0.3, 1e-9));
      expect(s.strength, closeTo(0.008 * 0.25, 1e-12));
      pool.update(0.33);
      expect(pool.samples, isEmpty);
    });

    test('a strike straight ahead lands in the middle of the screen; behind or off-side is null', () {
      final camera = PerspectiveCamera(
        position: Vector3(0, 2, 10),
        target: Vector3(0, 2, 0),
      );
      const viewport = Size(400, 800);
      final uv = strikeScreenUv(camera, Vector3(0, 2, -50), viewport)!;
      expect(uv.$1, closeTo(0.5, 1e-6));
      expect(uv.$2, closeTo(0.5, 1e-6));
      expect(strikeScreenUv(camera, Vector3(0, 2, 40), viewport), isNull);
      expect(strikeScreenUv(camera, Vector3(500, 2, 0), viewport), isNull);
      expect(strikeScreenUv(camera, Vector3(0, 2, -50), Size.zero), isNull);
    });
  });

  group('Wind', () {
    test('blows the way the island grass bends and scales with weather', () {
      expect(kWindDirection.length, closeTo(1, 1e-6));
      final grass = math.atan2(0.07, 0.16);
      expect(math.atan2(kWindDirection.y, kWindDirection.x), closeTo(grass, 0.02));
      final calm = windFor(weather: 0, time: 1.3);
      final storm = windFor(weather: 1, time: 1.3);
      expect(storm.speed, greaterThan(calm.speed));
      expect(rainDriftAcceleration(storm).length,
          greaterThan(rainDriftAcceleration(calm).length));
    });
  });

  group('SceneFrameMeter & onScreenDraws', () {
    test('tracks rendered scene FPS separately from paced frames', () {
      final m = SceneFrameMeter();
      _feed(m, startMicros: 0, seconds: 3, hz: 120, sceneHz: 40, counters: [0, 0]);
      expect(m.sceneFps, closeTo(40, 1.5));
      expect(m.pacedPerSecond, closeTo(80, 1.5));
    });

    test('onScreenDraws extracts draws, instances, culled, and offscreen views', () {
      final frame = RenderFrameStats(frameIndex: 1, timestampMicros: 1000);
      final planarCapture = RenderViewStats(
        viewIndex: -1,
        width: 512,
        height: 512,
        offscreen: true,
      )
        ..counters.draws = 25
        ..counters.culled = 10;
      final mainView = RenderViewStats(
        viewIndex: 0,
        width: 1080,
        height: 2400,
        offscreen: false,
      )
        ..counters.draws = 40
        ..counters.instances = 120
        ..counters.culled = 7;
      frame.views.addAll([planarCapture, mainView]);

      final stats = onScreenDraws(frame);
      expect(stats, isNotNull);
      expect(stats!.draws, 40);
      expect(stats.instances, 120);
      expect(stats.culled, 7);
      expect(stats.offscreenViews, 1);
    });
  });
}

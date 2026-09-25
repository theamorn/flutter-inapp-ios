import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/super_ultra/lightning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('generateLightningBolt', () {
    test('runs from the cloud to the sea, jagged but not wild', () {
      for (var seed = 0; seed < 20; seed++) {
        final top = vm.Vector3(50, 45, 10);
        final bottom = vm.Vector3(52, -1.35, 12);
        final bolt = generateLightningBolt(math.Random(seed), top, bottom);
        final main = bolt.first;
        expect(main.first, top);
        expect(main.last, bottom);
        expect(main.length, 33); // 2^5 segments
        for (final p in main) {
          // Midpoint kicks shrink each pass, so the channel stays within
          // about a third of the bolt's length of the straight line.
          final t = (top.y - p.y) / (top.y - bottom.y);
          final straight = top + (bottom - top) * t.clamp(0.0, 1.0);
          final off = vm.Vector2(p.x - straight.x, p.z - straight.z).length;
          expect(off, lessThan(0.4 * (top - bottom).length));
        }
      }
    });

    test('branches fork from the channel and head down', () {
      final bolt = generateLightningBolt(
        math.Random(7),
        vm.Vector3(0, 40, 60),
        vm.Vector3(0, -1.35, 60),
      );
      expect(bolt.length, greaterThan(1));
      for (final branch in bolt.skip(1)) {
        expect(bolt.first.any((p) => p == branch.first), isTrue);
        expect(branch.last.y, lessThan(branch.first.y));
      }
    });
  });

  group('LightningEnvelope', () {
    test('peaks near 1 on the main stroke and goes dark', () {
      for (var seed = 0; seed < 30; seed++) {
        final envelope = LightningEnvelope.random(math.Random(seed));
        var peak = 0.0;
        for (var t = 0.0; t < envelope.duration; t += 0.002) {
          peak = math.max(peak, envelope.valueAt(t));
        }
        expect(peak, closeTo(1.0, 0.05));
        expect(envelope.valueAt(envelope.duration), lessThan(0.02));
        expect(
          envelope.valueAt(envelope.mainPeakTime),
          closeTo(1.0, 0.05),
        );
      }
    });

    test('never more than three flashes in a second', () {
      for (var seed = 0; seed < 50; seed++) {
        final envelope = LightningEnvelope.random(math.Random(seed));
        expect(envelope.times.length, lessThanOrEqualTo(3));
        expect(envelope.duration, lessThan(1.0));
      }
      // And strikes are further apart than one second.
      expect(kMinStrikeInterval, greaterThan(1.0));
    });
  });
}

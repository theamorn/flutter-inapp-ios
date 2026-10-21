import 'dart:math' as math;

import 'package:flutter_module/tabs/scene/super_ultra/grass_draw_policy.dart';
import 'package:flutter_scene/scene.dart' show MeshDrawContext, MeshDrawPass;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// A jittered lawn like the rig's: [n] points over a disc of [radius].
List<(double, double)> _lawn(int n, {double radius = 14, int seed = 3}) {
  final random = math.Random(seed);
  final out = <(double, double)>[];
  while (out.length < n) {
    final x = (random.nextDouble() * 2 - 1) * radius;
    final z = (random.nextDouble() * 2 - 1) * radius;
    if (x * x + z * z <= radius * radius) out.add((x, z));
  }
  return out;
}

MeshDrawContext _context(MeshDrawPass pass) =>
    MeshDrawContext(pass: pass, cameraPosition: Vector3(0, 2, 5), primaryView: true);

void main() {
  group('grassDrawCount', () {
    test('high draws all, medium three quarters, low half, rounded up', () {
      expect(grassDrawCount(total: 13, level: QualityLevel.high), 13);
      expect(grassDrawCount(total: 13, level: QualityLevel.medium), 10);
      expect(grassDrawCount(total: 13, level: QualityLevel.low), 7);
      expect(grassDrawCount(total: 2048, level: QualityLevel.medium), 1536);
      expect(grassDrawCount(total: 2048, level: QualityLevel.low), 1024);
    });

    test('never exceeds the instances, never goes negative, keeps the order', () {
      for (final total in [0, 1, 13, 2048]) {
        final low = grassDrawCount(total: total, level: QualityLevel.low);
        final medium = grassDrawCount(total: total, level: QualityLevel.medium);
        final high = grassDrawCount(total: total, level: QualityLevel.high);
        expect(low, inInclusiveRange(0, total), reason: '$total');
        expect(low, lessThanOrEqualTo(medium));
        expect(medium, lessThanOrEqualTo(high));
        expect(high, total);
      }
      expect(grassDrawCount(total: 1, level: QualityLevel.low), 1);
    });
  });

  group('distributedOrder', () {
    test('is a permutation: every original index exactly once', () {
      for (final n in [0, 1, 13, 2048]) {
        final order = distributedOrder(_lawn(n), seed: 7);
        expect(order, hasLength(n));
        expect(order.toSet(), hasLength(n));
        expect(order.every((i) => i >= 0 && i < n), isTrue);
      }
    });

    test('is deterministic for a seed', () {
      final points = _lawn(500);
      expect(distributedOrder(points, seed: 7), distributedOrder(points, seed: 7));
    });

    test('an early prefix already covers the whole planted region', () {
      final points = _lawn(2758);
      final order = distributedOrder(points, seed: 7);
      final prefix = [for (final i in order.take(276)) points[i]];
      // Quadrants hold a quarter each, give or take.
      final counts = List<int>.filled(4, 0);
      for (final (x, z) in prefix) {
        counts[(x >= 0 ? 1 : 0) + (z >= 0 ? 2 : 0)]++;
      }
      for (final c in counts) {
        expect(c, inInclusiveRange(55, 83), reason: '$counts');
      }
      // And it reaches the rim, not just the middle.
      final reach = prefix.map((p) => math.sqrt(p.$1 * p.$1 + p.$2 * p.$2)).reduce(math.max);
      expect(reach, greaterThan(12));
    });

    test('no planted 3 m cell is left out of the half-density prefix', () {
      final points = _lawn(2758);
      final order = distributedOrder(points, seed: 7);
      int cell((double, double) p) => ((p.$1 + 15) ~/ 3) * 100 + ((p.$2 + 15) ~/ 3);
      final perCell = <int, int>{};
      for (final p in points) {
        perCell.update(cell(p), (n) => n + 1, ifAbsent: () => 1);
      }
      // Rim slivers with a tuft or two may go either way; any real patch of
      // lawn keeps some grass.
      final planted = {for (final e in perCell.entries) if (e.value >= 4) e.key};
      final half = {for (final i in order.take(1379)) cell(points[i])};
      expect(planted.difference(half), isEmpty);
    });
  });

  group('grassSelector', () {
    test('colour and depth draw the same prefix at every level', () {
      for (final level in QualityLevel.values) {
        final selector = grassSelector(total: 2758, level: () => level);
        final colour = selector(_context(MeshDrawPass.color));
        final depth = selector(_context(MeshDrawPass.depth));
        expect(colour.instanceCount, depth.instanceCount, reason: '$level');
        expect(colour.instanceCount, grassDrawCount(total: 2758, level: level));
        expect(colour.firstIndex, 0);
        expect(colour.indexCount, isNull);
      }
    });

    test('reads the level per draw and keeps nothing of the context', () {
      var level = QualityLevel.high;
      final selector = grassSelector(total: 100, level: () => level);
      final context = _context(MeshDrawPass.color);
      expect(selector(context).instanceCount, 100);
      // The renderer reuses and mutates one context across draws.
      context
        ..pass = MeshDrawPass.depth
        ..cameraPosition = Vector3(50, 50, 50);
      level = QualityLevel.low;
      expect(selector(context).instanceCount, 50);
    });

    test('full density is the comparison: every instance on every pass', () {
      final selector = grassSelector(total: 2758, level: () => QualityLevel.low, full: () => true);
      for (final pass in MeshDrawPass.values) {
        expect(selector(_context(pass)).instanceCount, 2758);
      }
    });
  });
}

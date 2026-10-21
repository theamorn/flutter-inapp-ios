/// How much of the Super Ultra lawn draws at each render quality tier, and
/// the instance order that keeps any prefix of it spread over the whole lawn.
///
/// The engine draws a prefix of an [InstancedMesh]'s instances
/// (`MeshDrawSelection.instanceCount`), so thinning the lawn means ordering
/// the tufts once so that every prefix is a fair sample of the lawn, then
/// choosing the prefix length per draw. Colour and depth passes pick the same
/// length. Nothing here is sorted per frame.
///
/// Pure apart from the engine's selector types: no GPU, unit-tested.
library;

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show MeshDrawContext, MeshDrawSelection, MeshDrawSelector;

/// The project's render quality levels. The rig maps the engine's effective
/// tier onto these; the policy never sees an engine tier.
enum QualityLevel { low, medium, high }

/// How many of [total] tufts draw at [level]: all on high, three quarters on
/// medium, half on low, rounded up and never more than [total].
int grassDrawCount({required int total, required QualityLevel level}) {
  if (total <= 0) return 0;
  final fraction = switch (level) {
    QualityLevel.high => 1.0,
    QualityLevel.medium => 0.75,
    QualityLevel.low => 0.5,
  };
  return math.min(total, (total * fraction).ceil());
}

/// An order of [points] (instance positions in the ground plane) whose every
/// prefix spreads over the whole set: the points are sorted along a Z-order
/// curve (a seeded offset breaks the grid's alignment), then visited in
/// bit-reversed rank order, so a prefix of any length takes evenly spaced
/// points along the curve. Returns each output slot's original index.
List<int> distributedOrder(List<(double, double)> points, {required int seed}) {
  final n = points.length;
  if (n == 0) return const [];
  var minX = double.infinity, minZ = double.infinity;
  var maxX = -double.infinity, maxZ = -double.infinity;
  for (final (x, z) in points) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minZ = math.min(minZ, z);
    maxZ = math.max(maxZ, z);
  }
  final random = math.Random(seed);
  final span = math.max(math.max(maxX - minX, maxZ - minZ), 1e-9);
  // A cell grid fine enough that each holds a tuft or two, shifted by a
  // seeded fraction of a cell.
  const bits = 10;
  const cells = 1 << bits;
  final shiftX = random.nextDouble(), shiftZ = random.nextDouble();
  int morton(double x, double z) {
    final cx = (((x - minX) / span) * (cells - 1) + shiftX).floor().clamp(0, cells - 1);
    final cz = (((z - minZ) / span) * (cells - 1) + shiftZ).floor().clamp(0, cells - 1);
    var code = 0;
    for (var b = 0; b < bits; b++) {
      code |= ((cx >> b) & 1) << (2 * b);
      code |= ((cz >> b) & 1) << (2 * b + 1);
    }
    return code;
  }

  final ties = List<int>.generate(n, (_) => random.nextInt(1 << 30));
  final codes = [for (final (x, z) in points) morton(x, z)];
  final byCurve = List<int>.generate(n, (i) => i)
    ..sort((a, b) {
      final c = codes[a].compareTo(codes[b]);
      return c != 0 ? c : ties[a].compareTo(ties[b]);
    });

  var width = 0;
  while ((1 << width) < n) {
    width++;
  }
  int reverse(int v) {
    var r = 0;
    for (var b = 0; b < width; b++) {
      r = (r << 1) | ((v >> b) & 1);
    }
    return r;
  }

  return [
    for (var k = 0; k < (1 << width); k++)
      if (reverse(k) < n) byCurve[reverse(k)],
  ];
}

/// The lawn's draw selector: the same prefix of [total] for colour, depth
/// and shadow passes, sized by the current [level] (read per draw), or every
/// tuft while [full] says so (the comparison). Keeps nothing of the context,
/// which the renderer reuses across draws.
MeshDrawSelector grassSelector({
  required int total,
  required QualityLevel Function() level,
  bool Function()? full,
}) =>
    (MeshDrawContext _) => MeshDrawSelection(
          instanceCount: (full?.call() ?? false)
              ? total
              : grassDrawCount(total: total, level: level()),
        );

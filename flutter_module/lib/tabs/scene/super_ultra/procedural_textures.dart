/// Pixel generators for the Super Ultra island: flame and smoke flipbooks, a
/// soft spark dot, and tileable ground detail maps.
///
/// Pure CPU and free of GPU imports, so the whole set runs on a background
/// isolate ([generateSuperUltraTextures] is a valid `compute` callback) and is
/// covered by `flutter test`. Every buffer is tightly packed RGBA8.
///
/// Baked textures rather than per-pixel shader noise, on purpose: a baked map
/// gets a mip chain, so fine detail filters away at distance instead of
/// sparkling, and sampling it is far cheaper than an fbm per fragment.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// One RGBA8 image.
class PixelImage {
  const PixelImage(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

/// Everything Super Ultra bakes, produced in one isolate hop.
class SuperUltraTextureSet {
  const SuperUltraTextureSet({
    required this.flameAtlas,
    required this.smokeAtlas,
    required this.softDot,
    required this.groundDetail,
    required this.sandRipples,
    required this.groundMasks,
  });

  /// 4×4 flipbook of one flame tongue across its life. Greyscale in rgb,
  /// shape in alpha; the particle colour supplies the hue.
  final PixelImage flameAtlas;

  /// 2×2 atlas of four different smoke puffs.
  final PixelImage smokeAtlas;

  /// A small radial falloff for sparks, embers and glow sprites. Without a
  /// texture a sprite is a hard-edged square.
  final PixelImage softDot;

  /// Tileable tangent-space normal (rgb) plus cavity (a) for grass and dirt
  /// clumps.
  final PixelImage groundDetail;

  /// Tileable tangent-space normal (rgb) plus height (a) for wind-blown sand
  /// ripples.
  final PixelImage sandRipples;

  /// Tileable linear masks: r = rock cracks, g = speckle, b = caustics,
  /// a = pebbles.
  final PixelImage groundMasks;
}

/// Flipbook grid of [SuperUltraTextureSet.flameAtlas].
const int kFlameAtlasColumns = 4;
const int kFlameAtlasRows = 4;

/// Flipbook grid of [SuperUltraTextureSet.smokeAtlas].
const int kSmokeAtlasColumns = 2;
const int kSmokeAtlasRows = 2;

/// Bakes the full set. Top-level with one argument so it can be handed to
/// `compute`.
SuperUltraTextureSet generateSuperUltraTextures(int seed) {
  return SuperUltraTextureSet(
    flameAtlas: generateFlameAtlas(seed: seed),
    smokeAtlas: generateSmokeAtlas(seed: seed + 1),
    softDot: generateSoftDot(),
    groundDetail: generateGroundDetail(seed: seed + 2),
    sandRipples: generateSandRipples(seed: seed + 3),
    groundMasks: generateGroundMasks(seed: seed + 4),
  );
}

// ---------------------------------------------------------------- sprites

/// One flame tongue's life as a [kFlameAtlasColumns]×[kFlameAtlasRows]
/// flipbook, read left-to-right, top-to-bottom. Frame 0 is a small bud at
/// the base; mid-life it is a tall licking tongue; late frames lift off the
/// base and erode into wisps. The same noise field scrolls upward through
/// every frame, so consecutive frames are coherent and `flipbookBlend`
/// crossfades them smoothly.
PixelImage generateFlameAtlas({int cell = 128, int seed = 7}) {
  const columns = kFlameAtlasColumns;
  const rows = kFlameAtlasRows;
  const frames = columns * rows;
  final width = cell * columns;
  final height = cell * rows;
  final pixels = Uint8List(width * height * 4);
  final noise = TileableNoise(seed);

  for (var frame = 0; frame < frames; frame++) {
    final phase = frame / (frames - 1);
    final ox = (frame % columns) * cell;
    final oy = (frame ~/ columns) * cell;
    // Tongue length rises, holds, and falls; late in life the base lifts so
    // the tongue detaches the way real flame licks do.
    final length =
        0.28 + 0.62 * math.pow(math.sin(math.pi * math.min(1.0, phase * 1.15)), 0.7);
    final base = 0.1 + 0.34 * _smoothstep(0.55, 1.0, phase);
    for (var py = 0; py < cell; py++) {
      final v = (py + 0.5) / cell;
      final y = 1.0 - v;
      for (var px = 0; px < cell; px++) {
        final u = (px + 0.5) / cell;
        final x = u - 0.5;
        final s = (y - base) / length;
        final sway = 0.075 * s * math.sin(s * 3.6 + phase * 5.0);
        final halfWidth = _flameHalfWidth(s);
        var density = 0.0;
        var core = 0.0;
        if (halfWidth > 0.0) {
          final distance = (x - sway).abs() / halfWidth;
          density = 1.0 - _smoothstep(0.45, 1.0, distance);
          core = 1.0 - _smoothstep(0.0, 0.6, distance);
        }
        if (density > 0.0) {
          final n = 0.5 +
              0.5 *
                  noise.fbm(u * 2.0, v * 1.4 + phase * 1.6,
                      period: 4, octaves: 4);
          final erodeLow = 0.2 + 0.55 * phase;
          density *=
              _smoothstep(erodeLow, erodeLow + 0.3, n + 0.5 * (1.0 - s));
          density *= 1.0 - _smoothstep(0.8, 1.05, s);
        }
        // Keep every cell's border empty so mips never bleed a neighbour's
        // frame in.
        density *= _smoothstep(0.0, 0.05, u) *
            _smoothstep(1.0, 0.95, u) *
            _smoothstep(0.0, 0.04, v) *
            _smoothstep(1.0, 0.96, v);
        final brightness =
            (0.55 * density + 0.65 * core * density * (1.0 - s * 0.6))
                .clamp(0.0, 1.0);
        final index = ((oy + py) * width + ox + px) * 4;
        final grey = (brightness * 255.0).round();
        pixels[index] = grey;
        pixels[index + 1] = grey;
        pixels[index + 2] = grey;
        pixels[index + 3] = (density.clamp(0.0, 1.0) * 255.0).round();
      }
    }
  }
  return PixelImage(pixels, width, height);
}

double _flameHalfWidth(double s) {
  const maxHalfWidth = 0.21;
  if (s < -0.16 || s > 1.0) {
    return 0.0;
  }
  if (s < 0.0) {
    // Rounded bottom of the teardrop.
    final t = s / 0.16;
    return maxHalfWidth * math.sqrt(math.max(0.0, 1.0 - t * t));
  }
  return maxHalfWidth * math.pow(1.0 - s, 0.62);
}

/// Four soft, lumpy smoke puffs in a [kSmokeAtlasColumns]×[kSmokeAtlasRows]
/// grid. Light grey in rgb so the particle colour decides how dark the smoke
/// reads.
PixelImage generateSmokeAtlas({int cell = 128, int seed = 13}) {
  const columns = kSmokeAtlasColumns;
  const rows = kSmokeAtlasRows;
  final width = cell * columns;
  final height = cell * rows;
  final pixels = Uint8List(width * height * 4);
  for (var puff = 0; puff < columns * rows; puff++) {
    final noise = TileableNoise(seed + puff * 101);
    final ox = (puff % columns) * cell;
    final oy = (puff ~/ columns) * cell;
    for (var py = 0; py < cell; py++) {
      final v = (py + 0.5) / cell;
      for (var px = 0; px < cell; px++) {
        final u = (px + 0.5) / cell;
        final dx = u - 0.5;
        final dy = v - 0.5;
        final n = noise.fbm(u, v, period: 4, octaves: 4);
        final radius = math.sqrt(dx * dx + dy * dy) * (1.0 + 0.35 * n);
        final shape = 1.0 - _smoothstep(0.12, 0.47, radius);
        final density = (shape * (0.62 + 0.38 * (0.5 + 0.5 * n)))
            .clamp(0.0, 1.0);
        final index = ((oy + py) * width + ox + px) * 4;
        final grey = (200 + 40 * (0.5 + 0.5 * n)).round().clamp(0, 255);
        pixels[index] = grey;
        pixels[index + 1] = grey;
        pixels[index + 2] = grey;
        pixels[index + 3] = (density * 255.0).round();
      }
    }
  }
  return PixelImage(pixels, width, height);
}

/// A white disc with a gaussian falloff to transparent.
PixelImage generateSoftDot({int size = 32}) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = (x + 0.5) / size - 0.5;
      final dy = (y + 0.5) / size - 0.5;
      final r2 = (dx * dx + dy * dy) * 4.0;
      final alpha = r2 >= 1.0 ? 0.0 : math.exp(-r2 * 4.5) * (1.0 - r2);
      final index = (y * size + x) * 4;
      pixels[index] = 255;
      pixels[index + 1] = 255;
      pixels[index + 2] = 255;
      pixels[index + 3] = (alpha * 255.0).round();
    }
  }
  return PixelImage(pixels, size, size);
}

// ---------------------------------------------------------------- ground

/// Grass-and-dirt micro relief: rounded clumps (Worley F1) over fine fbm.
/// Tileable. rgb = tangent-space normal, a = cavity (0 in the gaps).
PixelImage generateGroundDetail({int size = 256, int seed = 21}) {
  final noise = TileableNoise(seed);
  final heights = Float64List(size * size);
  for (var y = 0; y < size; y++) {
    final v = y / size;
    for (var x = 0; x < size; x++) {
      final u = x / size;
      final clumps = noise.worley(u, v, cells: 18);
      final clump = 1.0 - (clumps.f1 * 1.35).clamp(0.0, 1.0);
      final grain = 0.5 + 0.5 * noise.fbm(u, v, period: 16, octaves: 3);
      heights[y * size + x] = 0.62 * clump * clump + 0.38 * grain;
    }
  }
  return _normalMapFromHeights(heights, size, strength: 3.2);
}

/// Wind-blown sand ripples: asymmetric crests running across the tile with a
/// warped phase so they do not read as a ruler. Tileable (an integer number of
/// crests per tile). rgb = tangent-space normal, a = height.
PixelImage generateSandRipples({int size = 256, int seed = 23}) {
  final noise = TileableNoise(seed);
  const crests = 9;
  final heights = Float64List(size * size);
  for (var y = 0; y < size; y++) {
    final v = y / size;
    for (var x = 0; x < size; x++) {
      final u = x / size;
      final warp = 0.55 * noise.fbm(u, v, period: 3, octaves: 3);
      final phase = 2 * math.pi * (u * crests + warp);
      // A skewed sine: gentle stoss slope, steep lee face.
      final ripple = 0.5 + 0.5 * math.sin(phase + 0.45 * math.sin(phase));
      final breakup = 0.72 + 0.28 * noise.fbm(u, v, period: 8, octaves: 2);
      heights[y * size + x] = ripple * breakup;
    }
  }
  return _normalMapFromHeights(heights, size, strength: 2.2);
}

/// Linear masks sampled by `island_ground.fmat`. Tileable.
///
/// * r: rock cracks — Worley cell borders with free ends, masked by a
///   low-frequency region field and a high-frequency breaker (procedural
///   skill, "free-end Worley rock cracks"), so they are not bathroom tile.
/// * g: speckle — fine albedo variation.
/// * b: caustics — domain-warped Worley edges, the bright web under water.
/// * a: pebbles — Worley blobs whose radius varies with an fbm field, so they
///   cluster instead of sitting one per cell.
PixelImage generateGroundMasks({int size = 256, int seed = 37}) {
  final noise = TileableNoise(seed);
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final v = y / size;
    for (var x = 0; x < size; x++) {
      final u = x / size;

      final cells = noise.worley(u, v, cells: 7);
      final net = _smoothstep(0.1, 0.0, cells.f2 - cells.f1);
      final region =
          _smoothstep(-0.15, 0.35, noise.fbm(u, v, period: 3, octaves: 3));
      final breaker =
          _smoothstep(-0.35, 0.2, noise.fbm(u, v, period: 16, octaves: 2));
      final crack = net * region * breaker;

      final speckle =
          0.5 + 0.5 * noise.fbm(u, v, period: 32, octaves: 3);

      final warpU = u + 0.05 * noise.fbm(u, v, period: 4, octaves: 2);
      final warpV = v + 0.05 * noise.fbm(u + 0.37, v + 0.61, period: 4, octaves: 2);
      final caustic = noise.worley(warpU, warpV, cells: 6);
      final causticLine =
          math.pow(1.0 - _smoothstep(0.0, 0.32, caustic.f2 - caustic.f1), 3.0)
              .toDouble();

      final pebbleCells = noise.worley(u, v, cells: 26);
      final pebbleSize = 0.5 + 0.5 * noise.fbm(u, v, period: 5, octaves: 2);
      final pebble = _smoothstep(0.18 + 0.25 * pebbleSize, 0.08, pebbleCells.f1) *
          _smoothstep(0.35, 0.7, pebbleSize);

      final index = (y * size + x) * 4;
      pixels[index] = (crack.clamp(0.0, 1.0) * 255).round();
      pixels[index + 1] = (speckle.clamp(0.0, 1.0) * 255).round();
      pixels[index + 2] = (causticLine.clamp(0.0, 1.0) * 255).round();
      pixels[index + 3] = (pebble.clamp(0.0, 1.0) * 255).round();
    }
  }
  return PixelImage(pixels, size, size);
}

/// Central-difference normals of a wrapping height field. The image's +x is
/// the tangent (world +x) and its +y (row index) is the bitangent (world +z),
/// matching how the ground shader maps world XZ to UV.
PixelImage _normalMapFromHeights(
  Float64List heights,
  int size, {
  required double strength,
}) {
  final pixels = Uint8List(size * size * 4);
  double h(int x, int y) =>
      heights[((y + size) % size) * size + ((x + size) % size)];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = (h(x + 1, y) - h(x - 1, y)) * 0.5 * strength;
      final dy = (h(x, y + 1) - h(x, y - 1)) * 0.5 * strength;
      final inv = 1.0 / math.sqrt(dx * dx + dy * dy + 1.0);
      final index = (y * size + x) * 4;
      pixels[index] = ((-dx * inv * 0.5 + 0.5) * 255).round().clamp(0, 255);
      pixels[index + 1] = ((-dy * inv * 0.5 + 0.5) * 255).round().clamp(0, 255);
      pixels[index + 2] = ((inv * 0.5 + 0.5) * 255).round().clamp(0, 255);
      pixels[index + 3] = (h(x, y).clamp(0.0, 1.0) * 255).round();
    }
  }
  return PixelImage(pixels, size, size);
}

// ---------------------------------------------------------------- noise

/// Periodic gradient noise and Worley noise over the unit square, so a baked
/// tile wraps with no seam. Deterministic for a given seed.
class TileableNoise {
  TileableNoise(this.seed);

  final int seed;

  static final Float64List _gradientX = _buildGradients(true);
  static final Float64List _gradientY = _buildGradients(false);

  static Float64List _buildGradients(bool x) {
    final out = Float64List(256);
    for (var i = 0; i < 256; i++) {
      final angle = i / 256.0 * 2.0 * math.pi;
      out[i] = x ? math.cos(angle) : math.sin(angle);
    }
    return out;
  }

  int _hash(int x, int y) {
    var h = (seed * 0x27d4eb2d + x * 0x85ebca6b + y * 0xc2b2ae35) & 0xffffffff;
    h ^= h >> 16;
    h = (h * 0x7feb352d) & 0xffffffff;
    h ^= h >> 15;
    h = (h * 0x846ca68b) & 0xffffffff;
    h ^= h >> 16;
    return h;
  }

  static int _wrap(int value, int period) => ((value % period) + period) % period;

  double _gradientDot(int ix, int iy, int period, double dx, double dy) {
    final h = _hash(_wrap(ix, period), _wrap(iy, period)) & 255;
    return _gradientX[h] * dx + _gradientY[h] * dy;
  }

  /// Gradient noise at lattice coordinates ([x], [y]) that repeats every
  /// [period] lattice cells. Roughly -1..1.
  double perlin(double x, double y, int period) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final n00 = _gradientDot(x0, y0, period, fx, fy);
    final n10 = _gradientDot(x0 + 1, y0, period, fx - 1, fy);
    final n01 = _gradientDot(x0, y0 + 1, period, fx, fy - 1);
    final n11 = _gradientDot(x0 + 1, y0 + 1, period, fx - 1, fy - 1);
    final ux = _quintic(fx);
    final uy = _quintic(fy);
    final nx0 = n00 + (n10 - n00) * ux;
    final nx1 = n01 + (n11 - n01) * ux;
    return (nx0 + (nx1 - nx0) * uy) * 1.41;
  }

  /// Fractal noise over texture coordinates [u], [v] (one tile = 0..1) with
  /// [period] base cells per tile. Roughly -1..1. Tileable because every
  /// octave's period is an integer multiple of the tile.
  double fbm(
    double u,
    double v, {
    required int period,
    int octaves = 4,
    double gain = 0.5,
  }) {
    var sum = 0.0;
    var amplitude = 1.0;
    var norm = 0.0;
    var cells = period;
    for (var o = 0; o < octaves; o++) {
      sum += amplitude * perlin(u * cells, v * cells, cells);
      norm += amplitude;
      amplitude *= gain;
      cells *= 2;
    }
    return sum / norm;
  }

  /// Nearest and second-nearest feature-point distances, in cell units, for a
  /// wrapping grid of [cells]×[cells] jittered points.
  ({double f1, double f2}) worley(double u, double v, {required int cells}) {
    final x = u * cells;
    final y = v * cells;
    final cx = x.floor();
    final cy = y.floor();
    var f1 = double.infinity;
    var f2 = double.infinity;
    for (var oy = -1; oy <= 1; oy++) {
      for (var ox = -1; ox <= 1; ox++) {
        final gx = cx + ox;
        final gy = cy + oy;
        final h = _hash(_wrap(gx, cells), _wrap(gy, cells));
        final px = gx + (h & 0xffff) / 65535.0;
        final py = gy + ((h >> 16) & 0xffff) / 65535.0;
        final dx = px - x;
        final dy = py - y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < f1) {
          f2 = f1;
          f1 = d;
        } else if (d < f2) {
          f2 = d;
        }
      }
    }
    return (f1: f1, f2: f2);
  }
}

double _quintic(double t) => t * t * t * (t * (t * 6 - 15) + 10);

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

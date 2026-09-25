import 'package:flutter_module/tabs/scene/super_ultra/procedural_textures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectTileable(PixelImage image, {int channel = 3, int tolerance = 40}) {
    // A seamless tile: the last column/row is a near neighbour of the first.
    final w = image.width;
    final h = image.height;
    var total = 0;
    var count = 0;
    for (var y = 0; y < h; y++) {
      final a = image.pixels[(y * w) * 4 + channel];
      final b = image.pixels[(y * w + w - 1) * 4 + channel];
      total += (a - b).abs();
      count++;
    }
    for (var x = 0; x < w; x++) {
      final a = image.pixels[x * 4 + channel];
      final b = image.pixels[((h - 1) * w + x) * 4 + channel];
      total += (a - b).abs();
      count++;
    }
    expect(total / count, lessThan(tolerance));
  }

  test('the flame atlas is a clean 4x4 flipbook', () {
    final atlas = generateFlameAtlas(cell: 32);
    expect(atlas.width, 32 * kFlameAtlasColumns);
    expect(atlas.height, 32 * kFlameAtlasRows);
    expect(atlas.pixels.length, atlas.width * atlas.height * 4);
    // Cell borders are empty so mips never bleed a neighbour frame in.
    for (var x = 0; x < atlas.width; x++) {
      expect(atlas.pixels[x * 4 + 3], 0);
    }
    // Every frame has some flame in it.
    for (var frame = 0; frame < kFlameAtlasColumns * kFlameAtlasRows; frame++) {
      final ox = (frame % kFlameAtlasColumns) * 32;
      final oy = (frame ~/ kFlameAtlasColumns) * 32;
      var coverage = 0;
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          coverage += atlas.pixels[((oy + y) * atlas.width + ox + x) * 4 + 3];
        }
      }
      expect(coverage, greaterThan(0), reason: 'frame $frame is empty');
    }
  });

  test('the soft dot fades to nothing at its edge', () {
    final dot = generateSoftDot(size: 16);
    expect(dot.pixels[3], 0);
    final centre = (8 * 16 + 8) * 4 + 3;
    expect(dot.pixels[centre], greaterThan(150));
  });

  test('ground maps tile without a seam', () {
    expectTileable(generateGroundDetail(size: 64), channel: 3);
    expectTileable(generateGroundDetail(size: 64), channel: 0);
    expectTileable(generateSandRipples(size: 64), channel: 3);
    final masks = generateGroundMasks(size: 64);
    expectTileable(masks, channel: 1);
    expectTileable(masks, channel: 2, tolerance: 60);
  });

  test('normal maps point out of the surface', () {
    final detail = generateGroundDetail(size: 32);
    for (var i = 0; i < detail.pixels.length; i += 4) {
      // Blue encodes +Z; it must stay in the upper hemisphere.
      expect(detail.pixels[i + 2], greaterThan(128));
    }
  });

  test('the whole set bakes from one seed', () {
    final set = generateSuperUltraTextures(3);
    expect(set.flameAtlas.pixels, isNotEmpty);
    expect(set.smokeAtlas.width, set.smokeAtlas.height);
    expect(set.groundMasks.width, 256);
  });
}

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/tabs/scene/water_bump.dart';

void main() {
  group('generateWaveNormalPixels', () {
    test('generates expected pixel buffer size with opaque alpha', () {
      const size = 64;
      final pixels = generateWaveNormalPixels(size: size);
      expect(pixels.length, equals(size * size * 4));

      for (var i = 0; i < pixels.length; i += 4) {
        expect(pixels[i + 3], equals(255)); // Alpha is always 255
      }
    });

    test('normal vectors are unit length and point predominantly upward (+Z)', () {
      const size = 32;
      final pixels = generateWaveNormalPixels(size: size);

      for (var i = 0; i < pixels.length; i += 4) {
        final nx = (pixels[i] / 255.0) * 2.0 - 1.0;
        final ny = (pixels[i + 1] / 255.0) * 2.0 - 1.0;
        final nz = (pixels[i + 2] / 255.0) * 2.0 - 1.0;

        // Vector length is approximately 1.0
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        expect(len, closeTo(1.0, 0.05));

        // Normal points upward towards the viewer (nz > 0.6)
        expect(nz, greaterThan(0.6));
      }
    });

    test('pixel values are within valid byte ranges and vary with wave slopes', () {
      const size = 64;
      final pixels = generateWaveNormalPixels(size: size);

      var minR = 255, maxR = 0;
      var minG = 255, maxG = 0;
      var minB = 255, maxB = 0;

      for (var i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];

        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (g < minG) minG = g;
        if (g > maxG) maxG = g;
        if (b < minB) minB = b;
        if (b > maxB) maxB = b;
      }

      // Proves normal map contains dynamic slope perturbations (not flat)
      expect(maxR - minR, greaterThan(20));
      expect(maxG - minG, greaterThan(20));
      // Z (blue) component stays high for upward-facing water surface
      expect(minB, greaterThan(180));
    });
  });
}

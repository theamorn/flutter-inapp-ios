import 'dart:math' as math;
import 'dart:typed_data';

/// Generates a seamless, looping tangent-space normal map representing ocean water ripples.
///
/// Returns a [Uint8List] of RGBA8 pixels with dimensions [size] x [size].
/// Normal vector (nx, ny, nz) is encoded as:
/// R = (nx * 0.5 + 0.5) * 255
/// G = (ny * 0.5 + 0.5) * 255
/// B = (nz * 0.5 + 0.5) * 255
/// A = 255
Uint8List generateWaveNormalPixels({int size = 128}) {
  final pixels = Uint8List(size * size * 4);
  const twoPi = math.pi * 2.0;

  // Multi-frequency wave harmonics (fx, fy, amplitude).
  // Integer frequencies guarantee seamless wrapping at texture boundaries.
  const waves = <(double fx, double fy, double amp)>[
    (2.0, 3.0, 0.18),
    (4.0, -3.0, 0.14),
    (-3.0, 5.0, 0.10),
    (6.0, 2.0, 0.08),
    (-5.0, -4.0, 0.06),
    (8.0, 7.0, 0.04),
  ];

  var idx = 0;
  for (var y = 0; y < size; y++) {
    final v = y / size;
    for (var x = 0; x < size; x++) {
      final u = x / size;

      // Surface slope derivatives
      var dhDu = 0.0;
      var dhDv = 0.0;

      for (final (fx, fy, amp) in waves) {
        final phase = twoPi * (fx * u + fy * v);
        final cosPhase = math.cos(phase);
        dhDu += amp * fx * twoPi * cosPhase;
        dhDv += amp * fy * twoPi * cosPhase;
      }

      // Normal = normalize(-dhDu * scale, -dhDv * scale, 1.0)
      final nx = -dhDu * 0.08;
      final ny = -dhDv * 0.08;
      const nz = 1.0;
      final invLen = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz);

      final normX = nx * invLen;
      final normY = ny * invLen;
      final normZ = nz * invLen;

      pixels[idx] = ((normX * 0.5 + 0.5) * 255.0).clamp(0, 255).toInt();
      pixels[idx + 1] = ((normY * 0.5 + 0.5) * 255.0).clamp(0, 255).toInt();
      pixels[idx + 2] = ((normZ * 0.5 + 0.5) * 255.0).clamp(0, 255).toInt();
      pixels[idx + 3] = 255;
      idx += 4;
    }
  }

  return pixels;
}

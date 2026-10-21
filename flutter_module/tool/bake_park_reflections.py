"""Bakes the Shop header's park reflections from a Radiance .hdr.

Writes three RGBM levels of the equirect (512x256, 128x64, 32x16) as raw
RGBA bytes. nimbus_metal.fmat samples them along the reflection vector and
blends by roughness. The engine's own prefiltered radiance comes back black
on the Adreno test phone (base-mip-only sampling, flutter#189965); plain
single-mip textures sample fine there.

Each level box-averages the unclamped radiance before encoding, so the sun's
energy still brightens the blurred levels. RGBM: rgb = stored.rgb^2 *
stored.a * RANGE; squaring is a cheap gamma that keeps detail in the darks.

Usage: python3 tool/bake_park_reflections.py <source.hdr> <out_prefix>
"""
import math
import sys

RANGE = 16.0


def read_hdr(path):
    data = open(path, 'rb').read()
    i = 0
    while True:
        j = data.index(b'\n', i)
        line = data[i:j]
        i = j + 1
        if line.startswith(b'-Y'):
            parts = line.split()
            h, w = int(parts[1]), int(parts[3])
            break
    pixels = []
    for _ in range(h):
        assert data[i] == 2 and data[i + 1] == 2, 'only RLE scanlines'
        i += 4
        channels = []
        for _ in range(4):
            row = bytearray()
            while len(row) < w:
                n = data[i]
                i += 1
                if n > 128:
                    row.extend(bytes([data[i]]) * (n - 128))
                    i += 1
                else:
                    row.extend(data[i:i + n])
                    i += n
            channels.append(row)
        r, g, b, e = channels
        out = []
        for x in range(w):
            if e[x] == 0:
                out.append((0.0, 0.0, 0.0))
            else:
                f = math.ldexp(1.0, e[x] - 136)
                out.append((r[x] * f, g[x] * f, b[x] * f))
        pixels.append(out)
    return w, h, pixels


def downsample(w, h, pixels, factor):
    nw, nh = w // factor, h // factor
    out = []
    n = factor * factor
    for y in range(nh):
        row = []
        for x in range(nw):
            sr = sg = sb = 0.0
            for dy in range(factor):
                src = pixels[y * factor + dy]
                for dx in range(factor):
                    p = src[x * factor + dx]
                    sr += p[0]
                    sg += p[1]
                    sb += p[2]
            row.append((sr / n, sg / n, sb / n))
        out.append(row)
    return nw, nh, out


def encode_rgbm(pixels):
    out = bytearray()
    for row in pixels:
        for r, g, b in row:
            r, g, b = (min(c / RANGE, 1.0) for c in (r, g, b))
            m = min(max(math.ceil(max(r, g, b) * 255) / 255, 1 / 255), 1.0)
            out += bytes([
                round(math.sqrt(min(r / m, 1.0)) * 255),
                round(math.sqrt(min(g / m, 1.0)) * 255),
                round(math.sqrt(min(b / m, 1.0)) * 255),
                round(m * 255),
            ])
    return out


if __name__ == '__main__':
    source, prefix = sys.argv[1], sys.argv[2]
    w, h, px = read_hdr(source)
    if w > 512:
        w, h, px = downsample(w, h, px, w // 512)
    for level, factor in enumerate([1, 4, 4]):
        if factor > 1:
            w, h, px = downsample(w, h, px, factor)
        path = f'{prefix}_{level}.rgbm'
        open(path, 'wb').write(encode_rgbm(px))
        print(path, w, h)

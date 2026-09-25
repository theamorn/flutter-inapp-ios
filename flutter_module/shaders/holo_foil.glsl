#include <flutter/runtime_effect.glsl>

// Holographic foil face of the promo badge (tab 4, route /promo).
//
// Drawn into the card's own rect: FlutterFragCoord is card-local under
// Impeller, so the pattern stays glued to the card through the renderer's
// rotation and perspective. Uniform order is a contract with the index
// constants in lib/tabs/promo/holo_badge.dart.

precision highp float;

uniform vec2 uSize;      // 0, 1: card size in logical px
uniform float uTime;     // 2: seconds, for slow drift and twinkle
uniform vec2 uTilt;      // 3, 4: (sin yaw, lean), roughly -1..1
uniform float uShine;    // 5: claim pulse, 0 -> 1 once
uniform float uClaimed;  // 6: 0 -> 1, shifts the foil toward gold
uniform float uFace;     // 7: 0 front, 1 back

out vec4 fragColor;

const float TAU = 6.28318530718;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 4; i++) {
    value += amplitude * valueNoise(p);
    p *= 2.03;
    amplitude *= 0.5;
  }
  return value;
}

float roundedBoxSdf(vec2 point, vec2 halfSize, float radius) {
  vec2 distanceToEdge = abs(point) - halfSize + vec2(radius);
  return length(max(distanceToEdge, vec2(0.0)))
      + min(max(distanceToEdge.x, distanceToEdge.y), 0.0)
      - radius;
}

// Thin-film interference, approximated by a cosine palette.
vec3 film(float t) {
  return 0.5 + 0.5 * cos(TAU * (t + vec3(0.0, 0.33, 0.67)));
}

void main() {
  vec2 size = max(uSize, vec2(1.0));
  vec2 fragment = FlutterFragCoord().xy;
  vec2 uv = fragment / size;
  vec2 centered = fragment - size * 0.5;

  float radius = min(size.x, size.y) * 0.1;
  float edge = roundedBoxSdf(centered, size * 0.5 - 0.5, radius);
  float mask = 1.0 - smoothstep(-1.0, 0.5, edge);
  if (mask <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // The light the foil catches: the badge's own turn and lean, plus a slow
  // idle drift so a badge hanging still is never a dead picture.
  vec2 light = uTilt + vec2(sin(uTime * 0.35), cos(uTime * 0.27)) * 0.22;

  // Base: deep indigo into black, with a faint engraved guilloche.
  vec3 color = mix(vec3(0.10, 0.07, 0.25), vec3(0.015, 0.01, 0.05), uv.y);
  color *= mix(1.0, 0.72, uFace);
  float wave = sin(centered.y * mix(0.18, 0.26, uFace)
      + sin(centered.x * 0.045) * 4.0);
  color += smoothstep(0.93, 1.0, wave) * 0.05;

  // Holo foil: saturated rainbow bands running diagonally, sliding with the
  // light, seen through fine striations and soft cloud, and strongest around
  // the glare spot where the foil catches the light.
  float bands = uv.x * 0.9 + uv.y * 0.55 + dot(light, vec2(0.9, 0.6));
  vec3 rainbow = film(bands * 1.6 + fbm(uv * 2.5) * 0.25);
  vec3 gold = mix(vec3(1.0, 0.86, 0.5), vec3(0.8, 0.5, 0.18),
      0.5 + 0.5 * sin(bands * TAU * 1.3));
  vec3 foil = mix(rainbow, gold, uClaimed);
  float striations = 0.82 + 0.18 * sin((uv.x - uv.y * 0.6) * 260.0);
  float cloud = 0.55 + 0.45 * fbm(uv * vec2(5.0, 3.5) + light * 0.4);
  vec2 glareAt = vec2(0.5) + light * vec2(0.65, 0.55);
  vec2 fromGlare = (uv - glareAt) * vec2(1.0, size.y / size.x * 1.6);
  float glare = exp(-dot(fromGlare, fromGlare) * 5.0);
  // The back is quieter until it carries the claimed code, which shines gold.
  float faceStrength = mix(1.0, mix(0.45, 0.9, uClaimed), uFace);
  float holo = striations * cloud * (0.32 + 1.1 * glare) * faceStrength;
  color += foil * holo;

  // Glitter: each cell has a random micro-facet that flashes when the light
  // lines up with it.
  vec2 cells = uv * vec2(56.0, 36.0);
  vec2 cell = floor(cells);
  float seed = hash(cell);
  vec3 facet = normalize(vec3(
      (vec2(seed, hash(cell + 17.0)) - 0.5) * 1.8, 1.0));
  vec3 toLight = normalize(vec3(light.x * 1.6, -light.y * 1.6 + 0.15, 1.0));
  float spark = pow(max(dot(facet, toLight), 0.0), 70.0)
      * smoothstep(0.42, 0.0, length(fract(cells) - 0.5))
      * step(0.45, hash(cell + 3.0))
      * (0.6 + 0.4 * sin(uTime * 3.0 + seed * TAU));
  color += spark * (1.2 + foil * 0.8);

  // Specular band that tracks the light, plus the claim pulse sweeping across.
  float diagonal = uv.x + uv.y * 0.45;
  float band = exp(-pow((diagonal - 0.72 - light.x * 0.85) * 4.5, 2.0));
  color += band * 0.2;
  float pulse = sin(uShine * 3.14159265);
  color += exp(-pow((diagonal - uShine * 1.9 + 0.2) * 7.0, 2.0)) * pulse;

  // Rim light that grows as the card turns away from the viewer.
  float rim = exp(edge / 5.0);
  color += rim * (0.15 + length(uTilt) * 0.7) * foil;

  // Soft shoulder: bright foil stays saturated instead of clipping to white.
  color = 1.0 - exp(-color * 1.25);

  fragColor = vec4(color * mask, mask);
}

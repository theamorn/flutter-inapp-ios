#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uTouchPosition;
uniform float uRippleStartTime;
uniform float uRefractionStrength;
uniform float uThickness;
uniform float uDayNight;
uniform sampler2D uImage;

out vec4 fragColor;

float roundedBoxSdf(vec2 point, vec2 halfSize, float radius) {
  vec2 distanceToEdge = abs(point) - halfSize + vec2(radius);
  return length(max(distanceToEdge, vec2(0.0)))
      + min(max(distanceToEdge.x, distanceToEdge.y), 0.0)
      - radius;
}

void main() {
  vec2 fragmentPosition = FlutterFragCoord().xy;
  vec2 safeResolution = max(uResolution, vec2(1.0));
  vec2 uv = fragmentPosition / safeResolution;
  vec2 texel = 1.0 / safeResolution;
  vec2 center = safeResolution * 0.5;
  vec2 halfSize = max(center - vec2(1.0), vec2(1.0));
  float cornerRadius = min(30.0, min(safeResolution.x, safeResolution.y) * 0.09);

  float surfaceDistance = roundedBoxSdf(
    fragmentPosition - center,
    halfSize,
    cornerRadius
  );
  float glassMask = 1.0 - smoothstep(-0.4, 1.0, surfaceDistance);

  // Treat the panel like a shallow convex lens. The normal grows toward the
  // rim, so moving content bends more strongly at the glass edge.
  vec2 localPosition = (fragmentPosition - center) / halfSize;
  float distanceFromCenter = clamp(dot(localPosition, localPosition), 0.0, 1.6);
  vec2 surfaceNormal = localPosition * (0.28 + 0.72 * distanceFromCenter);
  vec2 edgeNormal = sign(localPosition)
      * smoothstep(vec2(0.56), vec2(0.98), abs(localPosition));
  surfaceNormal += edgeNormal * (0.24 + uThickness * 0.36);

  // One live radial wave is enough to make a drag feel tactile without a
  // dynamic loop or a texture full of ripple state.
  float rippleAge = uTime - uRippleStartTime;
  vec2 fromTouch = fragmentPosition - uTouchPosition;
  float touchDistance = length(fromTouch);
  vec2 rippleDirection = fromTouch / max(touchDistance, 1.0);
  float rippleRadius = rippleAge * 215.0;
  float distanceFromWave = touchDistance - rippleRadius;
  float rippleLifetime = step(0.0, rippleAge) * step(rippleAge, 2.35);
  float rippleEnvelope = exp(-abs(distanceFromWave) * 0.038)
      * exp(-rippleAge * 0.82)
      * rippleLifetime;
  float rippleWave = sin(distanceFromWave * 0.19) * rippleEnvelope;
  surfaceNormal += rippleDirection * rippleWave * (0.95 + uThickness * 0.55);

  float displacementPixels = (1.5 + 12.5 * uRefractionStrength)
      * (0.38 + 0.82 * uThickness);
  vec2 refractedUv = uv + surfaceNormal * displacementPixels * texel;
  refractedUv = clamp(refractedUv, texel * 0.5, vec2(1.0) - texel * 0.5);

  // Separate the three samples by less than one logical pixel at the strongest
  // setting. This reads as optical dispersion instead of a glitch effect.
  vec2 dispersionDirection = surfaceNormal / max(length(surfaceNormal), 0.001);
  vec2 dispersion = dispersionDirection
      * (0.15 + 0.75 * uRefractionStrength)
      * texel;
  float red = texture(uImage, clamp(refractedUv + dispersion, vec2(0.0), vec2(1.0))).r;
  float green = texture(uImage, refractedUv).g;
  float blue = texture(uImage, clamp(refractedUv - dispersion, vec2(0.0), vec2(1.0))).b;
  vec4 original = texture(uImage, clamp(uv, vec2(0.0), vec2(1.0)));
  vec3 refracted = vec3(red, green, blue);

  vec3 dayTint = vec3(0.91, 0.98, 1.04);
  vec3 nightTint = vec3(0.60, 0.72, 1.04);
  vec3 glassTint = mix(dayTint, nightTint, uDayNight);
  float tintAmount = 0.055 + uThickness * 0.105;
  vec3 glassColor = mix(refracted, glassTint, tintAmount);

  // A tight bright rim and a broad top-left sheen sell the material more than
  // displacement alone. Ripple highlights briefly catch the same light.
  float rim = exp(-abs(surfaceDistance) * (0.15 + uThickness * 0.025));
  float directionalRim = 0.62
      + 0.38 * max(dot(normalize(surfaceNormal + vec2(0.001)), normalize(vec2(-0.8, -0.6))), 0.0);
  vec3 rimColor = mix(vec3(0.86, 0.96, 1.0), vec3(0.62, 0.78, 1.0), uDayNight);
  glassColor += rimColor * rim * directionalRim * (0.22 + uThickness * 0.16);

  float sheen = pow(clamp(1.0 - dot(uv, vec2(0.62, 0.54)), 0.0, 1.0), 5.0);
  glassColor += rimColor * sheen * 0.075;
  glassColor += rimColor * abs(rippleWave) * 0.12;

  fragColor = vec4(mix(original.rgb, glassColor, glassMask), original.a * glassMask);
}

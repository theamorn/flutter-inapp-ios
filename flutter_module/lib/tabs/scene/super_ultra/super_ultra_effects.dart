/// The Super Ultra features the effects menu can switch off one at a time,
/// so their cost can be read off the device's frame times, plus the two
/// image-quality picks (anti-aliasing and render scale).
///
/// Every effect is on by default; switching one off is a measuring tool, not
/// a quality preset (grass, for one, simply disappears).
library;

import 'package:flutter_scene/scene.dart' show AntiAliasingMode;

/// How Super Ultra smooths edges. One pick; SMAA by default.
enum SuperUltraAntiAliasing {
  smaa(
    'SMAA',
    'Three passes over the finished image; clean edges, little blur',
    AntiAliasingMode.smaa,
  ),
  msaa(
    'MSAA',
    '4 samples a pixel. The sea reads the scene behind it, which splits the '
        'pass and sends the 4× depth buffer to memory and back',
    AntiAliasingMode.msaa,
  ),
  taa(
    'TAA',
    'Blends jittered frames; also calms AO and god-ray noise, can smear '
        'moving water',
    AntiAliasingMode.taa,
  ),
  fxaa(
    'FXAA',
    'One pass over the finished image; the softest',
    AntiAliasingMode.fxaa,
  ),
  none('Off', 'Jagged edges', AntiAliasingMode.none);

  const SuperUltraAntiAliasing(this.label, this.cost, this.mode);

  static const SuperUltraAntiAliasing initial = SuperUltraAntiAliasing.smaa;

  /// Menu label.
  final String label;

  /// What it costs, in a line.
  final String cost;

  final AntiAliasingMode mode;
}

/// How many pixels Super Ultra draws before scaling up to the screen. Every
/// screen-space pass (AO, god rays, soft shadows, fog, bloom, the sea's
/// scene copies) pays per pixel. One pick; 85% by default.
enum SuperUltraRenderScale {
  percent100('100%', 'Every screen pixel', 1.0),
  percent85('85%', '72% of the pixels, scaled up', 0.85),
  percent75('75%', '56% of the pixels, scaled up', 0.75);

  const SuperUltraRenderScale(this.label, this.cost, this.scale);

  static const SuperUltraRenderScale initial = SuperUltraRenderScale.percent85;

  /// Menu label.
  final String label;

  /// What it costs, in a line.
  final String cost;

  /// `Scene.renderScale`.
  final double scale;
}

/// Where an effect sits in the menu.
enum SuperUltraEffectGroup {
  lighting('Lighting & shadows'),
  post('Post effects'),
  scene('Scene content');

  const SuperUltraEffectGroup(this.label);

  final String label;
}

enum SuperUltraEffect {
  planarReflection(
    'Sea reflection',
    'Draws the whole scene a second time, mirrored under the sea',
    SuperUltraEffectGroup.lighting,
  ),
  godRays(
    'God rays',
    'Light shafts: marches the shadow map for every pixel',
    SuperUltraEffectGroup.lighting,
  ),
  ambientOcclusion(
    'Ambient occlusion (GTAO)',
    'Darkens creases; several screen-sized passes',
    SuperUltraEffectGroup.lighting,
  ),
  contactShadows(
    'Contact shadows',
    'Short screen-space march for the line where things touch',
    SuperUltraEffectGroup.lighting,
  ),
  secondCascade(
    'Far shadow cascade',
    'Draws the shadow casters again into a second shadow map',
    SuperUltraEffectGroup.lighting,
  ),
  softShadows(
    'Soft shadows (PCSS)',
    'Blocker search plus a wide filter per shadowed pixel',
    SuperUltraEffectGroup.lighting,
  ),
  bloom(
    'Bloom',
    'Glow around bright things: a chain of small blur passes',
    SuperUltraEffectGroup.post,
  ),
  lensFlare(
    'Lens flare',
    'Ghosts and a halo off the sun',
    SuperUltraEffectGroup.post,
  ),
  fog(
    'Fog',
    'Distance haze that glows toward the sun',
    SuperUltraEffectGroup.post,
  ),
  filmFinish(
    'Vignette, grain, grading',
    'Final colour touches',
    SuperUltraEffectGroup.post,
  ),
  sea(
    'Full sea',
    'Refraction, depth-tinted water and the reflection. Off swaps in a '
        'simple opaque sea with the same waves',
    SuperUltraEffectGroup.scene,
  ),
  grass(
    'Grass',
    '2,758 instanced tufts with wind in the vertex shader',
    SuperUltraEffectGroup.scene,
  ),
  fireVfx(
    'Campfire VFX',
    'Flame, ember, spark and smoke particles, coal bed, heat haze',
    SuperUltraEffectGroup.scene,
  );

  const SuperUltraEffect(this.label, this.cost, this.group);

  /// Menu label.
  final String label;

  /// What it costs, in a line.
  final String cost;

  final SuperUltraEffectGroup group;

  /// The effect this one only works on top of: the reflection is part of
  /// the full sea, and the simple sea has none.
  SuperUltraEffect? get needs =>
      this == planarReflection ? SuperUltraEffect.sea : null;
}

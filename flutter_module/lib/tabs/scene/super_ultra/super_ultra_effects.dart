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
  percent75('75%', '56% of the pixels, scaled up', 0.75),
  auto(
    'Auto',
    'Starts at 100% and lowers the scale (to 60%) whenever frames miss 60 fps',
    1.0,
    adaptive: true,
  );

  const SuperUltraRenderScale(
    this.label,
    this.cost,
    this.scale, {
    this.adaptive = false,
  });

  static const SuperUltraRenderScale initial = SuperUltraRenderScale.percent85;

  /// Menu label.
  final String label;

  /// What it costs, in a line.
  final String cost;

  /// `Scene.renderScale`.
  final double scale;

  /// Whether the renderer may lower the scale itself
  /// (`Scene.renderQuality.adaptive`, flutter_scene 0.24).
  final bool adaptive;
}

/// How many frames of GPU work may be queued before the scene re-presents its
/// last image instead of drawing a new one (`Scene.maxGpuFramesInFlight`,
/// flutter_scene 0.24). One pick; the engine's 1 by default.
enum SuperUltraGpuPacing {
  one('1 frame', 'UI thread never waits on the GPU; about a tenth of GPU '
      'throughput held back', 1),
  two('2 frames', 'Full GPU throughput; the UI thread can still wait about '
      'half as long as before 0.24', 2);

  const SuperUltraGpuPacing(this.label, this.cost, this.frames);

  static const SuperUltraGpuPacing initial = SuperUltraGpuPacing.one;

  final String label;
  final String cost;
  final int frames;
}

/// Caps how often the scene renders (`SceneView.maxFrameRate`, 0.24): an even
/// cadence instead of a ragged one when the device can't hold the panel rate.
enum SuperUltraFrameCap {
  uncapped('Uncapped', 'Renders every frame it can', null),
  fps60('60 fps', 'Every other refresh on a 120 Hz panel; steadier, cooler', 60);

  const SuperUltraFrameCap(this.label, this.cost, this.fps);

  static const SuperUltraFrameCap initial = SuperUltraFrameCap.uncapped;

  final String label;
  final String cost;
  final double? fps;
}

/// How many scene-colour copies a frame may take for the sea and the heat
/// haze (`Scene.sceneColorCaptureBatches`, 0.24). Shared is one copy, but the
/// haze then sees the scene from before the sea was drawn.
enum SuperUltraSceneCopies {
  separate(
    'Separate',
    'One copy per overlapping reader (engine default)',
    null,
  ),
  shared('Shared', 'One copy for all; the sea may vanish behind the haze', 1);

  const SuperUltraSceneCopies(this.label, this.cost, this.batches);

  static const SuperUltraSceneCopies initial = SuperUltraSceneCopies.separate;

  final String label;
  final String cost;
  final int? batches;
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
  fireShadows(
    'Campfire shadows',
    'Point-light shadows: the casters draw again into six cube faces '
        '(at night; by day the god rays need the shadow atlas)',
    SuperUltraEffectGroup.lighting,
  ),
  stoneIndirect(
    'Custom firepit light',
    'The firepit stones light their own shadowed sides from the sky and '
        'ground (material hooks). Off: the engine\'s baked sky light',
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
  lightningRipple(
    'Lightning ripple',
    'A short screen ripple from each lightning strike in view (screen '
        'distortion pass, only while a ripple lives)',
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
  depthOfField(
    'Depth of field',
    'Bokeh blur in close-up and over-the-shoulder views; off in wide orbit views',
    SuperUltraEffectGroup.post,
  ),
  autoExposure(
    'Auto-exposure',
    'Smooth eye adaptation between bright noon sun, golden dusk and night',
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
  grassThinning(
    'Grass thinning',
    'Fewer tufts as the renderer lowers its quality tier: 75% on medium, '
        '50% on low, spread over the whole lawn. Off: every tuft at every tier',
    SuperUltraEffectGroup.scene,
  ),
  wind(
    'Wind',
    'A flag on a pole and palms and pines swaying in the wind (vertex '
        'stages); the storm blows harder. Off: no flag, still trees',
    SuperUltraEffectGroup.scene,
  ),
  glowCard(
    'Fire glow card',
    'One camera-facing additive card for the fire\'s core glow, ordered '
        'before the heat haze. Off: the old additive sprite emitter',
    SuperUltraEffectGroup.scene,
  ),
  fireVfx(
    'Campfire VFX',
    'Flame, ember, spark and smoke particles, coal bed, heat haze',
    SuperUltraEffectGroup.scene,
  ),
  fireflies(
    'Nocturnal fireflies',
    'Curl-noise glowing fireflies drifting above the lawn on clear nights',
    SuperUltraEffectGroup.scene,
  ),
  decals(
    'Ground decals',
    'Projected scorch ring under the campfire and footprints behind the player '
        '(reads scene depth)',
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

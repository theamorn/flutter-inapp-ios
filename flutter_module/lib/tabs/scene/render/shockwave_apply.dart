/// Puts a [ShockwavePool]'s ripples on screen through flutter_scene 0.24's
/// `Scene.screenDistortion`, and turns a strike's world position into the
/// screen point its ripple starts from.
library;

import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import 'shockwave_pool.dart';

/// Where [world] lands on a [viewport] seen through [camera], in screen UV
/// (origin top-left), or null when it is behind the camera or off screen:
/// a strike outside the view gets no ripple rather than one at the edge.
(double, double)? strikeScreenUv(Camera camera, Vector3 world, Size viewport) {
  if (viewport.isEmpty) return null;
  final uv = camera.projectToScreenUv(world, viewport);
  if (uv == null) return null;
  if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1) return null;
  return (uv.x, uv.y);
}

/// Triggers [pool] for [event] if the strike is on screen.
bool triggerStrike(ShockwavePool pool, StrikeEvent event, Camera camera, Size viewport) {
  final uv = strikeScreenUv(camera, Vector3(event.x, event.y, event.z), viewport);
  return uv != null && pool.trigger(event.id, uv.$1, uv.$2);
}

/// Mirrors [pool]'s live ripples into [scene]'s screen distortion, reusing
/// its pulse objects, and enables the pass only while a ripple lives.
void applyShockwaves(Scene scene, ShockwavePool pool) {
  final settings = scene.screenDistortion;
  final samples = pool.samples;
  final pulses = settings.pulses;
  while (pulses.length > samples.length) {
    pulses.removeLast();
  }
  for (var i = 0; i < samples.length; i++) {
    if (i == pulses.length) pulses.add(DistortionPulse());
    final s = samples[i];
    pulses[i]
      ..center.setValues(s.centerX, s.centerY)
      ..radius = s.radius
      ..thickness = s.thickness
      ..strength = s.strength
      ..chromaticAberration = s.chromaticAberration;
  }
  settings.enabled = samples.isNotEmpty;
}

/// Drops every ripple and switches the distortion pass off.
void clearSceneShockwaves(Scene scene, ShockwavePool pool) {
  pool.clear();
  scene.screenDistortion
    ..pulses.clear()
    ..enabled = false;
}

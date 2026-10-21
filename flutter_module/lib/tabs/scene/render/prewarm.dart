import 'package:flutter_scene/scene.dart';

/// Per-frame pipeline compilation budget during [prewarmPipelines]: short
/// enough that a slow device keeps answering input and animating its loading
/// screen between slices instead of blocking for the whole compile.
const Duration kPrewarmSliceBudget = Duration(milliseconds: 8);

/// Precompiles the GPU pipelines [scene] needs from [camera] (plus any extra
/// [views]) before the user interacts, including off-frustum meshes and both
/// the lean and full lit shader tiers (`allShadingTiers: true`, added in
/// flutter_scene 0.24.3) so mode switches (Normal ↔ Ultra ↔ Super Ultra) and
/// effect toggles (GTAO, campfire shadows) never stall a frame on first draw.
///
/// Safe in headless widget tests: if no Flutter GPU context is available, the
/// warm-up becomes a no-op and returns `false`.
Future<bool> prewarmPipelines(
  Scene scene,
  Camera camera, {
  List<RenderView> extraViews = const [],
  bool includeOffscreen = true,
  bool allShadingTiers = true,
  Duration? sliceBudget = kPrewarmSliceBudget,
}) async {
  try {
    await scene.warmUp(
      [RenderView(camera: camera), ...extraViews],
      includeOffscreen: includeOffscreen,
      sliceBudget: sliceBudget,
      allShadingTiers: allShadingTiers,
    );
    return true;
  } catch (_) {
    // Headless test environments without a Flutter GPU context cannot
    // compile pipelines; swallow cleanly so callers don't need try/catch.
    return false;
  }
}

/// Drops pooled transient render targets (`releaseTransientRenderTargets()`)
/// so hiding or leaving a heavy 3D scene immediately reclaims attachment memory.
///
/// Safe in headless widget tests where no GPU context exists.
bool releaseSceneTargets() {
  try {
    releaseTransientRenderTargets();
    return true;
  } catch (_) {
    return false;
  }
}

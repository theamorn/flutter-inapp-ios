# 05 — Tab 4: Liquid Glass panel

> **Status:** this panel no longer has a tab. Tab 4 is now the Shop page in `09-inline-holo-badge.md` on both hosts. The `/glass` route and this code stay supported, so the tab can be restored with one line per host.

## Goal

A control panel rendered behind a live glass surface: a fragment shader refracts the **actual scrolling widget tree beneath it**, and dragging a finger sends a ripple across the glass. Sliders control day/night, refraction strength, and glass thickness.

This is the tab that makes the development-cost argument. The same screen runs identically on Android, where the OS offers nothing comparable.

## Prerequisites

- `02-ios-host.md` complete (engine for route `/glass` exists).
- Read `ARCHITECTURE.md` for the route contract.

## Repo facts you need

- `flutter_module/pubspec.yaml` already depends on `flutter_shaders: ^0.1.3`. `AnimatedSampler` comes from there.
- **`flutter_module/lib/shader_screen.dart` is the reference implementation** for loading and driving a fragment shader: a `CustomPainter` holding a `ui.FragmentShader`, an `AnimationController` supplying time, `shouldRepaint` returning true for continuous animation. Read it first.
- Existing shaders live in `flutter_module/shaders/` and **must be listed under `flutter: shaders:` in `pubspec.yaml`** — not `assets:`. There are five already listed; follow that pattern for the new one.
- `flutter_module/lib/app_screen.dart` (1446 lines) contains the previous talk's effect gallery. Read it for technique if useful, but do not refactor it — it backs the `/` dev home.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/shaders/liquid_glass.glsl` | **new** — in-house custom fragment shader |
| `flutter_module/pubspec.yaml` | list the new shader + `liquid_glass_renderer` package |
| `flutter_module/lib/tabs/glass/glass_app.dart` | **new** — widget for route `/glass` with tab mode toggle |
| `flutter_module/lib/tabs/glass/liquid_glass.dart` | **new** — `AnimatedSampler` + custom painter |
| `flutter_module/lib/tabs/glass/package_liquid_glass.dart` | **new** — `liquid_glass_renderer` integration with `FakeGlass` fallback |
| `flutter_module/lib/main.dart` | wire `/glass` |

## Implementation notes

### The shader

`liquid_glass.glsl` samples the backdrop texture and displaces the sample coordinate. Roughly:

- **Refraction** — build a surface normal from the glass shape (rounded-rect SDF works well) and offset the UV along it. Thickness scales the offset.
- **Chromatic aberration** — sample R, G, B at slightly different offsets. Keep it subtle; overdone it reads as a broken screen rather than as glass.
- **Specular rim** — a bright edge where the normal turns away, which is what actually sells "glass" more than the refraction does.
- **Ripple** — a radial wave from the touch point that decays with distance and age, perturbing the normal as it passes.

Uniforms: resolution, time, touch position, ripple start time, refraction strength, thickness, day/night factor. Plus the backdrop `sampler2D`.

### Feeding it the live widget tree

The point of the tab is that the glass refracts **live, moving content** — not a static screenshot. Wrap the content subtree in `AnimatedSampler` from `flutter_shaders`, which snapshots the child each frame and hands it to the shader as `uImage`:

```dart
AnimatedSampler(
  (image, size, canvas) {
    shader
      ..setImageSampler(0, image)
      ..setFloat(...);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  },
  child: theContentBeneathTheGlass,
)
```

**Put a scrolling list under the glass.** A static background makes the effect look like an image filter; visibly scrolling content under a distorting surface is what proves it is live.

### Controls

Day/night (drives the palette and the glass tint), refraction strength, glass thickness. Make them real-time — the presenter drags them on stage.

## Inner Tab: In-House Custom Shader vs `liquid_glass_renderer` Library

Tab 4 now includes a top segmented control allowing instant comparison between the custom in-house shader and the community package [`liquid_glass_renderer`](https://pub.dev/packages/liquid_glass_renderer).

### Comparison Matrix

| Aspect | In-House Custom Shader (`liquid_glass.glsl`) | `liquid_glass_renderer` Package (`^0.2.0-dev.4`) |
|---|---|---|
| **Pipeline** | Single-pass fragment shader over `AnimatedSampler` | Multi-layer compositor (`LiquidGlassLayer` + `LiquidGlass`) |
| **Geometry** | Rounded rect SDF in GLSL | SDF geometry (`LiquidRoundedSuperellipse`, `LiquidOval`, `LiquidRoundedRectangle`) cached to offscreen textures |
| **Multi-shape Blending** | Single bounding panel | Metaball / smooth-min blending across shapes via `LiquidGlassBlendGroup` (up to 16 shapes) |
| **Optical Controls** | Refraction offset, subtle chromatic aberration, specular rim, day/night lerp | Refraction, blur, light angle/intensity, ambient light, saturation boost, chromatic aberration |
| **Interactivity** | Touch-driven propagating wave ripples via continuous clock | `GlassGlow` (touch light tracking) and `LiquidStretch` (jelly squash & stretch) |
| **Fallback** | Direct bypass | Built-in `FakeGlass` (backdrop filter based, no shader refraction) |

### Limitations & Performance Trade-offs

1. **Engine Requirement (Impeller Only)**:
   - `liquid_glass_renderer` strictly requires **Impeller** because its architecture depends on synchronous scene texture capture (`scene.toImageSync`) and `ImageFilter.shader`.
   - On **Skia**, Web, Windows, and Linux, the package automatically degrades or issues a warning, falling back to `FakeGlass`.
2. **Animation Memory Spike (Flutter Issue #138627)**:
   - Flutter's engine does not immediately dispose intermediate scene textures. Moving or animating glass shapes continuously causes transient memory spikes and GC churn.
   - *Mitigation*: Keep shapes stationary where possible, or use `FakeGlass` during heavy animations.
3. **GPU Fill-Rate & Thermal Impact**:
   - `LiquidGlassLayer` and `LiquidGlassBlendGroup` allocate offscreen textures covering their full bounding boxes.
   - On high-DPI (Retina @3x) devices, large glass layers demand high fill-rate and can trigger device heating or thermal throttling over prolonged usage.
4. **Blur + Blending Artifacts (Flutter Issue #170820)**:
   - Combining background blur with shape blending in `LiquidGlassBlendGroup` introduces visible edge artifacts.
5. **Shape Budget**:
   - Limit blended shapes to $\le 4-8$ per group; hard engine cap at 16 shapes.

## The talk track

This is iOS 26's Liquid Glass aesthetic, in one codebase, running identically on iOS and Android — where the platform gives you nothing equivalent and you would be hand-rolling it. And it ripples under your finger, because the shader takes the live widget tree as input: impractical in UIKit, impossible in a WebView.

Having both the in-house GLSL shader and the community `liquid_glass_renderer` package in the same tab lets you demonstrate the trade-offs live:
- The in-house shader demonstrates a predictable, single-pass, low-overhead pipeline tailored for maximum 120fps responsiveness and zero GC spikes.
- The `liquid_glass_renderer` package demonstrates complex superellipse geometries, multi-shape metaball merging, and how Impeller's new capabilities enable advanced effects with built-in `FakeGlass` fallbacks.

## Gotchas

- Shaders go under `flutter: shaders:` in `pubspec.yaml`, **not** `assets:`. Listed in the wrong section they will not compile and the failure message is unhelpful.
- `AnimatedSampler` snapshots its child every frame. Keep the subtree beneath the glass reasonably sized — snapshotting the entire screen including the glass itself creates a feedback loop.
- Do not put the glass inside its own `AnimatedSampler` subtree. It must be a sibling drawn over the content, or you get recursive sampling.
- GLSL in Flutter has restrictions: no dynamic-length loops, no `texture()` with computed LOD. Keep loops bounded by constants.
- `liquid_glass_renderer` requires Impeller; on Skia or during headless tests without shader support, ensure `FakeGlass` fallback handles the rendering gracefully.
- Test on Android before declaring parity. Impeller's GLSL handling differs from Skia's, and a shader that works on iOS can fail to compile on Android.

## Acceptance criteria

- [ ] Glass panel refracts visibly scrolling content beneath it, in real time.
- [ ] Dragging across the glass produces a ripple that propagates and decays.
- [ ] All three sliders take effect immediately.
- [ ] Holds the device's full refresh rate while dragging *and* scrolling simultaneously.
- [ ] Renders identically on Android (checked once `07-android-host.md` exists, or via `flutter run` on the module standalone before then).
- [ ] `flutter analyze` clean; `/` dev home unaffected.

## How to verify

Physical device, release mode.

1. Scroll the list under the glass. Content visibly distorts as it passes behind.
2. Drag continuously across the glass **while** the list is scrolling. This is the worst case: HUD must hold.
3. Sweep each slider end to end mid-drag. No hitching.
4. Run the same route on Android and compare screenshots side by side. Differences are bugs — parity is the claim being made.

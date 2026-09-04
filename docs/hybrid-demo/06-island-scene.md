# 06 — Tab 5: Island scene (`flutter_scene`)

## Goal

The finale. A low-poly island rendered with `flutter_scene`, with an orbiting camera, a day→night slider, a particle layer, and — the interaction the tab is built around — **tap anywhere on the island and a character walks there.**

## Prerequisites

- `01-scene-spike.md` complete, **including its Findings section.** Read it before designing anything here — it records whether real directional lighting is available, which decides how day/night is implemented.
- `02-ios-host.md` complete (engine for route `/scene` exists, `FLTEnableFlutterGPU` set).

## Repo facts you need

- `flutter_scene`, `flutter_scene_importer`, and `flutter_gpu` were added to `flutter_module/pubspec.yaml` in task 01.
- Flutter GPU is enabled via the host's `Info.plist` key `FLTEnableFlutterGPU` (capital `GPU` — see `01-scene-spike.md` for the casing trap).
- `flutter_module/lib/shader_screen.dart` is the reference for fragment-shader work, which the sky layer and particle overlay will use.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/assets/models/island.model` | **new** — imported, committed |
| `flutter_module/assets/models/character.model` | **new** — imported, committed |
| `flutter_module/lib/tabs/scene/scene_app.dart` | **new** — widget for route `/scene` |
| `flutter_module/lib/tabs/scene/island_scene.dart` | **new** — scene graph + camera |
| `flutter_module/lib/tabs/scene/tap_to_move.dart` | **new** — unprojection + movement |
| `flutter_module/lib/tabs/scene/particles.dart` | **new** — 2D overlay layer |
| `flutter_module/pubspec.yaml` | list `.model` files under `assets:` |
| `flutter_module/lib/main.dart` | wire `/scene` |

## Implementation notes

### Assets

Low-poly island diorama plus a character or vehicle. Use CC0 sources — Kenney, Poly Pizza. Import each with:

```bash
fvm dart run flutter_scene_importer:import --input assets/models/island.glb --output assets/models/island.model
```

Commit the `.model` output and list it under `flutter: assets:`. The source `.glb` need not ship.

**Choose assets that read from the back of a room.** Strong silhouettes, flat saturated colours, chunky forms. Detailed realistic models turn to mush on a projector.

### Camera

Orbit on horizontal/vertical drag, pinch to zoom, clamped so the presenter cannot get lost under the terrain. Give it gentle inertia — it feels considered, and it looks good while the presenter is talking rather than touching.

### Tap to move — the centrepiece

This is what proves the tab is a live scene graph and not a video loop. An audience assumes a pretty 3D render is pre-baked; watching it respond to an arbitrary tap removes that doubt instantly.

1. Take the tap position in local widget coordinates.
2. Build a ray: unproject through the camera's inverse view-projection matrix at near and far planes.
3. Intersect the ray with the ground plane `y = 0`. (If the island is not flat, intersect with a simplified collision plane or heightfield — do not try to raycast the mesh.)
4. Clamp the target to the island bounds so the character cannot walk into the sea.
5. Animate the character node's transform toward the target with easing, rotating it to face the direction of travel.
6. Drop an expanding ring marker at the tap point that fades out.

### Day → night

**Implementation depends on the Findings in `01-scene-spike.md`.** Either drive a real directional light's direction and colour, or — if `flutter_scene` does not expose usable runtime lighting — drive ambient/environment colour plus a shader-drawn sky gradient composited *behind* the 3D. Both look good. Pick the one the spike established as actually available; do not discover this here.

The slider should also swap the particle layer: daytime dust motes → nighttime fireflies.

### Particles

A **2D overlay** composited over the 3D render, not 3D particles. Far cheaper, and at projector distance it reads better anyway.

### Readout

Triangle count and draw calls on screen, next to the HUD's framerate. Real geometry, real numbers, still pinned at full refresh rate — that juxtaposition is the argument.

## Gotchas

- `flutter_scene`'s material and lighting model is minimal. Do not design a lighting look you have not confirmed is achievable — that is precisely what task 01 exists to settle.
- Unprojection is easy to get subtly wrong. Verify by tapping the four corners of the island and confirming the character arrives where you tapped, not offset. Watch for device-pixel-ratio and widget-vs-screen coordinate mistakes — the classic symptom is an error that grows toward the screen edges.
- Do not raycast against the full mesh. A ground plane or coarse heightfield is enough and is orders of magnitude cheaper.
- If the model renders black, it is almost always missing materials or an unsupported material type in the import, not a lighting bug.
- The engine stays alive when the tab is hidden. Stop the render loop when the route is not visible, or tab 5 quietly burns battery and GPU behind tabs 1–4 and skews every other tab's HUD numbers.

## Acceptance criteria

- [ ] Island renders on a physical device in release mode.
- [ ] Camera orbits and zooms smoothly, clamped sensibly.
- [ ] Tapping anywhere on the island moves the character there, facing the direction of travel, with a visible tap marker.
- [ ] Day→night slider works smoothly end to end and swaps the particle layer.
- [ ] Triangle count and draw calls are displayed.
- [ ] Full refresh rate held during simultaneous orbit + character movement + day/night sweep.
- [ ] Render loop stops when the tab is not visible.

## How to verify

Physical device, release mode. This one gets its own careful pass — it is the finale and it is the least proven technology in the stack.

1. Tap all four corners of the island and the centre. The character must arrive where you tapped, every time.
2. Orbit and pinch **while** the character is walking. No hitching.
3. Sweep day→night mid-walk, mid-orbit. Watch the HUD across the whole sweep.
4. Tab away to tab 1 and confirm the HUD's numbers return to tab-1 baseline — if they do not, the scene is still rendering in the background.
5. Leave the tab open for five minutes and watch memory for drift.
6. Run the full sequence twice more. The finale must not be a coin flip on stage.

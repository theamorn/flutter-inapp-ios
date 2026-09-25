# 06 — Tab 5: Island scene (`flutter_scene`)

## Goal

The finale. A low-poly island rendered with `flutter_scene`, with an orbiting camera, a day→night slider, a particle layer, and — the interaction the tab is built around — **tap anywhere on the island and a character walks there.**

It ships in three quality modes, chosen on screen: **Normal** (the stage path), **Ultra** (more props, NPC, flock, buoys), and **Super Ultra** (clear water, sculpted shore, grass, VFX fire, a visible sun and moon, god rays — for hardware with headroom). See [Super Ultra](#super-ultra).

> **Reusing this for another 3D demo?** Start from [`FLUTTER-3D-PLAYBOOK.md`](FLUTTER-3D-PLAYBOOK.md). It collects every setup trap, engine rule, recipe and verification technique from this doc in a form that doesn't depend on the island.

## Prerequisites

- `01-scene-spike.md` complete, **including its Findings section.** Read it before designing anything here — it records whether real directional lighting is available, which decides how day/night is implemented.
- `02-ios-host.md` complete (engine for route `/scene` exists, `FLTEnableFlutterGPU` set).

## Repo facts you need

- `flutter_scene` (0.23.0) and `flutter_gpu` (from the SDK) are in `flutter_module/pubspec.yaml`, with `vector_math` as an explicit dependency. **`flutter_scene_importer` is not, and must not be** — see `01-scene-spike.md`.
- The asset pipeline is a **build hook**, `flutter_module/hook/build.dart`, installed by `dart run flutter_scene:init`. Sources are `.glb` under `assets/models/`, loaded **by source path**: `loadScene('assets/models/tree_palm.glb')`. The hook converts them to `.fsceneb` under `flutter_scene_generated/`, which is listed under `flutter: assets:` and is gitignored by design. Commit the `.glb`.
- Flutter GPU is enabled via the host's Info.plist key `FLTEnableFlutterGPU` (capital `GPU` — see `01-scene-spike.md` for the casing trap). **This repo has `Info-Debug.plist` and `Info-Release.plist`, not `Info.plist`; the key is in both.**
- `flutter_module/lib/shader_screen.dart` is the reference for fragment-shader work.
- `flutter_scene` ships agent skills. They are installed at `flutter_module/.claude/skills/` (`fvm dart run flutter_scene:skills`); `references/traps.md` in `flutter_scene-idioms` is the highest-value page in this repo for anyone touching 3D. `FLUTTER-3D-PLAYBOOK.md` covers what the skills don't.
- Custom materials are `.fmat` files under `flutter_module/assets/materials/`, compiled by the same build hook (`buildMaterials`) and loaded by source path: `loadFmatMaterial('assets/materials/ocean.fmat')`. They must follow the portability rules in the playbook (§4) or they break on Android GLES.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/assets/models/*.glb` | **new** — CC0 sources, committed, preprocessed (see Findings) |
| `flutter_module/assets/models/CREDITS.txt` | **new** — attribution + the preprocessing note |
| `flutter_module/lib/tabs/scene/scene_app.dart` | **new** — widget for route `/scene` |
| `flutter_module/lib/tabs/scene/island_scene.dart` | **new** — scene graph, camera rig, day/night |
| `flutter_module/lib/tabs/scene/tap_to_move.dart` | **new** — unprojection + movement (pure maths, no GPU) |
| `flutter_module/lib/tabs/scene/particles.dart` | **new** — 2D overlay layer |
| `flutter_module/test/tabs/scene/*` | **new** — unit tests for the two pure modules |
| `flutter_module/lib/main.dart` | wire `/scene` (one line in the existing switch) |
| `flutter_module/lib/tabs/scene/island_components.dart` | per-node `Component`s (campfire flicker, NPC, flock, buoys, CPU wave grid, marker) |
| `flutter_module/lib/tabs/scene/super_ultra/*.dart` | **Super Ultra**: `super_ultra_rig.dart` (build, mount, per-frame parameters), `island_terrain.dart`, `ocean_waves.dart`, `sky_path.dart`, `procedural_textures.dart`, `super_ultra_fire.dart` |
| `flutter_module/assets/materials/*.fmat` | **Super Ultra** materials: `island_sky`, `ocean`, `island_ground`, `grass`, `ember_bed`, `heat_haze` |
| `flutter_module/test/tabs/scene/super_ultra/*` | tests for the pure Super Ultra modules (wave packing vs CPU, terrain, moon path, textures) |

`pubspec.yaml` needs **no** change: neither `assets/models/` nor `assets/materials/` is listed, because only the hook's `flutter_scene_generated/` output ships.

## Implementation notes

### Assets

Low-poly diorama props plus a character. CC0 sources — this build uses Kenney's **Nature Kit 2.1** and **Blocky Characters 2.0**. Drop the `.glb` under `assets/models/` and load by source path; there is no import command any more.

**The Ultra flock is four real birds** (`assets/models/seagull.glb`). The model is Quaternius's CC0 rigged pigeon from *Ultimate Monsters*, with its palette repainted as a gull (see `assets/models/CREDITS.txt`). The flock used to be flat 3.2 m white boxes rocking side to side, which read as paper. Now:
- Each bird is a skinned model playing its `Fast_Flying` clip. Rates and start points differ per bird, so the wingbeats never sync.
- `SeagullFlockComponent` moves each bird's node along its `FlockBirdMotion` path.
- Birds bank into their turns: roll = `atan(speed × turn rate / g)`, eased.
- They flap faster climbing and slower descending.
- They are built once at load and mounted or unmounted with Ultra.

The cost is 4 draws of about 2k triangles each, with no shadows.

Adding it hit four traps:
1. **The build hook ignored the new `.glb`.** At runtime: `No generated .fsceneb for source "assets/models/seagull.glb"`. The fix is the same as for the first `.fmat`: delete `.dart_tool/hooks_runner/flutter_module` and rebuild.
2. **`buildScenes` imports `.glb`, not `.gltf`.** The pack ships `Pigeon.gltf` with a base64 buffer, so it was repacked into a GLB's binary chunk.
3. **`castsShadows` is not inherited.** Set it on every node of a loaded model, not just the wrapper.
4. **vector_math's `Quaternion.rotated` turns the opposite way from `Matrix4.compose`,** and `Matrix4.compose` is how the engine applies `node.rotation`. A test that checks orientation with `rotated` fails on correct code. Check through a matrix.

**Choose assets that read from the back of a room.** Strong silhouettes, flat saturated colours, chunky forms.

**The island landmass itself is procedural**, not an asset: a `CylinderGeometry` grass cap over a `CylinderGeometry` dirt cone, with a `DiscGeometry` sea. That is deliberate — the tap-to-move ground plane and the visible terrain are then the same constant by construction, so they cannot drift apart.

### Camera

`OrbitCameraController` + `CameraComponent` on a scene node, driven by the `CameraControls` widget. Clamped distance and polar angle so the presenter cannot get under the terrain, `panSpeed: 0` so the island stays framed, and `smoothing` for inertia. Do not hand-roll this — the built-in controller already does all of it.

### Tap to move — the centrepiece

This is what proves the tab is a live scene graph and not a video loop.

1. Take the tap position in local widget coordinates (`RenderBox.globalToLocal`).
2. `Camera.screenPointToRay(localPosition, viewSize)` — **the built-in API, which works in logical pixels.** Do not build the inverse view-projection by hand and do not apply a device-pixel-ratio factor; that is the classic source of the edge-growing error.
3. Intersect the ray with the ground plane `y = 0`.
4. Clamp the target to the island radius so the character cannot walk into the sea.
5. Ease the character node's transform toward the target, turning it toward the direction of travel.
6. Drop an expanding ring marker at the tap point that fades out.

### Day → night

**Real directional lighting**, per `01-scene-spike.md`'s Findings: a `DirectionalLight` node aimed by `DayNightCycleComponent`, with the slider bound straight to `timeOfDay`, plus a dim moon light. See the Findings below for why this is *not* `Scene.sunLight`/`SunLight`, and why the moon is needed.

**Current state of the sky, which differs from the original design.** The design was a `PhysicalSkySource` shown as the `Skybox` and baked into the lighting through `SkyEnvironment`. In practice, Normal and Ultra draw **no sky** and are lit by the engine's **default studio environment**. The look settings were silently replacing the sky with null (Super Ultra finding 1), and both modes were tuned against that result, so it is kept deliberately. Only Super Ultra has a sky.

The slider also swaps the particle layer: daytime dust motes → nighttime fireflies.

### Quality modes

`IslandQuality { normal, ultra, superUltra }`, each a superset of the one before, switched through `IslandScene.setQuality`.
- Super Ultra is **built lazily** the first time it's chosen (textures and meshes on isolates), showing Ultra meanwhile. A later choice supersedes one still building.
- Its content hangs off one root node that is mounted and unmounted as a unit.
- Leaving it restores everything it changed: the sky, the camera limits, framing and projection, the shadow settings, the sun latitude, the buoy spots, and the hidden Normal/Ultra landmass and sea.

### Particles

A **2D overlay** composited over the 3D render, not 3D particles. Far cheaper, and at projector distance it reads better anyway.

### Readout

Triangle count and mesh count on screen, next to the HUD's framerate. **Not labelled "draw calls"** — see the Findings for why that would overstate what is measured.

### Visibility

The engine stays alive when the host hides the tab. The render loop must stop, or tab 5 skews every other tab's HUD numbers — which is the demo's entire evidentiary basis.

## Gotchas

- Unprojection is easy to get subtly wrong. Verify by tapping the four **corners**, not just the centre. The classic symptom is an error that grows toward the screen edges.
- Do not raycast against the full mesh. A ground plane is enough and is orders of magnitude cheaper.
- If the model renders black, it is almost always the material, not the lighting.
- The engine stays alive when the tab is hidden. Stop the render loop when the route is not visible.
- **Read `flutter_scene-idioms/references/traps.md` before writing scene code.** In-place transform edits, non-uniform scale on a lit mesh, and FOV in degrees are all silent failures.
- **Every `EnvironmentSettings` literal must name its `skybox` and `skyEnvironment`.** Assigning one applies the whole look and sets any sky it leaves out to null (Super Ultra finding 1).
- **`.fmat` materials must be written for GLES**, not just Metal: no `#include <noise.glsl>`, no reversed `smoothstep`, no `pow` on a negative base. The simulator will not catch these; the Android emulator does. See the playbook §4.
- **`OrbitCameraController.polar` is elevation above the horizon**, not the angle from vertical. The Normal camera (0.62 rad, looking down) never shows the sky, which is why a missing sky went unnoticed.

## Acceptance criteria

- [ ] Island renders on a physical device in release mode. — **NOT VERIFIED: no device attached. Verified on the iOS simulator in debug.**
- [x] Camera orbits and zooms smoothly, clamped sensibly. — implemented via `OrbitCameraController`; **clamping and smoothing not exercised by hand** (no way to drag a simulator programmatically).
- [x] Tapping anywhere on the island moves the character there, facing the direction of travel, with a visible tap marker. — verified on the simulator through the auto-demo probe, including off-centre positions.
- [x] Day→night slider works smoothly end to end and swaps the particle layer. — verified by sweeping `timeOfDay` and screenshotting day, dusk and night.
- [x] Triangle count and draw calls are displayed. — displayed, but the second number is labelled **meshes**, not draw calls; the criterion as written asked for a number `flutter_scene` does not expose (see Findings).
- [ ] Full refresh rate held during simultaneous orbit + character movement + day/night sweep. — **NOT VERIFIED: needs release-on-device. Debug simulator timings are not evidence.**
- [x] Render loop stops when the tab is not visible. — **verified on the simulator** by backgrounding the app: one `render loop stopped` log line, one `render loop resumed`, and the scene returns intact. **The add-to-app tab-switch path specifically is still unverified** (see Findings).
- [x] Super Ultra renders correctly at every time of day: sky with sun and moon, clear water with seabed and reflection, grass, fire. — verified by `SCENE_TOUR` screenshots on the iOS simulator (Metal) **and** the Android emulator (OpenGL ES).
- [x] Switching Normal ↔ Ultra ↔ Super Ultra in any order restores each mode's look, camera and content. — verified by `SCENE_TOUR_MODES` on the simulator.
- [x] Normal and Ultra look exactly as before Super Ultra was added. — verified by screenshot on the simulator and, for Normal, the emulator.
- [x] Lightning strikes while it rains, with the `⚡ Storm` toggle turning it off without stopping the rain. — bolt and envelope unit-tested (`lightning_test.dart`); strikes screenshotted at day, dusk and night on the simulator (with `SCENE_LIGHTNING_HOLD`) and on the emulator.
- [x] Rain toggles on and off in Super Ultra; drops collide with the ground, sea, props and characters and splash where they land; off leaves nothing mounted. — collision unit-tested (`rain_collision_test.dart`); visuals verified by screenshot on the simulator and the emulator; unmount confirmed by the `super ultra: rain off, unmounted` log.
- [ ] Super Ultra frame rate recorded on the iPhone and the Android phone (profile mode, UI and raster time), **with rain on and off**. — **NOT VERIFIED: no device.**

## How to verify

Physical device, release mode. This one gets its own careful pass — it is the finale and it is the least proven technology in the stack.

1. Tap all four corners of the island and the centre. The character must arrive where you tapped, every time.
2. Orbit and pinch **while** the character is walking. No hitching.
3. Sweep day→night mid-walk, mid-orbit. Watch the HUD across the whole sweep.
4. Tab away to tab 1 and confirm the HUD's numbers return to tab-1 baseline — if they do not, the scene is still rendering in the background.
5. Leave the tab open for five minutes and watch memory for drift.
6. Run the full sequence twice more. The finale must not be a coin flip on stage.

### Iterating without a device

The simulator runs Impeller on Metal and Flutter GPU works there (`01-scene-spike.md`). Use it for everything except measurement:

```bash
cd flutter_module
fvm flutter run --route=/scene -d <simulator-udid> --enable-flutter-gpu \
  --dart-define=SCENE_AUTO_DEMO=true
```

**Never `flutter run -t <file>`** — it rewrites `FLUTTER_TARGET` and the host app then silently builds the wrong entrypoint (`01-scene-spike.md`). `--route` does not touch it. After any run:

```bash
grep FLUTTER_TARGET flutter_module/.ios/Flutter/Generated.xcconfig   # must be lib/main.dart
```

`SCENE_AUTO_DEMO` is a debug-only affordance in `scene_app.dart`: a timer fires synthetic taps at five screen fractions (centre plus four off-centre points), sweeps the clock 2.5 hours per step, and overlays two markers — a red ring at the tap position and a cyan dot at the picked ground point projected back to screen. **When they coincide, the unprojection is right.** That is the only way to exercise tap-to-move without a finger, since `osascript` cannot reach the simulator without assistive access.

---

## Findings

> Recorded 2026-09-05, against `flutter_scene 0.23.0` / Flutter 3.47.2, on an iPhone 17 Pro simulator in debug. **No physical device was available, so nothing here is evidence for a performance claim.**

### What this doc got wrong

1. **`.model` files and `flutter_scene_importer:import` do not exist any more.** Already recorded in `01-scene-spike.md`; the table and the import command above have been rewritten. There is no manual import step at all.
2. **"`flutter_scene`'s material and lighting model is minimal"** — it is not, by a wide margin. Lights, cascaded shadows, IBL, a `DayNightCycleComponent`, orbit/fly/follow camera controllers, raycasting, a particle system and a full post stack all ship. The right instinct with this package is to check whether it already exists before writing it.
3. **"Build a ray: unproject through the camera's inverse view-projection matrix at near and far planes"** — do not. `Camera.screenPointToRay(Offset, Size)` is built in, works in the view's logical pixels, and has a `worldToScreen` inverse that makes the round trip testable. Every hand-rolled version of this is a chance to reintroduce the device-pixel-ratio bug the doc warns about two paragraphs later.

### Kenney's `.glb` files do not load as shipped — and the error does not say why

`loadScene` on a stock Nature Kit model throws:

```
Exception: Child already has a parent
#0  Node.add (package:flutter_scene/src/node.dart:1187)
#1  _realizeWith (package:flutter_scene/src/fscene/realize/realize.dart:181)
```

**Cause.** Every Nature Kit export carries a node named `tmpParent` that is *not* referenced by any glTF scene but *does* list the scene's root node as its child:

```json
"scenes": [{"nodes": [1]}],
"nodes": [
  {"name": "tmpParent", "children": [1]},
  {"name": "tree_palmTall", "mesh": 0}
]
```

A glTF reader that walks scenes ignores node 0. `flutter_scene`'s offline realizer instantiates **every** node in the document, wires children first, and only then attaches the document roots — so `tmpParent` claims node 1, and the root attach fails. The message names neither the file nor the node.

**Fix.** Prune unreachable nodes from the `.glb` before committing it, remapping indices. Committed sources here are already pruned; the script:

```python
# python3 prune.py *.glb — drops glTF nodes not reachable from any scene
import struct, json, sys
def read_glb(p):
    d = open(p,'rb').read(); off = 12; out = []
    while off < len(d):
        ln, ty = struct.unpack('<II', d[off:off+8])
        out.append([ty, d[off+8:off+8+ln]]); off += 8 + ln
    return out
def write_glb(p, chunks):
    body = b''
    for ty, data in chunks:
        pad = (4 - len(data) % 4) % 4
        data += (b' ' if ty == 0x4E4F534A else b'\x00') * pad
        body += struct.pack('<II', len(data), ty) + data
    open(p,'wb').write(b'glTF' + struct.pack('<II', 2, 12+len(body)) + body)
for path in sys.argv[1:]:
    chunks = read_glb(path); j = json.loads(chunks[0][1])
    nodes = j.get('nodes', []); reach = set()
    def visit(i):
        if i in reach: return
        reach.add(i)
        for c in nodes[i].get('children', []): visit(c)
    for sc in j.get('scenes', []):
        for n in sc.get('nodes', []): visit(n)
    if len(reach) == len(nodes): continue
    keep = [i for i in range(len(nodes)) if i in reach]
    remap = {o: n for n, o in enumerate(keep)}
    j['nodes'] = [dict(nodes[i], **({'children': [remap[c] for c in nodes[i]['children']]}
                                    if 'children' in nodes[i] else {})) for i in keep]
    for sc in j.get('scenes', []): sc['nodes'] = [remap[n] for n in sc['nodes']]
    for sk in j.get('skins', []):
        sk['joints'] = [remap[x] for x in sk.get('joints', [])]
        if 'skeleton' in sk: sk['skeleton'] = remap[sk['skeleton']]
    for an in j.get('animations', []):
        for ch in an.get('channels', []):
            if 'node' in ch.get('target', {}): ch['target']['node'] = remap[ch['target']['node']]
    chunks[0][1] = json.dumps(j, separators=(',',':')).encode()
    write_glb(path, chunks)
```

**A second, unfixable variant of the same failure.** `tree_palmDetailedTall.glb` and `tree_palmDetailedShort.glb` contain two sibling nodes both named `leafs`. Same exception, same stack. Those two models are simply avoided; `tree_palmTall.glb` is used instead.

**Screening rule for any new `.glb`:** before adding one, check that every node is reachable from a scene and that no two nodes share a name. Both are one-liners over the JSON chunk, and both otherwise cost an hour of misdirected debugging.

### External textures silently fail, then the model renders untextured

Kenney's Blocky Characters `.glb` references its atlas by URI:

```json
"images": [{"uri": "Textures/texture-a.png", "name": "texture-a"}]
```

At runtime this prints `fscene: failed to load texture ...: Unable to load asset: "Textures/texture-a.png"` and the character draws with no albedo. The build hook does not resolve or bundle the sidecar. The fix is to embed the PNG into the GLB's binary chunk as a `bufferView`-backed image — `assets/models/character.glb` here is the embedded version, and the model is then self-contained.

### Kenney materials need two rewrites after import, both silent

1. **`metallicFactor: 1, roughnessFactor: 1`.** Kenney's exports declare every material fully metallic. Under PBR a metal has no diffuse term, so the whole island reads as dark plastic lit only by reflections. Walk the loaded node tree and set `metallicFactor = 0`.
2. **`KHR_materials_unlit`.** The character declares it, and `flutter_scene` honours it — importing as an `UnlitMaterial`. An unlit material is not touched by the sun, so the character would stay at full daylight brightness at midnight, in the one tab whose point is the lighting. Replace it with a `PhysicallyBasedMaterial` carrying the same `baseColorTexture` and `baseColorFactor`.

Neither produces a warning. Both are handled in `_relightImportedMaterials`.

### Day/night: `DayNightCycleComponent`, **not** `SunLight`

`01-scene-spike.md` suggests `scene.sunLight = SunLight(sky)` and separately recommends `DayNightCycleComponent`. **Using both double-lights the scene**, and of the two only one actually produces a sunset:

- `SunLight.resolve()` takes its colour from `source.sunLightColor`. For `PhysicalSkySource` in 0.23.0 that getter is `Vector3(1.0, 0.98, 0.95)` — **a constant**, despite the doc comment above it claiming atmospheric transmittance reddens it near the horizon. A `SunLight` therefore never reddens at sunset.
- `DayNightCycleComponent.evaluateLighting()` ramps the sun from `(1.0, 0.95, 0.88)` at noon to `(1.0, 0.55, 0.20)` at the horizon, on the **same 0..3 intensity scale** the sky uses (`PhysicalSkySource.sunLightIntensity == 3.0 * energy`, `DirectionalLight.intensity` defaults to 3.0). The units line up, so it can be swapped in directly.

So: `PhysicalSkySource` → `Skybox` + `SkyEnvironment`, one `Node` carrying a `DirectionalLightComponent`, and `DayNightCycleComponent(sunLightNode: …, skySource: …, targetScene: …)` driving all of it from `timeOfDay`. `Scene.sunLight` is left null.

> **Superseded (2026-09-24).** The skybox and `SkyEnvironment` described here were later removed by accident: the look settings added for Ultra replaced them with null. Normal and Ultra have since been lit by the default studio environment, and keep that deliberately. The sun and moon lights and `DayNightCycleComponent` still work as described. See Super Ultra finding 1.

**`applyLightingToTarget: false` and apply it yourself.** The component still aims the sun node and writes `skySource.sunDirection`; turning off the application step lets you put a floor under `environmentIntensity` and add a moon (below) without fighting it every frame. Note the component's `update` runs from `Scene.render`'s implicit tick, which happens **after** `SceneView.onTick`, so anything you write to the light from `onTick` is overwritten unless you turn this off.

**Golden hour is present but subtle, and that is a design choice you may want to reverse.** `evaluateLighting()` scales the sun's *intensity* by the same `smoothT` that drives its *colour*, so at the horizon the light is simultaneously reddest and dimmest and the warm cast barely lands on the terrain. Screenshotted at 17:30 the shadows rake right across the island and the sky darkens convincingly, but there is no dramatic orange. If the presenter wants a stronger sunset beat, hold the intensity up near the horizon while keeping the colour ramp — that is a few lines in `_applyLighting`, not a change to the component.

**The night needs its own light.** With the sun below the horizon `PhysicalSkySource` renders black, so the `SkyEnvironment` bakes a black environment and `environmentIntensity` has nothing to scale — the island goes to literal black, screenshot-confirmed. A dim, cold, shadowless `DirectionalLight` faded in on `nightBlend` is what makes the night half of the slider a scene rather than a black rectangle. It costs one more light and no extra shadow pass. *(Still true, and it matters more in Super Ultra, where a real sky really does go black; there the moon also takes over the shadow-casting light.)*

**`SkyEnvironment` refresh policy matters.** The default is `manual`, which bakes once — so the sky visibly moves while the lighting stays stuck at the initial time of day. `SkyEnvironmentRefresh.interval` at 200 ms with `faceResolution: 64, equirectWidth: 256` keeps the IBL following the slider for a fraction of a frame's work. `everyFrame` is a real per-frame pass and is not worth it here.

> **Superseded.** `interval` kept a bake in flight on an idle clock and showed up as raster jank on device. The code uses `manual` and calls `invalidate()` when the slider moves; Super Ultra does the same.

### The bug that looked like a rendering failure and was a layout one

The first working build greyed out the entire scene behind a translucent rounded rectangle, with the day/night slider floating at the vertical centre of the screen. It reads as a compositing or post-processing bug. It is neither.

**Flutter's `Slider` expands to fill any bounded height it is given.** Inside `Align(alignment: bottomCenter) → Padding → DecoratedBox → Row → Expanded(Slider)`, the `Align` loosens the constraints but `maxHeight` is still the whole screen, so the Slider took all of it, the Row and the `DecoratedBox` grew with it, and the panel's `Colors.black.withValues(alpha: 0.42)` background covered the safe area. The identical wrapper around the stats readout was fine because its child is a `Column(mainAxisSize: min)` with no Slider in it.

Fix: `SizedBox(height: 52)` around the Row. Worth knowing because the symptom points at the 3D and the cause is 200 lines away in the HUD.

### Colour: the tone curve eats a pastel palette

The first pass looked washed out — everything mint and beige. Two compounding causes, both worth naming:

- **glTF `baseColorFactor` is linear.** A hand-authored `0.35, 0.72, 0.32` is a *pale* green once encoded, not a grass green. The terrain colours here are deliberately low linear values (`0.11, 0.40, 0.13`).
- **Default exposure pushes this palette into the ACES shoulder**, which desaturates as it rolls off. `exposure: 0.8` with `saturation: 1.4` in the `EnvironmentSettings` recovers the graphic, projector-legible look the doc asks for. The `stylized` preset in the `flutter_scene-looks` skill is the right starting point; its default `exposure: 1.0` is not.

### Stopping the render loop — and the two bugs found doing it

**Use `TickerMode`, not `SceneView(autoTick:)`.** Toggling `autoTick` looks like the obvious switch and it is a trap. `_SceneViewState` is a `SingleTickerProviderStateMixin`, and on an `autoTick` change it disposes its ticker and calls `createTicker` again — but `SingleTickerProviderStateMixin` never releases its one ticker slot, even on dispose. So the *first time the tab comes back*, the whole scene is replaced by a red error screen:

```
_SceneViewState is a SingleTickerProviderStateMixin but multiple tickers were created.
```

Screenshot-confirmed: the tab went away fine and came back broken. That is the exact shape of failure that survives development and detonates on stage, because nobody switches away and back while iterating. Wrapping the view in `TickerMode(enabled: …)` mutes the ticker `SceneView` already has, needs no change to the package, and keeps the view (and its GPU resources) alive so returning to the tab costs nothing.

With the ticker muted there is no per-frame render, and the app's own `onTick` stops too — which also freezes the particle layer and the walk. The state is retained, so the tab still "stays where you left it" when it comes back.

**And check you only have one screen.** `onGenerateRoute` alone is not enough to serve `defaultRouteName == '/scene'`. Navigator's default initial-route handling splits `/scene` into `['/', '/scene']` and pushes **both** when both resolve — so the tab mounts two `IslandSceneScreen`s, two `Scene`s and two render loops, one of them invisible underneath and still costing GPU. On the one tab whose purpose is an honest performance number, that is the worst available bug.

It was caught only because the lifecycle log line printed **twice**:

```
flutter: island scene: render loop stopped (AppLifecycleState.hidden)
flutter: island scene: render loop stopped (AppLifecycleState.hidden)
```

`onGenerateInitialRoutes` returning exactly one route fixes it, and the log then prints one line. Any future tab that answers a non-`/` initial route with `onGenerateRoute` has the same hazard; `game_app.dart` and the glass tab use a bare `home:` and fall back to `/`, so they are single-instance already — but they log "Could not navigate to initial route" while doing it, and that warning is the tell.

The signal driving it is `didChangeAppLifecycleState`, and it **fails open** — only `paused`, `hidden` and `detached` stop rendering, so an embedder that never reports `resumed` still draws. This was chosen because it needs no host-side change.

**What is verified:** on the simulator, backgrounding the app (launching Settings over it) logs `render loop stopped (AppLifecycleState.hidden)` exactly once, foregrounding it logs `render loop resumed (AppLifecycleState.inactive)` exactly once, and the scene comes back rendering correctly.
**What is NOT verified:** that iOS actually delivers a lifecycle event when a `FlutterViewController` inside a `UITabBarController` is switched away from. The iOS embedder is expected to send `AppLifecycleState.paused` from `viewDidDisappear:`, which is what makes this work without touching `cool-ios/`, **but that was not confirmed against a build of the host app.** `08-polish.md` must check it: switch to tab 1 and watch whether tab 5's Dart frame telemetry stops arriving on `com.theamorn.hybrid/telemetry`. If it does not, the fallback is a `MethodChannel` message from `FlutterTabViewController.viewWillAppear/viewWillDisappear`, which is a small change to `02-ios-host.md`'s file.

### Draw calls: what the number actually counts

`flutter_scene` exposes no draw-call counter, so **this acceptance criterion cannot be met as written** and the readout does not pretend otherwise: it says `36 meshes`.

What it counts is mesh primitives in the visible scene graph — one draw each in the colour pass. It does **not** include the shadow pass, the skybox, the IBL bake or the post stack, so the real GPU draw count is higher. Labelling it "36 draw calls" on a slide would be a number that does not survive being questioned, on the one tab whose job is to be questioned. The field is named `meshCount` in code so it cannot quietly drift back.

Triangles are exact: `Geometry.extractMeshData().triangleCount`, summed per instance and cached per geometry, counted once at build time (the scene is static in count). `Geometry.cpuMeshData` would give the same numbers without the copy, but it is `@internal` and using it trips `invalid_use_of_internal_member`.

### Testing 3D without a GPU

`flutter test` can import `package:flutter_scene/scene.dart` and use `PerspectiveCamera` — the camera is pure `vector_math`, and nothing touches `flutter_gpu` until a `Scene` or a `Geometry` is constructed. That makes the highest-risk part of this tab unit-testable:

`test/tabs/scene/tap_to_move_test.dart` round-trips `screenPointToRay` → ground-plane intersection → `worldToScreen` at the **corners** of three aspect ratios and asserts agreement to a twentieth of a pixel. A device-pixel-ratio mistake shows up there as an error of tens to hundreds of pixels, growing toward the edges — exactly the failure this doc warns about, caught in 2 seconds instead of on stage.

Tolerances must be float32-sized, not float64-sized: `vector_math` stores `Vector3` in a `Float32List`, so `closeTo(3, 1e-9)` fails on an exact-looking clamp result.

### Left undone

- **Everything that needs a phone.** No frame timings, no memory numbers, no release build of tab 5, no ProMotion check. Nothing in this file supports a performance claim.
- **A true golden-hour look.** See above — the ramp is there, the drama is not.
- **Orbit and pinch were never driven by a finger.** The controller is the package's own and is configured with clamps, but the feel — inertia, the polar clamp, whether 26 units is too far — has not been judged by a human.
- **The spike artifacts are gone** (`lib/spike_scene.dart`, `lib/spike_main.dart`, `assets/models/spike_box.glb`), per `01-scene-spike.md`. The `/spike` branch in `main.dart` and the throwaway blocks in `cool-ios` belong to `02-ios-host.md` and were already removed there.
- **No sound, no LODs.** Normal is about 3,600 triangles across 44 meshes and Ultra about 13,600; neither needs LODs. Super Ultra is about 133,000 triangles (terrain 51k, sea 44k, grass about 25k instanced); LODs for the terrain and sea are the obvious next step if it misses budget on device.

---

## Super Ultra

> Added 2026-09-24, against `flutter_scene 0.23.0` / Flutter 3.47.2. Verified on the iPhone 17 Pro **simulator** and an Android **emulator** (OpenGL ES), both in debug; see "Not verified" below.

A third mode for the island (`💎 Super`), for hardware with headroom. Android barely holds 60 fps in Ultra, while the iPhone has room to spare. It keeps everything Ultra has and adds:

| Area | What | Where |
|---|---|---|
| Island | A heightfield replaces the cylinder cap and upside-down cone. The walkable top is exactly `y = 0` out to r = 10, so tap-to-move is unchanged. Beyond that: a grass lip, beaches or rocky headlands, a sandy shelf, and a reef drop to about -15 m. | `super_ultra/island_terrain.dart` |
| Ground | One lit `.fmat`. It splats grass, dirt, sand, wet sand, rock and seabed from height, slope and vertex masks, with relief from baked tileable normal maps and caustics under water. | `assets/materials/island_ground.fmat` |
| Grass | About 2,800 instanced tufts. They sway with quadratic-cantilever wind, part around the player, and glow when backlit. | `assets/materials/grass.fmat` |
| Water | GPU Gerstner waves, refraction of the seabed through `scene_color`, Beer-Lambert tint from `scene_depth`, a `PlanarReflectorComponent` mirror, and surf and crest foam. Buoys and balls sample the same waves on the CPU with the shader's clock. | `assets/materials/ocean.fmat`, `super_ultra/ocean_waves.dart` |
| Sky | A port of the engine's physical sky, plus a visible sun with a corona, a phase-lit moon with craters, stars and a Milky Way. The sun follows a high-latitude arc (≈22° at noon) and the moon a low arc, so both are in frame. At night the moon takes over the shadow-casting light. | `assets/materials/island_sky.fmat`, `super_ultra/sky_path.dart` |
| Fire | Flipbook flame tongues, a core glow, velocity-stretched embers, spark bursts, flipbook smoke, a glowing coal bed and heat haze. | `super_ultra/super_ultra_fire.dart`, `ember_bed.fmat`, `heat_haze.fmat` |
| Rain (toggle) | `🌧 Rain` button, shown only in Super Ultra. About 2,300 drops/s fall as velocity-stretched streaks and **collide** with the terrain, the sea, every prop, the player, the NPC, balls and crates. Each hit splashes (droplets plus an impact flash), water hits sometimes leave a ring, and drops on the campfire hiss up as steam. The GPU half: raindrop rings across the whole sea, wet dark ground with ringed puddles, wet grass, an overcast sky that hides the sun, moon and stars, a dimmer sun, and fog. It fades in and out over 2.5 s. Off unmounts every rain node once the last drop lands, so it then costs nothing. | `super_ultra/super_ultra_rain.dart`, `super_ultra/rain_collision.dart`, rain terms in the four materials |
| Lightning (toggle) | `⚡ Storm` button, shown while it rains; on by default. In a full downpour, a strike every 4.5–12.5 s, three quarters of them in frame. Each strike is a branching HDR bolt (it blooms and the sea mirrors it), a cold shadowless flash light, the clouds lighting up around it, an ambient pulse, and rain streaks catching the light. There are two or three pulses within half a second, never more than three flashes a second. The flash lights the scene fully at night and only about a third as much by day. | `super_ultra/lightning.dart`, the `flash` term in `island_sky.fmat` |
| Effects menu | `🎛 Effects` button, shown only in Super Ultra. A half-height panel opens with two image-quality pickers, anti-aliasing (SMAA, MSAA, TAA, FXAA, off) and render scale (100%, 85%, 75%), then lists every other Super Ultra feature with its own switch, grouped: lighting & shadows, post effects, scene content. A live readout at the top shows UI time, raster time and fps over the last 2 s. It is for finding what a feature costs on a real device, not a quality preset: switching Grass off removes the grass. `Full sea` off swaps in a simple opaque sea instead of removing the water, and greys out `Sea reflection`, which only the full sea has. Choices survive mode switches until `Reset`. | `super_ultra/super_ultra_effects.dart`, `IslandScene.setEffect`, `setAntiAliasing`, `setRenderScale` |
| Look | One coherent `EnvironmentSettings`: GTAO with bent normals, god rays, fog with sun in-scatter, bloom with lens flare, light grain. SSR is off because the planar mirror replaces it. Shadows use 2048 px, 2 cascades and PCSS. | `IslandScene._applySuperUltraLook` |

The content is built the first time the mode is chosen: textures and meshes on isolates, materials from the build hook. That takes about 4 s cold and 0.3–0.5 s warm on the simulator in debug. The scene shows Ultra meanwhile.

### Findings

The engine-level lessons here are also generalised, with recipes and a symptom table, in [`FLUTTER-3D-PLAYBOOK.md`](FLUTTER-3D-PLAYBOOK.md). The numbered findings below are the evidence trail.

**1. There was no sky in any mode, and nothing said so.** Assigning `scene.environmentSettings = EnvironmentSettings(...)` applies the *whole* look through `applyLookTo`, including `scene.skybox`, `scene.skyEnvironment` and `scene.environment`. A literal that doesn't name a sky sets all three to null. `_buildEnvironment()` set a physical sky and then called `_applyEnvironmentSettings()`, which removed it on the next line. So Normal and Ultra have been drawing no sky, and lighting with the engine's **default studio environment** rather than the sky, which is why the sun was never visible.

Evidence: the sky region read exactly the Scaffold colour `(7, 19, 31)` in every mode; a bare `Scene` with the same skybox drew it; `environment_settings.dart:489`. Each `EnvironmentSettings` literal now carries its mode's sky (`_activeSkybox`).

**Decision left open:** Normal and Ultra keep the look they were tuned against (no sky, studio lighting). Turning the physical sky on for them was tried: at `exposure: 0.8` the island washes out to pastel by day, and nights get darker. Re-grading the stage path is a separate call.

**2. A translucent `.fmat` with `depth_write: true` reads its own depth.** `TranslucentDepthPatchPass` patches depth-writing translucents into the pre-pass depth that `scene_depth` samples. So the water computed zero thickness everywhere, showed foam across the whole sea, and faded itself out. The water uses `depth_write: false`.

**3. GLSL `pow()` with a negative base is NaN, and one NaN in a sky takes out the frame.** `pow(dot(dir, n) / 0.2, 2.0)` in the Milky Way band left the sky transparent. Through the IBL bake it also blew every lit surface out to white. Square it by hand.

**4. Framed on a low sun, the physical sky model is a white sheet.** Its forward-scatter glow runs 4–50× the zenith radiance toward the sun (evaluated numerically for the exact parameters). The Super Ultra sky compresses daylight luminance above a knee at 1, multiplies the daylight sky (not the sun disk) by 0.5, and uses turbidity 3.

**5. Stars need pixel-sized falloff and a window inside their cell.** Sized in `1 - cos` units, a star wider than its hash cell is clipped square by the cell edge. The water's reflection then stretches those squares into streaks.

**6. Build hook cache.** The very first `.fmat` added under a new `assets/materials/` directory compiled a stale input set. Deleting `.dart_tool/hooks_runner/flutter_module` fixed it, and later edits recompiled normally. Compiled bundles are per backend (`metalIos`, `metalDesktop`, `openglEs`, `openglEs,vulkan`), 2–3.6 MB each. Everything in `flutter_scene_generated/` ships as assets.

**7. Caustic scale matters more than caustic strength.** Caustic cells of 0.7 m read as a coarse web of polygons from 30 m away. At about 0.3 m, and faded with view distance, they read as light.

**8. `#include <noise.glsl>` in a sky `.fmat` silently fails on GLES.** On the Android emulator (Impeller on OpenGL ES), the sky drew nothing: the sky pass was transparent, and the lighting baked from it turned the island white and yellow. Nothing appeared in logcat. A zero-parameter probe (paint the sky magenta if its parameters arrive as zeros) never showed, so the shader wasn't running at all. The stock `GradientSkySource` rendered fine. The library's large constant tables are the difference. The sky, ember bed and heat haze now use a small local hash noise, and Super Ultra renders on the emulator. The surface materials that never included it (ocean, ground, grass) were fine throughout.

**9. `smoothstep(edge0, edge1, x)` with `edge0 > edge1` is undefined in GLSL ES.** Metal happens to evaluate it as intended. Every falling edge is written as `1.0 - smoothstep(lo, hi, x)`.

**10. A `.fmat` that fails to compile does not fail the build.** The hook prints `building .fmat materials failed; keeping the previous shaders.` and the app runs with the **old** materials, so a broken edit looks like an edit with no effect. It happened here with a redefined variable (`wet`). Grep the build output for that line after every material change.

### Rain

**Collision can't use `Scene.raycast`.** It tests render triangles one by one (no per-mesh BVH), and it skips instanced meshes entirely, which covers the scattered props and the balls. So `rain_collision.dart` tests each drop against analytic proxies:
- a 0.5 m height grid of the terrain, sampled once on an isolate;
- the sea plane, wherever the ground is below it;
- ellipsoids, cylinders and cones sized from each model's real bounds (palm 1.36 m, pine 1.25 m, rocks and bushes 0.2–0.3 m);
- capsules and spheres for the player, NPC, balls and crates, refreshed every simulation step.

Drops above the tallest obstacle skip the tests entirely, which is most of their fall. The module kills a drop by setting its `age` to its `lifetime`; the particle system reaps it at the end of the step.

**Splashes are injected, not emitted.** The splash system has no spawner. A `ParticleModule` drains a queue of hit points and calls `storage.spawn()` itself, writing every column the system's own spawn path would.

**Density is a budget.** 2,300 drops/s over the 54 × 54 m rain box is about 0.8 drops/m²/s, so a character would be hit about once every eight seconds and its splashes never seen. 30% of the drops are therefore spawned in a 6 × 6 m box over the player and the NPC, upwind by the drift. They are still real drops that collide; only where they start changes.

**Splash rates were tuned down, on purpose.** A splash for every ground hit turned bare ground into what looked like snow. Ground splashes 12% of hits, water 20% (the ocean shader's rings carry the sea), and solid things get every hit, with the biggest splash so collisions read.

**Unlit effects need the light level.** Drops, splashes, steam and ripple rings are sprites and an unlit ring. Their tint follows the key light and ambient (`SuperUltraRain.setLight`), or they glow white at night.

### Lightning

**A strike is cheap.** The bolt is 1–5 `TubeGeometry` primitives over `PolylinePath`s from midpoint displacement: about 30 points for the main channel, with branches forking off its upper part. Set `stations` to the point count so the corners stay sharp.
- **Bolt:** one `UnlitMaterial` whose colour follows the flash in HDR (about 9–14), so bloom does the glow. Hide the node between pulses rather than dimming it to black; an opaque unlit tube dimmed to zero draws as a black line.
- **Flash light:** a separate shadowless `DirectionalLight` aimed from the strike. Its intensity changes don't touch the static shadow cache.
- **Clouds and ambient:** the clouds light up through a `flash` parameter on the sky shader, and the ambient pulse is `environmentIntensity`, because re-baking the sky lighting per flash would cost far more.
- **Placement:** strikes are aimed inside the camera's portrait field of view (about ±14°) at 45–85 m, never on the island.

**Flashing is a content-safety issue.** The envelope is two or three pulses within 0.5 s, and strikes are at least 4.5 s apart, which keeps it under three flashes a second. `⚡ Storm` removes the flashing without stopping the rain. On a projector in front of an audience, consider leaving it off.

**Daylight lightning barely registers.** A flash at full strength whited out a noon frame, so the scene lighting from a flash scales from 0.3 by day to 1.0 at night. The bolt stays bright either way.

### Performance pass

> 2026-09-24. The brief was to make it cheaper with nothing on screen changing. Measured in profile mode on the `hybrid_demo_shop` emulator (Super Ultra, rain and storm, 10:30), and on the iPhone 17 Pro simulator for the look. No device.

**Changes.** Each one leaves every pixel's formula the same:
- **The sea is out of its own mirror.** `oceanNode.layers = kSuperUltraNoReflectLayer`. The planar capture clips at the flat sea plane, but the shader lifts wave crests above it. So the whole sea was being redrawn into its own reflection every frame, with the scene colour and depth copies its refraction needs, only to leave stray crest patches.
- **Ground (`island_ground.fmat`):** grass normals are fetched only where there is grass or dirt, sand ripples only on sand, the rock normal only on rock. The fetches use `textureGrad` with derivatives taken before the branches, so mip selection is unchanged. That's 3–5 fetches per pixel instead of 7.
- **Ocean (`ocean.fmat`):** the two foam fetches run only where there is surf or a crest, and the rain rings only where their distance fade is non-zero.
- **Sky (`island_sky.fmat`):** the Milky Way skips its two fbm evaluations beyond 3.2 band-widths, where it is below 4e-5 of its peak.
- **Rain collision:** a 1 m grid broadphase over the props, with shapes kept in order so the first hit is the same. That's 236 → 40 ns per test on the host (66 shapes, 400k drops, identical hits).

**Evidence:**
- **Look:** before/after screenshot tours on the simulator, dry and raining, at 10:30, 17:24, 18:24, 21:30, 01:30 and 06:24. Side by side they are the same apart from animation (characters, foam, fireflies, rain).
  - Mean per-pixel difference in the sky and HUD bands: 0.2–3 of 255.
  - Mean difference in the sea bands: up to about 10, from waves moving between the two captures.
- **Android:** the emulator renders every changed material. The GLES bundle is `#version 300 es`, and the build never printed `keeping the previous shaders`.
- **CPU:** `RainCollider.test` went from 3.6–7.5% to 1.5% of UI-isolate samples. `rain_collision_test` checks the grid against a per-prop brute-force reference.
- **Frame rate: no measurable change on the emulator.** Alternating fresh runs:

  | Build | fps per run |
  |---|---|
  | After | 26.9, 32.8, 34.1 |
  | Before | 22.5, 39.4 |

  Three more runs exited at launch. The spread between runs of the same APK is larger than anything these changes can do. The shader and capture savings are GPU work, and the emulator is UI-bound. Quantifying them needs the phones.

**Where the time goes.** UI-isolate samples on the emulator:
- `Scene.render` takes about 80%:
  - main scene pass about 35%
  - planar capture about 16%
  - bloom and lens flare about 13%
  - shadows about 4%
- `Scene._tick` takes 10–15%: rain, fire turbulence and the other particles.
- Widgets take about 3%.

What is left to cut is visible. In rough order of payoff:
- a lower planar `resolutionScale`, or keeping particles out of the capture
- fewer bloom mips, or no lens flare
- god-ray steps
- rain `kFullRate`
- `renderScale`

**Emulator drift, not a leak.** During the baseline, UI time climbed from about 5 ms to over 20 ms across ten minutes. The Dart heap stayed flat, with identical instance counts a minute apart, and the native heap moved between 120 and 140 MB. The emulator has 2 GB of RAM and sat 650–700 MB into swap, and the host is a MacBook Air. Treat emulator frame rates as noise unless runs alternate. See the playbook, §7.

### Anti-aliasing and render scale

> 2026-09-24. From the effects menu on the iPhone: switching MSAA on, and switching full resolution on, each added a lot of raster time.

**Why MSAA was expensive here.** `flutter_scene` calls MSAA cheap on mobile, and it is while the scene pass stays in tile memory. The sea's material reads `scene_color` and `scene_depth`, so the engine splits the scene pass at the first translucent that reads the screen (`render/scene_pass.dart` in 0.23.0). With MSAA on, that split:
- stores the 4× depth buffer to memory at the end of the opaque pass and loads it back for the translucent pass
- copies the resolved colour full-screen back into the MSAA target, then resolves a second time
- probably happens twice: the heat haze also reads `scene_color` and overlaps the sea on screen, so it should get its own batch (not confirmed)

**Why full resolution was expensive.** 100% draws 1.38× the pixels of 85%, and nearly every Super Ultra pass pays per pixel: GTAO, the god-ray march, PCSS, contact shadows, fog, bloom and the sea's scene copies. With MSAA on, the depth round trip grows by the same factor.

**Change.** Super Ultra defaults to SMAA at 85%. SMAA runs on the resolved image, so the split pass goes back to a 1× depth buffer. The menu's MSAA and Full resolution switches became the two pickers.

**Not measured yet:** device numbers for SMAA at 85% against MSAA at 100% (`SCENE_ABLATION` has both), and whether TAA smears the waves or the particles.

### Simple sea

> 2026-09-24. From the effects menu on the iPhone, UI time: the full sea took it from 10 to 14 ms, and the full sea with its reflection from 10 to 20 ms.

`Full sea` off used to remove the water. It now swaps in `ocean_simple.fmat` on its own mesh (`SuperUltraRig.simpleSeaNode`): the same waves, ripples and foam, opaque, with no scene colour, scene depth or planar reflection. See the playbook's "Simple sea" for how it gets its colour without the depth.

**Checked on the simulator:** it builds and renders, the horizon fades into the fog with no edge, and the full sea is unchanged when switched back. By eye, the shallows are milkier than the full sea's clear water, the far water is darker navy where the full sea is silver, and it has no raindrop rings.

**Not measured yet:** its cost on the phone. The ablation's `Full sea off` step now measures it.

### Debug affordances (never on in a shipped build)

`--dart-define=SCENE_QUALITY=superUltra|ultra|normal` picks the mode after load. `SCENE_TOUR=true` steps the clock through 10:30, 17:24, 18:24, 21:30, 01:30 and 06:24, re-aiming the Super Ultra camera at the sun or moon at each stop and logging `island tour: …`. `SCENE_TOUR_MODES=true` also cycles Normal → Ultra → Super → Ultra → Normal → Super to exercise every transition. `SCENE_RAIN=true` switches the rain on after load. `SCENE_LIGHTNING_HOLD=2` holds each strike at its peak for two seconds, so a screenshot taken after the `island lightning: strike` log line catches it. `SCENE_ABLATION=true` (with `SCENE_QUALITY=superUltra`, profile build) switches each effects-menu entry off in turn, tries each non-default anti-aliasing and render-scale pick, then runs `MSAA at 100% (old default)`, `all post off` and `+ rain & storm`. Each step settles 4 s and is measured 5 s, over 3 rounds, and the run ends with a median table of UI and raster deltas. It takes about 10 minutes. On the emulator the same settings measured anywhere from 7 to 18 ms of UI time across rounds, so its table is not evidence. Run it, or the menu, on the phone. `SCENE_FRAME_STATS=true` logs `island frames: n=… ui avg/p90/max … | raster avg/p90/max … | <mode> <rain> <storm>` every 5 s from `FrameTiming`; use it with `--profile`. The simulator can't be tapped from a script; these are how each mode and light was screenshotted.

### Not verified

- **No device numbers.** Every observation above is from the simulator in debug or the emulator, and says nothing about a phone's frame rate (see "Performance pass" for why the emulator's numbers can't be quoted either). Super Ultra adds a second scene render (the planar capture) and several screen-space passes. Profile it on the iPhone and the Android phone (`--profile`, DevTools frame chart) before quoting it. If a thread is over budget, the levers are, in order: the planar `resolutionScale`/`layerMask`, god-ray steps, grass count, `renderScale`, then the AO method.
- **The heat haze** is subtle; it isn't confirmed visible at stage distance.
- **Android** is verified only on the `hybrid_demo_shop` emulator (API 36, Impeller on OpenGL ES): all six tour stops render correctly, and Normal still renders. That says nothing about a real Android GPU's Vulkan path or its frame rate.

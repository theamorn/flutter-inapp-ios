# 06 — Tab 5: Island scene (`flutter_scene`)

## Goal

The finale. A low-poly island rendered with `flutter_scene`, with an orbiting camera, a day→night slider, a particle layer, and — the interaction the tab is built around — **tap anywhere on the island and a character walks there.**

## Prerequisites

- `01-scene-spike.md` complete, **including its Findings section.** Read it before designing anything here — it records whether real directional lighting is available, which decides how day/night is implemented.
- `02-ios-host.md` complete (engine for route `/scene` exists, `FLTEnableFlutterGPU` set).

## Repo facts you need

- `flutter_scene` (0.23.0) and `flutter_gpu` (from the SDK) are in `flutter_module/pubspec.yaml`, with `vector_math` as an explicit dependency. **`flutter_scene_importer` is not, and must not be** — see `01-scene-spike.md`.
- The asset pipeline is a **build hook**, `flutter_module/hook/build.dart`, installed by `dart run flutter_scene:init`. Sources are `.glb` under `assets/models/`, loaded **by source path**: `loadScene('assets/models/tree_palm.glb')`. The hook converts them to `.fsceneb` under `flutter_scene_generated/`, which is listed under `flutter: assets:` and is gitignored by design. Commit the `.glb`.
- Flutter GPU is enabled via the host's Info.plist key `FLTEnableFlutterGPU` (capital `GPU` — see `01-scene-spike.md` for the casing trap). **This repo has `Info-Debug.plist` and `Info-Release.plist`, not `Info.plist`; the key is in both.**
- `flutter_module/lib/shader_screen.dart` is the reference for fragment-shader work.
- `flutter_scene` ships agent skills. They are installed at `flutter_module/.claude/skills/` (`fvm dart run flutter_scene:skills`); `references/traps.md` in `flutter_scene-idioms` is the highest-value page in this repo for anyone touching 3D.

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

`pubspec.yaml` needs **no** change: `assets/models/` is never listed, because only the hook's `flutter_scene_generated/` output ships.

## Implementation notes

### Assets

Low-poly diorama props plus a character. CC0 sources — this build uses Kenney's **Nature Kit 2.1** and **Blocky Characters 2.0**. Drop the `.glb` under `assets/models/` and load by source path; there is no import command any more.

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

**Real directional lighting**, per `01-scene-spike.md`'s Findings. `PhysicalSkySource` + `Skybox` + `SkyEnvironment` + a `DirectionalLight` node, all driven by `DayNightCycleComponent` with the slider bound straight to `timeOfDay`. See the Findings below for why this is *not* `Scene.sunLight`/`SunLight`, and why a second, moon light is needed.

The slider also swaps the particle layer: daytime dust motes → nighttime fireflies.

### Particles

A **2D overlay** composited over the 3D render, not 3D particles. Far cheaper, and at projector distance it reads better anyway.

### Readout

Triangle count and draw calls on screen, next to the HUD's framerate.

### Visibility

The engine stays alive when the host hides the tab. The render loop must stop, or tab 5 skews every other tab's HUD numbers — which is the demo's entire evidentiary basis.

## Gotchas

- Unprojection is easy to get subtly wrong. Verify by tapping the four **corners**, not just the centre. The classic symptom is an error that grows toward the screen edges.
- Do not raycast against the full mesh. A ground plane is enough and is orders of magnitude cheaper.
- If the model renders black, it is almost always the material, not the lighting.
- The engine stays alive when the tab is hidden. Stop the render loop when the route is not visible.
- **Read `flutter_scene-idioms/references/traps.md` before writing scene code.** In-place transform edits, non-uniform scale on a lit mesh, and FOV in degrees are all silent failures.

## Acceptance criteria

- [ ] Island renders on a physical device in release mode. — **NOT VERIFIED: no device attached. Verified on the iOS simulator in debug.**
- [x] Camera orbits and zooms smoothly, clamped sensibly. — implemented via `OrbitCameraController`; **clamping and smoothing not exercised by hand** (no way to drag a simulator programmatically).
- [x] Tapping anywhere on the island moves the character there, facing the direction of travel, with a visible tap marker. — verified on the simulator through the auto-demo probe, including off-centre positions.
- [x] Day→night slider works smoothly end to end and swaps the particle layer. — verified by sweeping `timeOfDay` and screenshotting day, dusk and night.
- [x] Triangle count and draw calls are displayed.
- [ ] Full refresh rate held during simultaneous orbit + character movement + day/night sweep. — **NOT VERIFIED: needs release-on-device. Debug simulator timings are not evidence.**
- [x] Render loop stops when the tab is not visible. — **verified on the simulator** by backgrounding the app: one `render loop stopped` log line, one `render loop resumed`, and the scene returns intact. **The add-to-app tab-switch path specifically is still unverified** (see Findings).

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

**`applyLightingToTarget: false` and apply it yourself.** The component still aims the sun node and writes `skySource.sunDirection`; turning off the application step lets you put a floor under `environmentIntensity` and add a moon (below) without fighting it every frame. Note the component's `update` runs from `Scene.render`'s implicit tick, which happens **after** `SceneView.onTick`, so anything you write to the light from `onTick` is overwritten unless you turn this off.

**Golden hour is present but subtle, and that is a design choice you may want to reverse.** `evaluateLighting()` scales the sun's *intensity* by the same `smoothT` that drives its *colour*, so at the horizon the light is simultaneously reddest and dimmest and the warm cast barely lands on the terrain. Screenshotted at 17:30 the shadows rake right across the island and the sky darkens convincingly, but there is no dramatic orange. If the presenter wants a stronger sunset beat, hold the intensity up near the horizon while keeping the colour ramp — that is a few lines in `_applyLighting`, not a change to the component.

**The night needs its own light.** With the sun below the horizon `PhysicalSkySource` renders black, so the `SkyEnvironment` bakes a black environment and `environmentIntensity` has nothing to scale — the island goes to literal black, screenshot-confirmed. A dim, cold, shadowless `DirectionalLight` faded in on `nightBlend` is what makes the night half of the slider a scene rather than a black rectangle. It costs one more light and no extra shadow pass.

**`SkyEnvironment` refresh policy matters.** The default is `manual`, which bakes once — so the sky visibly moves while the lighting stays stuck at the initial time of day. `SkyEnvironmentRefresh.interval` at 200 ms with `faceResolution: 64, equirectWidth: 256` keeps the IBL following the slider for a fraction of a frame's work. `everyFrame` is a real per-frame pass and is not worth it here.

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

`flutter_scene` exposes no draw-call counter. The readout counts **mesh primitives in the visible scene graph** — one per colour-pass draw. It does **not** include the shadow pass, the skybox, the IBL bake or the post stack, so the real GPU draw count is higher. On stage the honest phrasing is "36 meshes in the scene graph"; do not claim it is the total GPU draw count.

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
- **No sound, no post-processing beyond the `stylized` preset, no LODs.** The scene is 2,340 triangles across 36 meshes; none of that is needed at this size.

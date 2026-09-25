# Flutter 3D playbook (`flutter_scene`)

A reusable reference for building a 3D demo with `flutter_scene`, distilled from the island tab (`06-island-scene.md`) and its Super Ultra mode. It is written to be **copied into another project on its own**: it names the file in this repo that implements each recipe, but nothing here depends on the island.

> **Pinned to `flutter_scene 0.23.0`, Flutter 3.47.2 (Dart 3.13.2), Impeller.** APIs and traps below were checked against that package's source. Re-check anything marked *engine behaviour* after an upgrade.
>
> **Evidence level.** Everything here was verified on the iPhone 17 Pro **simulator** (Metal) and an Android **emulator** (API 36, Impeller on OpenGL ES), in debug. That is evidence for *correctness*, never for *frame rate*. Performance claims need a physical device in profile or release mode.

Read the `flutter_scene` agent skills too (`dart run flutter_scene:skills` installs them into `.claude/skills/`). `flutter_scene-idioms/references/traps.md` is the best single page on the engine. This playbook covers what the skills do **not** say, or say too quietly.

---

## 1. Setup checklist

| Step | Detail | Silent failure if wrong |
|---|---|---|
| Dependencies | `flutter_scene`, `flutter_gpu: {sdk: flutter}`, `vector_math` (explicitly). **Not** `flutter_scene_importer` (dead; pins `hooks ^1`). | Version solving fails, and pub suggests downgrading. |
| Build hook | `dart run flutter_scene:init` writes `hook/build.dart` (`buildScenes` + `buildMaterials`). Add `flutter_scene_generated/` under `flutter: assets:`. | Models and `.fmat` materials are never compiled. |
| Math import | `package:vector_math/vector_math.dart`, **not** `vector_math_64`. | Type errors, or two incompatible `Vector3`s. |
| iOS GPU flag | `FLTEnableFlutterGPU` = true in **every** Info plist the host uses (this repo has separate debug and release plists). Note the capital `GPU`; the tooling's own constant is misspelled. | No Flutter GPU, and no error. |
| Android GPU flag | `<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true"/>`. Must be fully qualified. | No Flutter GPU, and no error. |
| `flutter run` | `--enable-flutter-gpu`. Never `--enable-experiment=native-assets`. | — |
| Add-to-app entrypoint | Any `flutter run` in the module can rewrite `FLUTTER_TARGET` in `.ios/Flutter/Generated.xcconfig`: to your `-t` file, or to an absolute path. Afterwards, check `grep FLUTTER_TARGET .ios/Flutter/Generated.xcconfig` reads `lib/main.dart`. | The host app silently builds the wrong entrypoint. |
| glTF screening | Before adding a `.glb`: every node reachable from a scene, no duplicate node names, textures embedded (not `uri:` sidecars). Kenney exports need `metallic = 0`, and `KHR_materials_unlit` swapped for PBR, or they won't respond to lighting. See `06` Findings for the prune script. | `Child already has a parent`; untextured models; black or unlit props. |
| Skills | `dart run flutter_scene:skills`, then `--check` after upgrading the package. | Stale guidance. |

---

## 2. Architecture that held up

**Own the scene imperatively.** A plain Dart class owns the `Scene` and the game state; `SceneView(scene, onTick: …)` displays it. Per-object behaviour lives in `Component.update(dt)` on nodes. Keep the class's own `tick` for game-wide simulation only. (`island_scene.dart`, `island_components.dart`)

**Put every piece of pure maths in a GPU-free file and unit-test it.** `flutter test` can import `package:flutter_scene/scene.dart` and use cameras, `MeshData`, `WaterSurfaceComponent`, `GerstnerWave`, and so on. Nothing touches `flutter_gpu` until a `Scene` or `Geometry` is constructed. In this repo that pays for itself:
- `tap_to_move.dart`: unprojection round-trips at the screen corners.
- `ocean_waves.dart`: the GPU wave formula matches the CPU one.
- `island_terrain.dart`: the flat top is exact and triangles face up.
- `sky_path.dart`: the moon stays in frame.
- `procedural_textures.dart`: tiles are seamless.

**Quality tiers as an enum, each tier a superset of the one below.** `IslandQuality { normal, ultra, superUltra }`.
- The heavy tier is **built lazily and asynchronously** the first time it's chosen: `compute()` for texture baking and meshing, `loadFmatMaterial` for materials.
- **Show the previous tier while it builds**, so the button responds immediately.
- A **request counter** lets a later choice supersede one still building.
- Mount the tier's content under **one root node** (`mount`/`unmount`).
- Leaving the tier **restores everything it changed**: sky, camera limits and framing, projection, shadow settings, latitude, and hidden nodes.

(`super_ultra/super_ultra_rig.dart`, `IslandScene.setQuality`)

**Keep one clock per effect, shared by GPU and CPU.** When a shader animates something the CPU also samples (waves under buoys), the rig owns the time and hands the *same* value to the shader parameter and to `WaterSurfaceComponent.evaluateAt(pos, customTime)`.

**Stop the render loop with `TickerMode`, not `SceneView(autoTick:)`.** Toggling `autoTick` recreates the ticker, and a `SingleTickerProviderStateMixin` throws the second time. Also pin `onGenerateInitialRoutes` to exactly one route, or a deep-linked route mounts two scenes.

**Keep the readout honest.** Label the number "meshes", not "draw calls": the engine exposes no draw counter. Count triangles with `Geometry.extractMeshData().triangleCount`, cached per geometry, including instanced batches.

**Reframe the orbit camera without setters.** `OrbitCameraController` has no public azimuth, polar or distance setters. To move the camera, build a new controller at the camera's *current* pose, then push its goals so it eases instead of cutting:

```dart
// polar is ELEVATION above the horizon; the eye sits at -(sin az, 0, cos az).
final offset = cameraNode.globalTransform.getTranslation() - target;
final distance = offset.length;
final polar = math.asin(offset.y / distance);
final azimuth = math.atan2(-offset.x, -offset.z);
final next = OrbitCameraController(target: target, distance: distance,
    azimuth: azimuth, polar: polar, minPolar: …, maxPolar: …);
next
  ..orbitBy(wrapAngle(wantAzimuth - azimuth), wantPolar - polar)
  ..dollyBy(-math.log(wantDistance / distance) / next.dollySpeed);
cameraNode..removeComponent(old)..addComponent(next);
```

`CameraComponent.projection` is settable, which covers FOV and far-plane changes. Any widget holding the controller (`CameraControls(controller:)`) must be rebuilt with the new one. (`IslandScene._reframeCamera`)

**Aim the camera at a light.** To look along a horizontal heading `d`, use azimuth `atan2(d.x, d.z)`.

---

## 3. The look: `EnvironmentSettings` rules

### Rule 1 — it is the *whole* look, sky included

`scene.environmentSettings = EnvironmentSettings(...)` runs `applyLookTo`, which assigns `scene.skybox`, `scene.skyEnvironment`, `scene.environment`, `scene.sunLight`, `toneMapping`, `exposure` **and** `environmentIntensity`. A literal that doesn't name a sky **sets it to null**. The island ran for weeks with no sky and default studio lighting because of this.

```dart
scene.environmentSettings = EnvironmentSettings(
  skybox: activeSkybox,               // every literal, every mode
  skyEnvironment: activeSkyEnvironment,
  toneMapping: ToneMappingMode.aces,
  // …
);
applyLighting(); // it also reset environmentIntensity to 1.0
```

**Detect it:** sample a sky pixel. If it equals the app's background colour exactly, nothing drew there (see §6).

### Rule 2 — pick a preset, then move one knob at a time

Start from the looks skill's `showcase` / `stylized` / `moody` / `clean` literals. The Super Ultra look is `showcase` grounding plus the atmospheric half of `moody`:
- GTAO with bent normals, at half resolution
- God rays: 24 steps, density about 0.18 (0.45 hazed the whole frame)
- Exponential fog about 0.003, with `fogSkyColorInfluence: 1` so distant geometry melts into the sky
- Bloom threshold 1.0, plus lens flare with the halo kept low
- Grain about 0.035
- SSR **off** when planar reflections are on, or the two double up

### Rule 3 — a sky you can see needs its own exposure

The physical daylight model is tuned so a midday sky sits near 1.0. **Framed on a low sun**, its forward-scatter glow runs 4–50× the zenith radiance (worked out numerically for the real parameters). After ACES and the sRGB encode, anything above about 1.6 is near-white, so the whole frame turns white. The fixes, in a custom sky:
- Compress daylight luminance above a knee at 1: `L' = min(L, 1) + e / (1 + 0.9e)` with `e = max(L - 1, 0)`.
- Multiply the daylight sky, **not the sun disk**, by about 0.5.
- Use turbidity about 3.
- Evaluate the formula in a few lines of Python before touching the shader. It's faster than screenshot tuning.

### Rule 4 — night lighting is your job

A physical sky is black below the horizon, so the lighting baked from it is black too. Add a moon:
- A shadowless dim key light is enough for readability.
- For moonlit shadows and god rays, **re-aim the one shadow-casting light** at the moon past mid-twilight, and give it a cold colour.
- Keep an ambient floor (`environmentIntensity` of 0.25–0.45).
- Give the sky a faint navy night base so the night lighting bake has something to bake.

### Rule 5 — decouple where the sun *is* from how bright it is

To keep the sun in frame, drive its *direction* from a high-latitude arc (`DayNightCycleComponent.latitude ≈ 68` peaks near 22°). Take its *colour and intensity* from a second, unmounted `DayNightCycleComponent` at a normal latitude, so noon still looks like noon. `evaluateLighting()` works on an unmounted component.

---

## 4. `.fmat` authoring

### The contract

| Thing | Rule |
|---|---|
| Blocks | `material { … }` plus **either** `fragment { void Surface(inout MaterialInputs material) }` **or** `sky { vec3 Sky(vec3 direction) }`. A surface material may add `vertex { void Vertex(inout VertexInputs vertex) }`. |
| Shading | `lit` (default), `physical`, `unlit`. `engine_inputs` require a lit model. |
| Blending | `opaque` or `alpha` (premultiplied) **only**. There's no additive mode, and unlit output is premultiplied by alpha, so alpha = 0 cannot give additive either. Use `SpriteMaterial` with `SpriteBlendMode.additive` for glow. |
| Engine inputs | `scene_color`, `filtered_scene_color`, `scene_depth`, `planar_reflection`. Surface materials only. Accessors: `GetSceneColor(uvOffset)`, `GetSceneDepth(uvOffset)` (returns 1e8 if unavailable), `GetFragmentViewDepth()`, `GetPlanarReflection()`. The raw `planar_reflection` sampler and `planar_reflection_info.view_projection` are in scope if you want to distort the lookup yourself. |
| Parameters | `float int vec2 vec3 vec4 mat4 sampler2d samplerCube`. **No `mat3`, no arrays**: pack per-wave data into `mat4` columns (`m[i]` in GLSL is `Matrix4.setColumn(i, …)` in Dart). Set with `material.parameters.setFloat/setVec4/setMat4(…)`. Textures: `setTexture(name, tex.gpuTexture, sampler: tex.sampledSampler)`. |
| Varyings | `varyings: [{ type: float, name: v_x }]`. Write it in `Vertex()`, read it in `Surface()`. |
| Vertex stage | Displace by writing `vertex.world_position` and `vertex.world_normal`. `vertex.position` is object space and `vertex.camera_position` is available. **There is no `GetTime()` in the vertex stage**: pass a `time` parameter from Dart each frame. `Vertex()` runs for instanced meshes (after the instance transform) and in the depth variant too. |
| Fragment accessors | `GetWorldPosition()`, `GetWorldNormal()`, `GetViewDirection()` (toward the camera), `v_viewvector` (camera − position; its length is the distance), `GetUV0()`, `GetVertexColor()` (includes the instance colour), `GetScreenUv()`, `GetTime()` (lit only), `SRGBToLinear()`. |
| Output | Linear HDR. `base_color` has straight alpha; `emissive` is added after lighting; `specular` scales **both** direct and IBL specular. Set `specular` to 0 where you composite your own reflection. |
| Loading | `loadFmatMaterial('assets/materials/x.fmat')` gives a `PreprocessedMaterial`; `loadFmatSky(…)` gives a `PreprocessedSky`, which is a `ShaderSkySource`, so it works in `Skybox(...)` and in `SkyEnvironment(...)`. One material instance per `PlanarReflectorComponent` group. |

### Portability rules (Metal hides all of these; GLES doesn't)

1. **Never `#include <noise.glsl>`** in a material that has to run on GLES. Its large constant tables made the sky pipeline fail **silently** on the Android emulator: the sky drew nothing, the lighting baked from it was garbage, and nothing appeared in logcat. Use local hash noise (below).
2. **Never write a reversed `smoothstep(hi, lo, x)`.** It's undefined in GLSL ES. Write `1.0 - smoothstep(lo, hi, x)`.
3. **Never call `pow()` on a base that can be negative.** Square by hand. Clamp `acos`/`asin` inputs to [-1, 1]; a normalized dot can land a hair past 1. Guard divisions with `max(x, 1e-12)`. **One NaN in a sky** leaves the sky transparent and, through the lighting bake, poisons every lit surface.
4. **Don't use reserved words as names**: `patch`, `sample`, `input`, `output`, `filter`, `active`… The compile error is obscure.
5. **A translucent material with `depth_write: true` is written into the depth texture that `scene_depth` samples** (`TranslucentDepthPatchPass`). Any material that reads `scene_depth` to measure what's behind it must use `depth_write: false`, or it reads its own surface.
6. **Sampler budget.** The lit framework already uses several samplers; the ceiling is 15 on GLES. Count engine inputs plus your textures. Water here uses 3 + 2.
7. **Textures:** `Texture2D.fromPixels(bytes, w, h, content: …, sampling: TextureSampling(…))`.
   - The bytes are sampled raw: call `SRGBToLinear` on colour maps yourself.
   - Use `TextureContent.normal` for normal maps and `.data` for masks, so mips average correctly.
   - For flipbooks, cap `maxMipmapLevels` and use `SamplerAddressMode.clampToEdge` (from `package:flutter_scene/gpu.dart`) so frames don't bleed.
8. **Build hook cache.** If a new `.fmat` doesn't appear, delete `.dart_tool/hooks_runner/<package>` and rebuild (deleting just its `*/dependencies.dependencies_hash_file.json` is enough, and keeps the compiled hook). The hook's discovery hash covers only the names directly under `assets/`, so a new file inside `assets/materials/` doesn't rerun it, and touching an existing `.fmat` doesn't either: the cache compares contents. Check `flutter_scene_generated/material.*.index.json` for your material names. Bundles are per backend (`metalIos`, `metalDesktop`, `openglEs`, `openglEs,vulkan`), about 2–3.6 MB each, and everything in the folder ships as assets. `.fmat` edits need a rebuild, not a hot restart.
9. **Test on the Android emulator** as well as the simulator. It runs Impeller on OpenGL ES and caught two of the rules above.
10. **A failed `.fmat` compile keeps the old shaders and the build still succeeds.** The only sign is one line: `building .fmat materials failed; keeping the previous shaders.` Grep for it after every material edit, or you'll debug a change that never shipped. (A redefined local variable did it here.)

Local noise that replaced `noise.glsl` (sine-free hashes after Dave Hoskins):

```glsl
float Hash12(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}
vec2 Hash22(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}
float ValueNoise2(vec2 p) {            // -1..1
  vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
  return mix(mix(Hash12(i), Hash12(i + vec2(1, 0)), u.x),
             mix(Hash12(i + vec2(0, 1)), Hash12(i + vec2(1, 1)), u.x), u.y) * 2.0 - 1.0;
}
float WorleyBorder2(vec2 p) {          // F2 - F1: ~0 on cell borders
  vec2 i = floor(p), f = fract(p);
  float f1 = 8.0, f2 = 8.0;
  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
    vec2 c = vec2(float(x), float(y));
    float d = length(c + Hash22(i + c) - f);
    if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
  }
  return f2 - f1;
}
```

Full 3D versions (`Hash13`, `ValueNoise3`, `Fbm3`, `Worley2`) are in `assets/materials/island_sky.fmat`.

### Prefer baked textures to per-pixel noise

Fine procedural detail evaluated per fragment has no mips, so it sparkles at a distance, and it costs ALU over the whole screen. Bake tileable maps on an isolate instead (periodic gradient noise and wrapping Worley; `procedural_textures.dart`), upload them with a mip chain, and sample them at two or three scales. Keep shader noise for low-frequency variation only.

---

## 5. Recipes

Each recipe names its implementation in this repo; copy it and change the numbers.

### Clear water (`ocean.fmat`, `ocean_waves.dart`, `island_terrain.dart: buildOceanMeshData`)

- **Mesh.** A polar ring grid, dense (about 0.45 m) near the shore and geometric out to the horizon, starting under the island so the waterline is always inside it. It's flat; the shader displaces it. Set `frustumCulled = false`, because the GPU displacement makes the flat bounds wrong.
- **Vertex.** Four Gerstner waves using exactly `WaterSurfaceComponent`'s formula, packed as `mat4 wave_shape` (dir.x, dir.z, A, k) and `mat4 wave_motion` (ω, qA, qkA, 0). A unit test holds the packing to the CPU result. Fade the waves out where the grid gets coarse.
- **Fragment.** The flow is as follows:
  - Ripples: two scrolling normal-map samples.
  - Thickness: `GetSceneDepth − GetFragmentViewDepth`. Drop the refraction offset if it would sample something in front of the water.
  - Refraction and colour: `GetSceneColor(offset)` × Beer–Lambert transmittance, plus body colour × in-scatter × a `water_light` parameter from Dart. The water is emissive, so it needs to be told how lit it is.
  - Reflection: sample the planar capture with a ripple-distorted projection, and mix by Schlick Fresnel (F0 0.02).
  - Output: `emissive = water`, `specular = 0` when a capture is bound (the IBL takes over when it isn't).
  - Foam: along thin water and on crests.
  - Alpha: feather it to 0 at thickness 0 so the shoreline has no hard seam, and fade the far rim into the fog.
- **Node.** `PlanarReflectorComponent(resolutionScale: 0.5, layerMask: all & ~noReflectLayer)`. The capture re-renders the scene, **skybox included**, so the sun glints in the water for free. Keep grass and other dense clutter on a layer the mirror skips; `Node.layers` is not inherited, so set it on each such node.
- **CPU twin.** An unmounted `WaterSurfaceComponent` with the same waves, sampled with the shader's clock, for buoys and floating objects.

### Simple sea (`ocean_simple.fmat`, `island_terrain.dart: buildSimpleSeaMeshData`)

The effects menu's cheap stand-in, mounted instead of the clear water when `Full sea` is off. It keeps the look's outline and drops everything that reads the frame back:
- **Opaque, no `engine_inputs`.** No `scene_color` means no split scene pass and no copies; no planar reflector means no second scene render; and the seabed under it is never shaded.
- **Depth baked into the mesh.** The shader can't read scene depth, so each vertex carries the water depth under it in vertex red (`/ kSimpleSeaDepthScale`), from the terrain heightfield. Colour and surf foam run off that, with `depth / max(view.y, 0.2)` standing in for the view-ray thickness.
- **Reflection from the engine.** `specular = 1` gives the sky reflection; the emissive water colour is scaled by `1 − Fresnel` so the sky takes over at grazing angles, as the mirror does in the full sea.
- **Runs to the far plane.** Opaque water can't alpha-fade into the sky, so its rings go out to 660 m, past the 640 m far plane, and the fog hides the edge.
- **Same waves.** The vertex block is a copy of `ocean.fmat`'s; keep the two identical.

### Terrain with an exact gameplay plane (`island_terrain.dart`)

- **Heightfield.** A pure function, exactly `0` inside the walk and ball radius. Use an epsilon so the rim ring doesn't compute −1e-30. Outside it: lip, then beach or rocky headland (from domain-warped coast noise), then shelf, then reef drop. Tap-picking stays a plane intersection.
- **Mesh.** A polar grid with rings dense where the shape changes. Winding: `(inner_j, inner_{j+1}, outer_j)` and `(inner_{j+1}, outer_{j+1}, outer_j)` for +Y faces; a test asserts every triangle's normal has `y > 0`. Build `MeshData.build(...)` in `compute()`, which also generates normals, then `MeshGeometry.fromMeshData`. Put masks in vertex colour (rock, dirt/trail) for the ground material. Set `shadowStatic = true`.

### Ground material (`island_ground.fmat`)

- **Splat** from world height (under water / wet band / sand below the lip), slope (rock), and vertex masks.
- **Relief** from two tileable normal maps (clumps; wind ripples, rotated off-axis) applied through a tangent frame with T = +x and B = +z.
- **Caustics** only under water: the `min()` of two scrolling layers of a baked Worley-border texture at cells of about 0.3 m. Fade them with view distance (at 0.7 m cells they read as a web of polygons) and scale them by daylight.
- **Rock cracks** only above water, where silt doesn't fill them.

### Grass (`grass.fmat`, `SuperUltraRig._buildGrass`)

- An `InstancedMesh` of a three-blade tuft built with `GeometryBuilder(deduplicate: false)`: dark root to bright tip in vertex colour, and normals authored **mostly up**, so the tuft shades like turf rather than cards. Use `culling: none` and `castsShadows = false`.
- Place tufts on a jittered grid, thinned by a low-frequency density field and kept off paths and prop footprints. About 2,800 tufts covered roughly 300 m² densely.
- **Vertex:** quadratic-cantilever wind (`h²`), travelling gusts, and a push away from a `player` parameter.
- **Fragment:** a translucency glow when the key light is behind the blade.

### Sky with sun, moon and stars (`island_sky.fmat`, `sky_path.dart`)

- **Daylight:** port the engine's physical sky. It's MIT and was about 60 lines in 0.23.0. Apply §3 rule 3.
- **Sun:** a disk drawn about four times real size, with limb darkening and a corona, unscaled so it blooms and flares.
- **Moon:** a lit sphere in sky space. It gets its phase from the real sun direction, maria from fbm, craters from Worley, and a little earthshine. Its path is a pure function, tested to stay in frame.
- **Stars:** at most one per cell of a 3D direction grid, jittered inside the cell. **Size them in `1 − cos` units, about 1.5–4.5 × 10⁻⁷, which is about a pixel**, and window the falloff well inside the cell. Otherwise they come out as squares, and the water stretches those into streaks.
- **Wiring:** `Skybox(sky)` plus `SkyEnvironment(sky, refresh: manual, faceResolution: 64, equirectWidth: 256)`. Call `invalidate()` when the clock moves, never per frame; the `interval` refresh jittered on device.

### Fire (`super_ultra_fire.dart`, `procedural_textures.dart`, `ember_bed.fmat`, `heat_haze.fmat`)

Real-time fire is a VFX recipe, not a shader trick:

| Layer | Settings that mattered |
|---|---|
| Flames | A 4×4 flipbook of **one tongue's life**: bud, then lick, then detach and erode. Use the same noise field scrolled per frame so frames blend. `FlipbookModule(frameCount: 16)` over life, `flipbookBlend = true`, `facing = axisLocked` (upright), `TurbulenceModule` (curl noise), additive blending, `softDepthFade`, and an **HDR colour ramp** (about 3.6 → 0.25) so bloom finds the core. |
| Core glow | A few large, short-lived soft dots, additive. |
| Embers | Long-lived, strong turbulence, `LinearDragModule`, `facing = velocityStretched`. |
| Sparks | `Spawner(bursts: [ParticleBurst(…, interval: …)])`, gravity down, stretched. |
| Smoke | Alpha blend, a 2×2 puff atlas with **`FlipbookModule(framesPerSecond: 0.01, randomStartFrame: true)`** (a fixed random variant per particle), rotation, a warm tint at the base, `cameraNearFade`. |
| Coals | A lit alpha disc under the logs: Worley borders glowing, with breathing noise. |
| Heat haze | A lit `.fmat` with `scene_color`, on a camera-facing quad that its vertex block turns to face the camera. `emissive = GetSceneColor(noiseOffset)` and `specular = 0`. Subtle. |
| Light | A point light with irregular flicker (incommensurate sines), not one periodic sine. |

Without a texture a sprite is a hard square: always give it at least a soft dot.

---

### Rain that collides (`super_ultra_rain.dart`, `rain_collision.dart`)

**Don't collide particles through `Scene.raycast`.** It tests render triangles one by one without a per-mesh BVH, and it skips instanced meshes. Use analytic proxies instead, all pure Dart and unit-tested:
- the terrain as a height grid sampled once on an isolate;
- the water as a plane where the ground is below it;
- props as vertical ellipsoids, cylinders and cones sized from each `.glb`'s bounds (read the POSITION accessor min/max);
- moving things as capsules and spheres rewritten once per step.

**The collision module** is a custom `ParticleModule`:
- `spawn()` lifts new drops to the top of the rain box, and can re-aim a share of them.
- `update()` skips every drop above the tallest obstacle, tests the rest, queues a hit, and kills the drop with `storage.age[i] = storage.lifetime[i]`. The system reaps it at the end of the step.

**Splashes and other emitted-at-a-point effects:** give that `ParticleSystem` `Spawner(rate: 0)` and a module that drains a hit queue with `storage.spawn()`, writing *every* column (pos, vel, age, lifetime, size, baseSize, rotation, colour, frame, axis, random01). Put `ColorOverLifeModule` after it in the list so new particles get their colour on the same step.

| Setting | Value that worked |
|---|---|
| Drops | `BoxEmitterShape` 54 × 54 m, 18 m up, a slightly slanted direction for wind; 10.5–13 m/s; width 0.014–0.024; `velocityStretched`, stretch 0.055; alpha blend at 0.55; **2,300/s at full strength** (`Spawner.rate` is mutable, so ramp it) |
| Hits on characters | 30% of drops spawned over the characters, upwind by the drift. Uniform rain hits a 1 m character about every 8 s. |
| Splash | Two or three droplets thrown up 0.5–2.5 m/s plus a 0.035–0.06 m flash for 0.07–0.1 s. Rates: ground 12% of hits, water 20%, solid things 100%. |
| Water rings | A pooled `InstancedMesh` of 128 flat `RingGeometry` instances (unlit, alpha); each grows to about 0.45 m over 0.75 s, and idle ones shrink to nothing under the sea. The ocean shader draws the dense rings. |
| GPU weather | One 0–1 level drives the sea's ring normals, darker, shinier ground with ringed puddles, wet grass, an overcast sky that hides the sun, moon and stars, a key light down 60%, god rays down 85%, and fog up from 0.003 to 0.016. Fade over 2.5 s; rebake the sky lighting every 0.4 s during the fade, not per frame. |
| Night | Tint every unlit rain effect by the light level, or it glows white. |
| Off | Fade out, then unmount the root once the last particle has landed. The toggle is then a true zero-cost switch for performance comparisons. |

### Lightning (`lightning.dart`)

**Bolt.** Build it by midpoint displacement: each pass splits every segment and kicks the midpoint sideways by about 0.26 × its length, which is jagged at every scale while staying within about 0.4 of the bolt's length of a straight line. Fork one to four branches from the upper two thirds. Draw each polyline as `TubeGeometry(PolylinePath(points), stations: points.length, radius: 0.1–0.22, radialSegments: 5, caps: false)` in one `Mesh.primitives`, with an `UnlitMaterial` in HDR (colour about 9–14 × the flash) so bloom makes the glow. **Hide the node between pulses**: an opaque unlit tube dimmed to zero is a black line.

**Flash envelope.** Two or three pulses in about half a second (a dim leader, the main stroke, sometimes a re-strike), each with a 12 ms rise and a 55 ms decay. Drive everything from that one value:
- a shadowless `DirectionalLight` from the strike (changing its intensity doesn't invalidate cached shadows);
- `environmentIntensity` on top of its current base, restored when the flash ends;
- a sky-shader parameter that lights the clouds, brightest toward the bolt;
- the tint of any unlit rain.

Don't rebake the sky lighting per flash.

**Safety and placement.** Keep it at three flashes a second or fewer, with strikes at least about 4.5 s apart, and give it its own toggle. Scale the flash's scene lighting by darkness (about 0.3 by day, 1.0 at night), or noon strikes white out the frame. Aim most strikes inside the camera's field of view (portrait is only about ±14° wide), at 45–85 m.

**Verification.** A 50 ms flash can't be screenshotted by a script. Add a debug-only hold (freeze the envelope at its peak for a couple of seconds), log each strike, and capture on the log line.

## 6. The verification loop that worked

**Drive the app without touching it.** A script can't tap a simulator, so add debug-only `--dart-define`s that are off in every shipped build:
- `SCENE_QUALITY=<tier>` picks the mode after load.
- `SCENE_TOUR=true` steps through fixed times of day, re-aims the camera at the key light, and logs `island tour: <mode> at <time> h` at each stop.
- `SCENE_TOUR_MODES=true` also cycles the tiers, which exercises every transition, including the first lazy build.

(`scene_app.dart`)

**Hot restart by signal.** Run `flutter run --pid-file /tmp/flutter.pid …` in the background, then `kill -USR2 $(cat /tmp/flutter.pid)` to hot restart (`-USR1` hot reloads). A Dart-only ablation then costs about 10 seconds; a `.fmat` change needs a full rebuild.

**Capture one settled frame per stop:**

```zsh
# iOS simulator
until grep -q "island tour" run.log; do sleep 1; done
seen=$(grep -c "island tour" run.log)
for i in 1 2 3 4 5 6; do
  until [ $(grep -c "island tour" run.log) -gt $seen ]; do sleep 0.5; done
  seen=$(grep -c "island tour" run.log); t=$(grep "island tour" run.log | tail -1 | sed 's/.* at //; s/ h//')
  sleep 6   # let exposure, particles and the IBL bake settle
  xcrun simctl io booted screenshot shot_$t.png
done
# Android emulator: adb -s emulator-5554 exec-out screencap -p > shot_$t.png
```

**Read pixels, not impressions.** Decode the PNG (a 40-line zlib-plus-filters reader is enough when PIL isn't installed) and print a grid of RGB values.
- A pixel **exactly equal to the app's background colour** means the scene drew nothing there, or drew NaN.
- (255, 255, 255) across lit surfaces means exposure blow-out or poisoned lighting.

**Ablate one thing per restart,** and when a whole feature is missing, build a **bare-scene repro**: a fresh `Scene` with only the feature (for example, only `Skybox(GradientSkySource())`). If the bare scene works, bisect *your* setup rather than the engine. Probe colours help too: paint magenta if a parameter reads zero. A probe that never appears tells you the shader isn't running at all.

### Symptom to cause

| Symptom | Cause found here |
|---|---|
| Sky pixels equal the app background in every mode | `EnvironmentSettings` literal without `skybox` (§3 rule 1) |
| Sky transparent **and** every lit surface white | NaN in the sky shader (`pow` of a negative base, `acos` > 1), baked into the lighting |
| Same, but only on Android GLES | `#include <noise.glsl>` in the sky; the pipeline failed silently |
| Water invisible, foam everywhere | Water reading its own depth: `depth_write: true` on a material that samples `scene_depth` |
| Whole frame white when facing a low sun | Physical sky glare; needs a knee plus sky exposure (§3 rule 3) |
| Uniform haze over everything | God-ray density or fog sun in-scatter too high |
| Big white squares at night; vertical streaks on water | Star falloff larger than its hash cell |
| Coarse polygon web on the seabed | Caustic or crack cell scale too large for the viewing distance |
| Mode B pastel and washed out after enabling a sky | Exposure tuned against the studio default; re-grade, or keep the old look deliberately |
| Readout off by one mesh right after a switch | Visibility restored by a component the next frame; the recount ran first |
| A shader edit has no effect | The `.fmat` failed to compile and the hook kept the old shaders (look for `keeping the previous shaders`) |
| Bare ground looks snow-covered in rain | A splash for every drop that lands; cut the ground splash rate |
| Rain and rings glow white at night | Unlit sprites and rings not tinted by the light level |
| Rain never visibly hits the characters | Uniform density is too low per m²; aim a share of the drops at them |
| A black line in the sky between lightning pulses | Unlit bolt dimmed to zero instead of hidden |
| Daytime lightning whites out the frame | Flash lighting not scaled down by daylight |
| `No generated .fsceneb for source "assets/…glb"` after adding a model | Stale build-hook cache; delete `.dart_tool/hooks_runner/<package>` and rebuild. Also: `buildScenes` takes `.glb`, so repack a `.gltf` |
| A loaded model still casts shadows after `castsShadows = false` | Not inherited; set it on every node of the model |
| An orientation test fails on code that renders right | `Quaternion.rotated` in vector_math rotates opposite to `Matrix4.compose` (which the engine uses); test through a matrix |
| A flying thing looks like a sheet of paper | A flat box rocked about its forward axis. Use a rigged model's flight clip, and bank it into turns |

---

## 7. Performance

The budget is 16.6 ms at 60 Hz, split between the UI thread (Dart, scene-graph walk, component updates) and the raster thread (GPU work and the whole post stack). **Measure in profile mode on the device** (DevTools frame chart) and fix the thread that's over budget. `flutter_scene` has no stats API.

What the Super Ultra tier adds, roughly heaviest first:

| Cost | Lever |
|---|---|
| Planar reflection: a **second full scene render** per frame | `resolutionScale` (0.5), and a `layerMask` that skips clutter |
| God rays: a shadow-map march per pixel | `godRaysStepCount`, `godRaysMaxDistance` |
| GTAO with bent normals | Half resolution, or fall back to `obscurance` |
| `scene_color` / `scene_depth` snapshots | Only while such a material is visible |
| Grass: about 25k triangles instanced, with vertex wind | Instance count, blades per tuft |
| Terrain and sea: about 51k + 44k triangles | Segment count; terrain is `shadowStatic` |
| Rain: about 3,200 drops in flight plus splashes, all CPU-stepped, and a grid-broadphase collision test for the lowest ones | The **toggle** (off = unmounted); `kFullRate`; the focus share; splash rates |
| MSAA with a `scene_color`/`scene_depth` material: the split scene pass stores and reloads the 4× depth buffer | `smaa` (or `taa`), and `renderScale` below 1 |
| Shadows: 2048 px, 2 cascades, PCSS | Resolution, cascade count, filter |

On the simulator in debug, the cold build (texture bake plus meshing on isolates, plus six material loads) took about 4 s; warm builds took 0.3–0.8 s. Build on a background isolate and show the lower tier meanwhile.

### Where the UI thread goes

A CPU profile of the UI isolate (Super Ultra, rain and storm, Android emulator, profile mode):
- `Scene.render` takes about 80%:
  - the main `ScenePass` about 35%
  - `PlanarReflectionCapturePass` about 16%
  - `BloomPass` (with lens flare) about 13%
  - shadows about 4%
- `Scene._tick` takes 10–15%, mostly particle stepping.
- Widgets take about 3%.

So most UI time is the engine encoding passes you can see. Cutting it further means cutting something visible.

### Wins that change nothing on screen

| Change | Thread | Why it's free |
|---|---|---|
| Keep a GPU-displaced reflector out of its **own** capture: put it on a layer outside its `layerMask` | Raster | The capture clips at the *flat* mirror plane, but vertex-displaced crests poke through it. So the whole sea was being drawn again into its own mirror every frame: 44k triangles, four Gerstner waves, and the scene colour and depth copies its refraction needs. All that bought was stray crest patches. The engine does not exclude a reflector from its own capture. The reflector only needs its layer to be in the **main** view's mask. |
| Skip texture fetches whose weight is exactly zero | Raster | The ground did 7 fetches on every pixel. Now it does 3, plus only the layers present: no grass normals on the seabed, no rock normal off rock. A fetch inside a branch has undefined implicit derivatives. So take `dFdx`/`dFdy` of `p.xz` before any branch, scale them per fetch, and use `textureGrad`. GLES bundles are `#version 300 es`, where `textureGrad` is core. |
| Gate work on the factor that multiplies it | Raster | Sea foam fetches only where surf or crest is above 0. Rain rings only where the distance fade is above 0. The Milky Way's two fbm calls only within 3.2 band-widths, where the band is still above 4e-5 of its peak. |
| Broadphase for CPU particle collision | UI | A 1 m grid over the props' footprints. Each cell lists shapes in their original order, so the first hit is the same. That's 236 → 40 ns per test on the host. On the emulator, `RainCollider.test` fell from 3.6–7.5% to 1.5% of UI samples. |

**Proving "nothing changed":**
- **Code:** an equivalence test against the old path. `rain_collision_test` holds the grid to a per-prop brute-force reference on 20,000 drops.
- **Shaders:** only take changes that are an identity by construction, where the skipped term is multiplied by zero. Then run a before/after screenshot tour: same stops, same dart-defines, side by side, with the mean difference per horizontal band. Keep the "before" files in a scratch directory with a `use.sh before|after` swap, so both builds come from one tree.

### Measuring on the Android emulator

- **Its numbers drift with the host.** On a MacBook Air, one build's UI time crept from 5 ms to over 20 ms across ten minutes. Separate runs of one APK ranged 23–39 fps. It was not a leak:
  - The Dart heap was flat, with identical instance counts a minute apart.
  - The native heap moved between 120 and 140 MB.
  - The emulator has 2 GB of RAM and sat 650–700 MB into swap.

  Compare variants only in alternating runs. A difference smaller than the run-to-run spread is no result; say so rather than quote it.
- **Stopping a profile run:** `flutter run --pid-file` is not written in profile mode. Kill the tool (`pkill -f "flutter_tools.snapshot run --profile"`), then `adb shell am force-stop` the app.
- **Flaky launches:** a launch right after an emulator reboot sometimes ends at once with `Application finished.`; run it again.
- **Find a feature's cost by taking it away, on the device.** On `flutter_scene` the UI thread also encodes every GPU pass and draw, so each extra pass costs UI time, not just raster time. The honest attribution is a per-feature switch plus a live frame readout (the island's `🎛 Effects` menu), or an automated ablation run that cycles the switches (`SCENE_ABLATION`). On the emulator, even interleaved ablation came back with 2–4× swings between rounds of identical settings, so only a device answers this.
- **Instruments that worked:**
  - A `SCENE_FRAME_STATS` dart-define that logs `FrameTiming` UI and raster avg/p90/max every 5 s.
  - A short `vm_service` script that samples the UI isolate with `getCpuSamples`. It works in profile mode, and it attributes time to render-graph passes and to your own modules.

---

## 8. Checklist for a new 3D demo

- [ ] §1 setup: both GPU flags spelled per the embedder, build hook installed, `flutter_scene_generated/` in assets, skills installed.
- [ ] Pure maths in GPU-free files with tests (picking, anything the CPU and GPU both compute).
- [ ] Every `EnvironmentSettings` literal names its `skybox` and `skyEnvironment` (or deliberately none); re-apply lighting afterwards.
- [ ] Every `.fmat`: no `noise.glsl`, no reversed `smoothstep`, no negative-base `pow`, clamped `acos`, guarded divisions, `depth_write: false` if it reads `scene_depth`, samplers counted. After each edit, check the build output for `keeping the previous shaders`.
- [ ] Anything expensive and optional (rain, extra VFX) gets its own toggle that **unmounts** it, so the HUD can show its cost.
- [ ] A debug tour dart-define plus a capture script, so every mode and light gets screenshotted without a finger.
- [ ] Verified on the iOS simulator **and** the Android emulator (GLES).
- [ ] Heavy tiers built lazily, with a supersede token and full restore on exit.
- [ ] Profile on the real devices before any on-stage claim; record the numbers. Emulator frame rates are for alternating A/B runs only, never for a claim.
- [ ] After any `flutter run` in an add-to-app module, `FLUTTER_TARGET` reads `lib/main.dart`.

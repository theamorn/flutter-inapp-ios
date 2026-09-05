# 01 — `flutter_scene` / `flutter_gpu` validation spike

## Goal

Prove that `flutter_scene` renders inside an add-to-app `FlutterEngineGroup` engine, in **release mode, on a physical iOS device**, before any feature work depends on it. Also answer one open design question for `06-island-scene.md`: what `flutter_scene`'s lighting API actually supports.

**This is a throwaway spike.** Its output is an answer plus notes written back into this file. Any code you write here is labeled disposable — do not carry it into tab 5 without rewriting it.

## Prerequisites

- `00-toolchain.md` complete.

## Repo facts you need

- `flutter_module/` is the add-to-app module; `cool-ios/` is the host, already wired via `podhelper.rb` in `cool-ios/Podfile`.
- The host's Info.plist is `cool-ios/cool-ios/Info.plist`. **This is the plist that matters** — the iOS embedder reads GPU/engine flags off the *main bundle*, not the Flutter module's bundle.
- Existing shader loading patterns to crib from: `flutter_module/lib/shader_screen.dart` (`CustomPainter` + `ui.FragmentShader`).

## Flutter GPU enablement — confirmed from 3.47.2 engine source

This was the open risk in the plan. It resolves cleanly: **Flutter GPU does not require `flutter run --enable-flutter-gpu`.** Both embedders accept the flag declaratively, which is exactly what an Xcode- or Gradle-launched host build needs.

### iOS

Add to `cool-ios/cool-ios/Info.plist`:

```xml
<key>FLTEnableFlutterGPU</key>
<true/>
```

The embedder reads this from the main bundle at
`engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterDartProject.mm:235`.

> **Casing trap — this will cost you a day if you miss it.**
> The engine reads `FLTEnableFlutterGPU`, with a capital `GPU`.
> The Flutter tooling's own constant, at `packages/flutter_tools/lib/src/ios/plist_parser.dart:35`, is spelled `FLTEnableFlutterGpu`.
> They disagree. **The embedder is authoritative.** Copying the tooling's spelling produces no error, no warning, and no Flutter GPU — the key is simply never read.

### Android

Add to the host `AndroidManifest.xml` (relevant in `07-android-host.md`):

```xml
<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true" />
```

**The key is fully qualified.** A bare `EnableFlutterGPU` does nothing — see the Findings below, where `07-android-host.md` settled this against the embedding bytecode. The flag is explicitly **allowed in release mode** and settable via the manifest.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/pubspec.yaml` | add `flutter_scene`, `flutter_scene_importer`, `flutter_gpu` |
| `flutter_module/lib/spike_scene.dart` | throwaway render target |
| `flutter_module/assets/models/` | one imported `.model` |
| `cool-ios/cool-ios/Info.plist` | `FLTEnableFlutterGPU` |
| **this file** | write findings back into "Findings" below |

## Implementation notes

1. Add dependencies:

   ```yaml
   dependencies:
     flutter_scene: ^<current>
     flutter_gpu:
       sdk: flutter
   dev_dependencies:
     flutter_scene_importer: ^<current>
   ```

2. Get any small CC0 `.glb` (Kenney, Poly Pizza) and import it:

   ```bash
   cd flutter_module
   fvm dart run flutter_scene_importer:import --input assets/models/thing.glb --output assets/models/thing.model
   ```

   List the `.model` output under `flutter: assets:` in `pubspec.yaml`. The `.glb` itself does not need to ship.

3. Render it from a Flutter screen, then host that screen in `cool-ios` **through an engine spawned from a `FlutterEngineGroup`** — not a bare `FlutterEngine`, and not `flutter run`. The group path is the one tab 5 will actually use, and it is the configuration that could plausibly differ.

4. Build **release**, to a **physical device**.

## Gotchas

- **Debug-mode or simulator success proves nothing here.** The simulator has no meaningful Impeller GPU path, and debug-mode Flutter takes a different code path than the AOT release build the demo runs on. A green simulator run is not evidence.
- Do not test through `flutter run` on the module alone. The whole question is whether this works *in add-to-app*, launched by the host.
- If `flutter_gpu` fails to resolve, re-check `00-toolchain.md` — `flutter precache` must have populated `bin/cache/pkg/flutter_gpu`.

## The lighting question — answer this and record it below

`flutter_scene`'s material and light model is minimal. Before `06-island-scene.md` is designed, determine concretely:

- Does it expose a usable directional light with a settable direction and colour?
- Is there ambient/environment colour control?
- What material types are available (unlit vs PBR), and which does the imported `.model` actually get?

**If real directional lighting is not available or not controllable at runtime**, the day→night effect in tab 5 must instead come from environment/ambient colour plus a shader-drawn sky gradient composited *behind* the 3D. That is a fine outcome and still looks good — but tab 5 must be designed knowing which of the two it is.

## Findings

> Recorded 2026-09-04. `06-island-scene.md` reads from here.

### The package moved. This doc's dependency instructions are superseded.

`flutter_scene` is at **0.23.0** and the API above describes ~0.15. Two changes matter:

**`flutter_scene_importer` is dead — do not use it.** It pins `hooks ^1.0.0`; `flutter_scene >= 0.16.0` needs `hooks ^2.0.0`. Version solving fails outright, and pub's own suggestion is to downgrade `flutter_scene` to `^0.15.0`. Take the other branch: drop the importer. There is no manual `.model` step and no `.model` file — the modern pipeline is a **build hook**.

```bash
cd flutter_module
fvm dart run flutter_scene:init      # writes hook/build.dart + flutter_scene_generated/
```

Sources now live at `assets/models/*.glb` and are loaded **by source path** — `loadScene('assets/models/spike_box.glb')` — with the hook converting them to `.fsceneb` at build time. The `.glb` stays in version control; `flutter_scene_generated/` is gitignored by a `.gitignore` the hook writes itself.

Resolved set: `flutter_scene 0.23.0`, `flutter_gpu 0.0.0 (sdk)`, `flutter_gpu_shaders 0.5.2`, `hooks 2.2.0`. `vector_math` must be an explicit dependency — `flutter_scene`'s API is written in its types, and using them transitively trips `depend_on_referenced_packages`.

### **Does `flutter_scene` render in add-to-app + engine group + release + device?**

**Build-side: yes, proven. Device-side: not yet run — no device was attached.**

The real unknown was never the plist key; it was whether **Dart build hooks execute under `xcode_backend.sh`**, since the add-to-app build is driven by Xcode rather than `flutter build`. They do. From a `-configuration Release -sdk iphoneos` build of `cool-ios.xcworkspace`:

```
Running build hooks for ios_arm64.
  ... dart .../hooks_runner/flutter_scene/.../hook.dill      ← engine shader bundle
  ... dart .../hooks_runner/flutter_module/.../hook.dill     ← our hook/build.dart
Running build hooks for ios_arm64 done.
Running link hooks for ios_arm64 done.
install_code_assets: ...
** BUILD SUCCEEDED **
```

And the converted asset ships in the bundle:

```
cool-ios.app/Frameworks/App.framework/flutter_assets/
  flutter_scene_generated/scene.spike_box.4eeb0a22.fsceneb
  packages/flutter_scene/flutter_scene_generated/          ← compiled engine shaders
```

`FLTEnableFlutterGPU = true` is present in the built `cool-ios.app/Info.plist`.

**Still owed, and it needs a phone:** launch the spike button, confirm the model is on screen, then run the negative control — remove `FLTEnableFlutterGPU`, rebuild, confirm it now *fails*. Until that runs, the claim is "it builds and bundles correctly", not "it renders".

### The simulator gotcha in this doc is wrong — and that is good news

This doc says "the simulator has no meaningful Impeller GPU path." **It does.** Verified by running the spike on an iPhone 17 Pro simulator:

```
$ fvm flutter run -t lib/spike_main.dart -d <sim> --enable-flutter-gpu
[IMPORTANT:...FlutterDarwinContextMetalImpeller.mm(45)]
  Using the Impeller rendering backend (Metal).
```

Both the procedural `CuboidGeometry` and the build-hook-converted `.glb` rendered, textured and PBR-shaded.

The doc conflated two separate claims, and only one of them holds:

- ❌ *"3D will not render on the simulator."* False. Impeller runs on Metal there and Flutter GPU works with `--enable-flutter-gpu`.
- ✅ *"Simulator results are not evidence for this talk."* Still entirely true. Debug-mode timings and simulator timings say nothing about the performance claims, and the HUD numbers from either are meaningless on stage.

**Why this matters practically:** tab 5 can be developed and iterated in the simulator with hot reload, which is far faster than a device round-trip for every camera tweak and lighting change. Only *measurement* requires release-on-device. `lib/spike_main.dart` is kept for exactly this — a standalone entrypoint that boots the scene without Xcode or the host app.

Two caveats from the capture: the skybox rendered black rather than as a sky, and the camera framing clipped both objects. Neither was investigated — the spike asked whether the GPU path works, not whether the scene was composed well. `06-island-scene.md` starts from a real camera and should not inherit the spike's.

### Trap: `flutter run -t` on the module poisons the host app's build

Running an alternate entrypoint in `flutter_module/` rewrites `FLUTTER_TARGET` in the module's generated config:

```
.ios/Flutter/Generated.xcconfig          FLUTTER_TARGET=lib/spike_main.dart
.ios/Flutter/flutter_export_environment.sh
```

`cool-ios`'s Xcode build phase sources that file, so **every Flutter tab in the host app then builds that entrypoint instead of `lib/main.dart`** — tab 3 stops being Flappy Cat and silently becomes whatever you last ran. No error, no warning, and the Xcode build still reports success. This happened during the spike and was caught only because tab 3 visibly showed the 3D scene.

Both files are gitignored, so nothing in version control protects you. After running any alternate entrypoint:

```bash
cd flutter_module && fvm flutter build ios --config-only
grep FLUTTER_TARGET .ios/Flutter/Generated.xcconfig   # must be lib/main.dart
```

Worth adding to the pre-talk checklist in `08-polish.md`: a stale `FLUTTER_TARGET` is exactly the kind of failure that survives a green build and only shows up on stage.

### **Lighting API — what is actually available?**

Far more than this doc feared. The contingency plan is not needed.

- **Directional light — yes, fully controllable.** `DirectionalLight` exposes `direction`, `color`, `intensity`, `castsShadow`, plus cascade count, map resolution, softness, and depth/normal bias. Point, spot, and rect-area lights exist too. Directional and spot cast shadows, with cached shadow tiles for static geometry.
- **Ambient/environment — yes.** `Scene.environmentIntensity`, `SkyEnvironment` (image-based lighting baked live from a sky, with cross-fades), `EnvironmentVolume`, and a default procedural studio environment so an imported model looks right with zero setup.
- **Materials.** `PhysicallyBasedMaterial` is the default and is what an imported `.glb` gets. Unlit and custom `.fmat` materials (fragment *and* vertex stages, with hot reload) are also available.

Three objects wire the sun, sky, and IBL to one source:

```dart
final sky = PhysicalSkySource();
scene.skybox        = Skybox(sky);
scene.skyEnvironment = SkyEnvironment(sky);
scene.sunLight       = SunLight(sky, castsShadow: true);
sky.sunDirection = ...;   // sky, IBL, light colour and shadows all follow
```

### **Day/night approach for tab 5: real directional light.**

Not ambient-plus-shader-sky. `SunLight` re-aims and recolours the directional light from the sky's sun every frame, and `PhysicalSkySource` reddens and dims the sun through atmospheric transmittance near the horizon — so sunset falls out of the physics rather than being hand-faked.

Better still, **`flutter_scene` ships `DayNightCycleComponent`** (`lib/src/kit/environment/`), which is tab 5's slider almost exactly:

```dart
DayNightCycleComponent(
  timeOfDay: 12.0,        // 0..24 — bind the slider straight to this
  timeSpeed: 0.0,         // 0 = presenter-driven, not auto-running
  latitude: 34.0,
  sunLightNode: sunNode,
  skySource: sky,
  targetScene: scene,
)
```

It derives sun direction from time-of-day and latitude and drives sun colour, sun intensity, `environmentIntensity`, and shadow darkness together. `06-island-scene.md` should build on it rather than reinvent a gradient.

### **Surprises, workarounds, version pins that mattered**

1. **The casing trap is real, and confirmed locally.** `/Users/pikmin/fvm/versions/3.47.2/packages/flutter_tools/lib/src/ios/plist_parser.dart:35` declares `kFLTEnableFlutterGpuKey = 'FLTEnableFlutterGpu'` — and *nothing else in flutter_tools references it*. It is dead code with the wrong casing. The embedder's `FLTEnableFlutterGPU` is the only spelling that does anything.

2. **This repo has no `Info.plist`.** It has **`Info-Debug.plist` and `Info-Release.plist`**, selected per configuration. The key went into **both**; a release-only edit would have made the debug build silently fall back. Every later doc that says "add to `cool-ios/cool-ios/Info.plist`" means both files.

3. **The Android key in this doc was wrong. SETTLED — it is `io.flutter.embedding.android.EnableFlutterGPU`.** This doc originally said a bare `EnableFlutterGPU`; flutter_scene's README said the fully-qualified name. `07-android-host.md` resolved it and the snippet above is now corrected.

   Confirmed independently against `bin/cache/artifacts/engine/android-arm64-release/flutter.jar`. `javap -c` on `FlutterEngineFlags$Flag` shows the constructor loading the literal `"io.flutter.embedding.android."` and prepending it to a suffix; the GPU flag's suffix is `"EnableFlutterGPU"`. `FlutterLoader` then calls `metaData.containsKey(metadataKey)` and **skips silently when the key is absent** — no error, no warning, no Flutter GPU.

   So Android has the *same silent-failure shape* as the iOS casing trap: a plausible-looking wrong key costs you a day. Two wrong spellings, two platforms, both silent. Check both against the embedder, never against the docs — including these.

4. **`flutter_scene` ships agent skills.** `dart run flutter_scene:skills` installs guidance for coding assistants. Not installed — offer it to the presenter before `06`.

5. **Bonus capability worth knowing before designing tab 5:** built-in geometry primitives (no assets needed), skinned mesh animation, instancing, automatic LODs, a particle system, post-processing (bloom, fog, god rays, SSR, DoF, tone mapping), and interactive Flutter widgets embedded on 3D surfaces with pointer raycasting.

### Spike artifacts — delete these after `06`

| Path | Note |
|---|---|
| `flutter_module/lib/spike_scene.dart` | throwaway; imported only by the `/spike` branch |
| `flutter_module/assets/models/spike_box.glb` | Khronos `BoxTextured` sample |
| `/spike` branch in `flutter_module/lib/main.dart` | `02-ios-host.md` replaces this dispatch wholesale |
| `THROWAWAY SPIKE` blocks in `cool-ios/cool-ios/ViewController.swift` | marked start/end; `02` deletes them with the file rename |

**Keep** `hook/build.dart`, `flutter_scene_generated/`, the pubspec dependencies, and the two plist keys — those are production wiring, not spike leftovers.

## Acceptance criteria

- [ ] A `.model` renders on screen inside `cool-ios`, from a `FlutterEngineGroup`-spawned engine, in release, on a physical device.
- [ ] `FLTEnableFlutterGPU` is set in the host Info.plist with the correct casing.
- [ ] The "Findings" section above is filled in, including a decision on the day/night approach.
- [ ] Spike code is either deleted or clearly marked throwaway; it is not imported by anything else.

## How to verify

Build `cool-ios` to a physical device in release. Navigate to the spike screen. You should see the model. Then confirm you are genuinely on the GPU path rather than silently falling back: remove the `FLTEnableFlutterGPU` key, rebuild, and confirm it now **fails**. If it renders identically with the key absent, the key is not what is making it work and your conclusion is wrong.

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
<meta-data android:name="EnableFlutterGPU" android:value="true" />
```

Per `engine/src/flutter/shell/platform/android/io/flutter/embedding/engine/FlutterEngineFlags.java:232`, this flag is explicitly **allowed in release mode** and settable via the manifest.

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

> Fill this in when the spike completes. `06-island-scene.md` reads from here.

- **Does `flutter_scene` render in add-to-app + engine group + release + device?** _(pending)_
- **Lighting API — what is actually available?** _(pending)_
- **Day/night approach for tab 5:** real directional light / ambient + shader sky _(pending — pick one)_
- **Surprises, workarounds, version pins that mattered:** _(pending)_

## Acceptance criteria

- [ ] A `.model` renders on screen inside `cool-ios`, from a `FlutterEngineGroup`-spawned engine, in release, on a physical device.
- [ ] `FLTEnableFlutterGPU` is set in the host Info.plist with the correct casing.
- [ ] The "Findings" section above is filled in, including a decision on the day/night approach.
- [ ] Spike code is either deleted or clearly marked throwaway; it is not imported by anything else.

## How to verify

Build `cool-ios` to a physical device in release. Navigate to the spike screen. You should see the model. Then confirm you are genuinely on the GPU path rather than silently falling back: remove the `FLTEnableFlutterGPU` key, rebuild, and confirm it now **fails**. If it renders identically with the key absent, the key is not what is making it work and your conclusion is wrong.

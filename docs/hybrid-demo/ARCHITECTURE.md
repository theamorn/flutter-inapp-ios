# Architecture & Shared Contracts

**This file is the single source of truth for anything two tasks share.** If you are implementing a task doc and need a route name, a channel name, or the engine topology, read it here. Do not invent your own — a mismatched string between the Swift side and the Dart side fails silently at runtime and costs hours.

## Engine topology

```
AppDelegate (iOS) / Application (Android)
  └── FlutterEngineGroup("hybrid-demo")     ← ONE group: shared snapshot, shared GPU context
        ├── engine A   initialRoute "/game"    ← spawned lazily on first tab-3 appearance
        ├── engine B   initialRoute "/glass"   ← spawned lazily on first tab-4 appearance
        └── engine C   initialRoute "/scene"   ← spawned lazily on first tab-5 appearance
```

**Why a group and not three independent engines.** Engines spawned from a `FlutterEngineGroup` share the Dart VM snapshot, the isolate group, and the GPU context with the group's first engine. Independent `FlutterEngine` instances do not — each pays the full startup and memory cost. The group is what makes three simultaneous Flutter tabs affordable, and the difference is a number the presenter quotes on stage.

**Why one engine per tab and not one engine with Dart-side routing.** Each tab keeps its own live state — the game keeps playing, the 3D camera keeps its angle, the glass keeps its slider values. Tab switching is therefore instant with no reload and no state teardown. That "it just stayed where I left it" moment is the demo.

**Why lazy spawning.** Engines are created on a tab's *first* appearance, never up front. This is deliberate and load-bearing: it lets the HUD show the real incremental memory cost of each engine as the presenter taps into it, live. Do not pre-warm engines at launch — it destroys the readout.

### Dart-side dispatch

`flutter_module/lib/main.dart` reads the initial route and branches:

```dart
void main() {
  final route = PlatformDispatcher.instance.defaultRouteName;
  runApp(switch (route) {
    '/game'  => const FlappyCatApp(),
    '/glass' => const LiquidGlassApp(),
    '/scene' => const IslandSceneApp(),
    _        => const StandaloneDevApp(),   // existing demo home
  });
}
```

Route `/` **must keep working** and must keep showing the existing demo home. It is how the module is developed standalone with `flutter run`, without booting Xcode or Gradle. Do not delete or repurpose it.

## Contracts — fixed names

| Thing | Value |
|---|---|
| Engine group name | `hybrid-demo` |
| Route — Flappy Cat (tab 3) | `/game` |
| Route — Liquid Glass (tab 4) | `/glass` |
| Route — Island scene (tab 5) | `/scene` |
| Route — standalone dev home | `/` |
| Existing channel (**keep, do not remove**) | `com.theamorn.flutter` |
| New telemetry channel | `com.theamorn.hybrid/telemetry` |

`com.theamorn.flutter` is the channel from the previous talk, wired in `cool-ios/cool-ios/ViewController.swift` and `flutter_module/lib/main.dart`. It still works and its setup code is the reference pattern for the new channel. Leave it in place.

## Telemetry — the HUD

The HUD is the demo's evidence. It shows two numbers side by side, and is scrupulously honest about what each one measures.

### 1. Host FPS + process memory — measured natively

Owned by the **host app**, never by Flutter. This matters: if Flutter measured its own performance, the audience could reasonably call the meter rigged.

- **iOS** — `CADisplayLink` for frame cadence on the host UI thread; `task_vm_info.phys_footprint` via `task_info()` for memory. `phys_footprint` is the number Xcode's memory gauge shows and the one to quote.
- **Android** — `Choreographer.FrameCallback` for cadence; `Debug.MemoryInfo` / `Debug.getPss()` for memory.

### 2. Flutter UI + raster frame times — reported from Dart

Dart registers `SchedulerBinding.instance.addTimingsCallback` and pushes samples over `com.theamorn.hybrid/telemetry`; the native HUD renders them alongside its own numbers.

Suggested payload (a map, so fields can be added without breaking the native side):

```dart
{
  'route':      '/scene',   // which engine is reporting
  'uiMillis':   4.2,        // FrameTiming.buildDuration,  averaged over the batch
  'rasterMillis': 6.1,      // FrameTiming.rasterDuration, averaged over the batch
  'fps':        118.0,      // derived
}
```

### Why the split is a feature, not a caveat

A native `CADisplayLink` measures the *host's* UI thread. Flutter renders on its own UI and raster threads, so host-side cadence alone would not capture Flutter jank — and claiming otherwise would be dishonest. Showing both numbers is what makes the HUD credible:

- On **tab 2 (WebView)**, WKWebView does its layout and compositing work on the host main thread, so the *host* number visibly janks under scroll. That is the honest demonstration of the WebView ceiling.
- On **tabs 3–5 (Flutter)**, both numbers stay pinned. The Flutter numbers prove Flutter isn't hiding jank on its own threads; the host number proves the native shell stays responsive while Flutter renders.

If the two disagree in a way you cannot explain, **the HUD is wrong and must be fixed before an audience sees it.** See `08-polish.md`.

### Non-negotiable: the ProMotion flag

Add to `cool-ios/cool-ios/Info.plist`:

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

Without it iOS caps the app at 60fps on ProMotion devices. Every "120" claim in the talk silently becomes "60", and the demo undersells exactly the thing it exists to prove.

## Flutter GPU enablement

Required for tab 5 (`flutter_scene`). Full detail and the casing trap are in `01-scene-spike.md`. Summary:

- **iOS** — `FLTEnableFlutterGPU` = `true` in the **host app's** `Info.plist`.
- **Android** — `<meta-data android:name="EnableFlutterGPU" android:value="true" />` in the host manifest.

Neither requires `flutter run --enable-flutter-gpu`, which is what makes add-to-app viable at all.

## Directory layout this plan creates

```
flutter_module/lib/
├── main.dart              ← route dispatch (modified)
├── tabs/
│   ├── game/              ← 04-flappy-cat.md
│   ├── glass/             ← 05-liquid-glass.md
│   └── scene/             ← 06-island-scene.md
└── telemetry/             ← addTimingsCallback → method channel
flutter_module/shaders/
└── liquid_glass.glsl      ← 05-liquid-glass.md

cool-ios/cool-ios/
├── LoginViewController.swift     ← renamed from ViewController.swift
├── MainTabBarController.swift
├── AppEngines.swift
├── FlutterTabViewController.swift
├── PerformanceHUDView.swift
├── HomeViewController.swift
├── SettingsWebViewController.swift
└── Resources/settings.html

cool-android/                     ← new Gradle project, 07-android-host.md
```

Existing files in `flutter_module/lib/` (`app_screen.dart`, `shader_screen.dart`, `game_screen.dart`, and their helpers) stay where they are. They back the `/` standalone dev home and are a source of reusable shader and particle code. Do not refactor them as part of this work.

# Architecture & Shared Contracts

**This file is the single source of truth for anything two tasks share.** If you are implementing a task doc and need a route name, a channel name, or the engine topology, read it here. Do not invent your own — a mismatched string between the Swift side and the Dart side fails silently at runtime and costs hours.

## Engine topology

```
AppEngines.shared (iOS) / AppEngines singleton (Android)
  └── FlutterEngineGroup("hybrid-demo")     ← ONE group: shared snapshot, shared GPU context
        ├── engine A   initialRoute "/game"    ← spawned lazily on first tab-3 appearance
        ├── engine B   initialRoute "/glass"   ← spawned lazily on first tab-4 appearance
        └── engine C   initialRoute "/scene"   ← spawned lazily on first tab-5 appearance
```

This is the iOS topology. Android implements Home and Game only, and lazily creates just the `/game` engine. The other route names are reserved for parity; Android does not expose Glass or Island tabs.

**Why a group.** Group-created engines reuse resources such as the GPU context, font metrics, and isolate group snapshot. Each engine still owns separate Dart application state. The savings depend on the app and device; measure them before quoting a number. See Flutter's [multiple-engine documentation](https://docs.flutter.dev/add-to-app/multiple-flutters).

**Why one engine per tab.** Each tab preserves its state while its engine is alive: the game round, the 3D camera angle, and the glass sliders. Hidden tabs suspend rendering; the game should not progress behind Home. iOS forwards child-controller lifecycle events. Android explicitly pauses the engine when hiding its container because `View.GONE` alone does not pause a Fragment. State is retained across tab switches, not guaranteed across process death.

**Why lazy spawning.** Engines are created on a tab's *first* appearance, never up front. This is deliberate and load-bearing: it lets the HUD show the real incremental memory cost of each engine as the presenter taps into it, live. Do not pre-warm engines at launch — it destroys the readout.

### Dart-side dispatch

`flutter_module/lib/main.dart` reads the initial route and branches:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = PlatformDispatcher.instance.defaultRouteName;
  if (route == '/game' || route == '/glass' || route == '/scene') {
    FrameTelemetryReporter(route).start();
  }
  runApp(switch (route) {
    '/game'  => const FlappyCatApp(),
    '/glass' => const LiquidGlassApp(),
    '/scene' => const IslandSceneApp(),
    _        => const MyApp(),   // existing standalone demo home
  });
}
```

Route `/` **must keep working** and must keep showing the existing demo home. It is how the module is developed standalone with `flutter run`, without booting Xcode or Gradle. Do not delete or repurpose it.

Each feature app creates exactly one initial Navigator route via `onGenerateInitialRoutes`. A native initial route such as `/glass` otherwise overrides `MaterialApp.initialRoute`; a `home:` alone logs an unknown-route error, while resolving both `/` and `/glass` can mount duplicate screens.

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

`com.theamorn.flutter` remains in the standalone home in `flutter_module/lib/main.dart`. The current native login opens the tab shell and does not install the previous talk's counter handler. The old native wiring is preserved in the root README's integration guide; do not claim that the current login demonstrates that exchange.

## Telemetry — the HUD

The native HUD and the page's own meter describe different work. Neither callback cadence nor average frame cost is a count of frames physically presented by the display.

### 1. Host FPS + process memory — measured natively

Owned by the **host app**, never by Flutter. This matters: if Flutter measured its own performance, the audience could reasonably call the meter rigged.

- **iOS** — `CADisplayLink` for frame cadence on the host UI thread; `task_vm_info.phys_footprint` via `task_info()` for memory. `phys_footprint` is the number Xcode's memory gauge shows and the one to quote.
- **Android** — `Choreographer.FrameCallback` for cadence; `Debug.MemoryInfo` / `Debug.getPss()` for memory.

The HUD uses **MiB** (bytes / 1,048,576), identifying iOS footprint and Android PSS. These are different accounting methods, not interchangeable memory benchmarks. iOS host footprint excludes separate WebKit content/network/GPU processes, so it cannot establish WebView's total memory cost. Cadence and memory refresh about once per second; iOS also refreshes memory when its labels update.

### 2. Flutter UI + raster frame times — reported from Dart

Dart registers `SchedulerBinding.instance.addTimingsCallback` and pushes samples over `com.theamorn.hybrid/telemetry`; the native HUD renders them alongside its own numbers.

Method: `reportFrameTimings`. Payload (a map, so fields can be added):

```dart
{
  'route':      '/scene',   // which engine is reporting
  'uiMillis':   4.2,        // FrameTiming.buildDuration,  averaged over the batch
  'rasterMillis': 6.1,      // FrameTiming.rasterDuration, averaged over the batch
  'fps':        118.0,      // vsync intervals / their total elapsed time
}
```

Reports are sent after at least 30 frames or on a 750ms timer when frames are available. UI and raster milliseconds are batch averages; a short stall can be hidden by the average. FPS includes long intervals while active; zero means there is not yet an interval to measure. Lifecycle changes clear the window so time spent hidden is not reported as a slow frame. Native receivers use the channel's owning engine as the route authority. Samples expire after two seconds and are cleared on tab return; native tabs show no active Flutter engine.

### 3. Web page cadence — measured in JavaScript

`settings.html` calculates `requestAnimationFrame` intervals / elapsed time, without a cap, seeded 120fps history, or mode-dependent random values. Labels update at most four times per second. `Intervals >32ms` counts that explicit threshold; it is not a refresh-rate-aware dropped-frame count. `Layout probes` counts the stress loop's work, not WebKit's internal layout passes.

Normal mode and **Stress Test** both use the same meter. Stress Test deliberately adds synchronous layout, blur, and a 16ms busy loop. It illustrates the effect of that workload; it does not establish a universal WebView ceiling. The host suspends the page loop on tab hide, and page visibility changes also reset the measurement window.

### How to interpret the split

A native display callback samples host scheduling. Flutter's UI and platform threads are merged by default on modern iOS/Android Flutter, so “Flutter runs all UI work on a separate thread” is not a valid explanation. Raster timing is still a separate metric. See the [Flutter thread-merge tracking issue](https://github.com/flutter/flutter/issues/150525).

- On **tab 2**, page JavaScript/layout run in a separate WebContent process. Host cadence can stay smooth while page cadence falls. That is expected, not a broken HUD. See [WebKit's process architecture](https://docs.webkit.org/Deep%20Dive/Architecture/WebKit2.html).
- On **tabs 3–5**, compare host cadence and Flutter UI/raster costs during the same action. Low batch averages do not rule out isolated jank; use frame timelines to inspect it. Do not promise “pinned 120” without a device recording.

Investigate unexplained differences in matching time windows before quoting results. See `08-polish.md` for the Instruments/DevTools cross-check.

### Engine spawn readout

Each route shows the difference in **whole-process** memory from just before creation to receipt of its **first telemetry batch**, plus synchronous `makeEngine` / `createAndRunEngine` call duration (`ms create`). This includes concurrent allocations and initial tab assets; it is approximate and can even be negative after reclamation. It is neither isolated engine memory nor time-to-first-visible-frame, and does not mean scene assets have finished loading. Visit tabs one at a time and allow memory to settle before recording subsequent deltas.

### Non-negotiable: the ProMotion flag

Both `cool-ios/cool-ios/Info-Debug.plist` and `Info-Release.plist` contain:

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

The HUD also requests the screen's maximum refresh rate through `preferredFrameRateRange`. The flag permits high-refresh scheduling; it does not guarantee 120fps. Low Power Mode, thermal conditions, display settings, and adaptive refresh affect the result. See Apple's [ProMotion guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays).

## Flutter GPU enablement

Required for tab 5 (`flutter_scene`). Full detail and the casing trap are in `01-scene-spike.md`. Summary:

- **iOS** — `FLTEnableFlutterGPU` = `true` in **both host plists**, `Info-Debug.plist` and `Info-Release.plist`.
- **Android** — `<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true" />` in the host manifest. The bare key is silently ignored. Android reserves this flag for the scene contract even though this host currently exposes only Game.

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

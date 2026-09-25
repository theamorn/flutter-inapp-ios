# Architecture & Shared Contracts

**This file is the single source of truth for anything two tasks share.** If you are implementing a task doc and need a route name, a channel name, or the engine topology, read it here. Do not invent your own — a mismatched string between the Swift side and the Dart side fails silently at runtime and costs hours.

## Engine topology

```
AppEngines.shared (iOS) / AppEngines singleton (Android)
  └── FlutterEngineGroup("hybrid-demo")     ← ONE group: shared snapshot, shared GPU context
        ├── engine A   initialRoute "/game"    ← spawned lazily on first tab-3 appearance
        ├── engine B   initialRoute "/promo"   ← spawned lazily on first tab-4 (Shop) appearance
        └── engine C   initialRoute "/scene"   ← spawned lazily on first tab-5 appearance
```

Both hosts use this topology and expose all five tabs. Tabs 3 and 5 give their engine the whole screen: `FlutterViewController` on iOS, `FlutterFragment` on Android. Tab 4 is different: a native product page with its engine **inline**, as one fixed-height tile in the page's scroll view. See [Inline tile](#inline-tile--route-promo) below.

`/glass` (Liquid Glass, `05-liquid-glass.md`) no longer has a tab. The route and its Dart code stay supported, so tab 4 can go back to Glass with a one-line change in each host's tab list.

**Why a group.** Group-created engines reuse resources such as the GPU context, font metrics, and isolate group snapshot. Each engine still owns separate Dart application state. The savings depend on the app and device; measure them before quoting a number. See Flutter's [multiple-engine documentation](https://docs.flutter.dev/add-to-app/multiple-flutters).

**Why one engine per tab.** Each tab preserves its state while its engine is alive: the game round, the 3D camera angle, and the glass sliders. Hidden tabs suspend rendering; the game should not progress behind Home. iOS forwards child-controller lifecycle events. Android explicitly pauses the engine when hiding its container because `View.GONE` alone does not pause a Fragment. State is retained across tab switches, not guaranteed across process death.

**Why lazy spawning.** Engines are created on a tab's *first* appearance, never up front. This is deliberate and load-bearing: it lets the HUD show the real incremental memory cost of each engine as the presenter taps into it, live. Do not pre-warm engines at launch — it destroys the readout.

### Dart-side dispatch

`flutter_module/lib/main.dart` reads the initial route and branches:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = PlatformDispatcher.instance.defaultRouteName;
  if (route == '/game' ||
      route == '/glass' ||
      route == '/promo' ||
      route == '/scene') {
    FrameTelemetryReporter(route).start();
  }
  runApp(switch (route) {
    '/game'  => const FlappyCatApp(),
    '/glass' => const LiquidGlassApp(),
    '/promo' => const HoloPromoApp(),
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
| Route — Shop promo tile (tab 4) | `/promo` |
| Route — Liquid Glass (no tab; kept supported) | `/glass` |
| Route — Island scene (tab 5) | `/scene` |
| Route — standalone dev home | `/` |
| Existing channel (**keep, do not remove**) | `com.theamorn.flutter` |
| New telemetry channel | `com.theamorn.hybrid/telemetry` |
| Inline promo tile channel | `com.theamorn.hybrid/promo` |

`com.theamorn.flutter` remains in the standalone home in `flutter_module/lib/main.dart`. The current native login opens the tab shell and does not install the previous talk's counter handler. The old native wiring is preserved in the root README's integration guide; do not claim that the current login demonstrates that exchange.

## Inline tile — route `/promo`

Tab 4 is a native product page (UIKit `ProductDetailViewController` / Compose `ShopScreen`) with the `/promo` engine as a 340pt/dp tile halfway down. Flutter draws a holographic badge on a lanyard (Flame, a verlet strap, and `shaders/holo_foil.glsl`). The page owns everything else. Task doc: `09-inline-holo-badge.md`.

**Units.** Everything on this channel is in Flutter logical pixels: iOS points, Android dp. Android converts to pixels with `displayMetrics.density`.

| Direction | Method | Arguments / reply |
|---|---|---|
| native → Dart | `scroll` | `{progress, velocity}`. `progress` is the tile center's offset from the viewport center in half-viewport heights, clamped to ±1.5. `velocity` is the page's content-offset speed, positive toward the end of the page. Sent only while visible, at most once per actual scroll step. |
| native → Dart | `visibility` | `{visible}`: the tile intersects the viewport grown by 120. Sent only on change. |
| Dart → native | `ready` | Reply `{visible, progress}`. Dart **pulls** its starting state, because pushes sent before its handler exists can be dropped. |
| Dart → native | `badgeBounds` | `{x, y, w, h}`: the badge's box in tile coordinates. At most 30 Hz, and only after moving more than 4, so nothing is sent while it hangs still. |
| Dart → native | `claimPromo` | `{code}` when the badge is tapped. The host shows the code in its **native** promo field, validates it, and applies the discount. Flutter never touches the price. |

**Who owns a touch.** A touch that *starts* inside the latest `badgeBounds`, grown by 16, belongs to Flutter, and the page must not scroll. Every other touch scrolls the page, including one on the tile's empty area. On iOS, `ProductScrollView.touchesShouldCancel(in:)` returns false for it, with `delaysContentTouches = false`. On Android, a wrapper view calls `requestDisallowInterceptTouchEvent(true)` on `ACTION_DOWN`, which Compose's `AndroidView` honors.

**Pausing.** The engine spawns on the Shop tab's first appearance, never on scroll-into-view, because engine creation is synchronous. Off-screen pausing goes through `visibility`, not the lifecycle. Dart's `PromoRunGate` runs the game only while the host says the tile is visible **and** the app is in the foreground, because Flame's own background handling would resume a game that is still scrolled away. With the tile off screen, the HUD reads `/promo no recent frames` while host cadence continues.

**Embedding differences.**

- **iOS:** a child `FlutterViewController` in a stack view, never a reused table cell. The scroll view is pinned to the safe area, so the tile's safe-area insets, and therefore Flutter's viewport metrics, never change mid-scroll.
- **Android:** a bare `FlutterView(context, FlutterTextureView(context))` inside a non-lazy `Column`. `TextureView` composites like a normal view, so it clips to rounded corners and moves with Compose scrolling, at the cost of a copy. With no fragment, the host supplies the rest itself:
  - a `PlatformPlugin`, so `HapticFeedback` has a handler;
  - consumed window insets;
  - activity lifecycle and window focus, forwarded to the engine by `TabsActivity`.

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
- **Android** — `<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true" />` in the host manifest. The bare key is silently ignored. Android needs it for the Island tab.

Neither requires `flutter run --enable-flutter-gpu`, which is what makes add-to-app viable at all.

## Directory layout this plan creates

```
flutter_module/lib/
├── main.dart              ← route dispatch (modified)
├── tabs/
│   ├── game/              ← 04-flappy-cat.md
│   ├── glass/             ← 05-liquid-glass.md (route kept, no tab)
│   ├── promo/             ← 09-inline-holo-badge.md
│   └── scene/             ← 06-island-scene.md
└── telemetry/             ← addTimingsCallback → method channel
flutter_module/shaders/
├── liquid_glass.glsl      ← 05-liquid-glass.md
└── holo_foil.glsl         ← 09-inline-holo-badge.md

cool-ios/cool-ios/
├── LoginViewController.swift     ← renamed from ViewController.swift
├── MainTabBarController.swift
├── AppEngines.swift
├── FlutterTabViewController.swift
├── PerformanceHUDView.swift
├── HomeViewController.swift
├── SettingsWebViewController.swift
├── ProductDetailViewController.swift      ← 09: the Shop page + ProductScrollView
├── InlineFlutterCardViewController.swift  ← 09: the /promo tile and its channel
└── Resources/settings.html

cool-android/                     ← new Gradle project, 07-android-host.md
```

Existing files in `flutter_module/lib/` (`app_screen.dart`, `shader_screen.dart`, `game_screen.dart`, and their helpers) stay where they are. They back the `/` standalone dev home and are a source of reusable shader and particle code. Do not refactor them as part of this work.

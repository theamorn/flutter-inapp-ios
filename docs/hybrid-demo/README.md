# The High-Performance Hybrid — Demo App

Build docs for a conference demo. **Read this file and `ARCHITECTURE.md` before touching any task doc.**

## The talk

**"The High-Performance Hybrid — Offloading Complex UI."**

The argument is *not* "rewrite your app in Flutter." It is:

1. **Native is good.** Keep your native app. (Tab 1)
2. **WebView is genuinely the right tool for some screens** — and it has a measurable ceiling. (Tab 2)
3. **Flutter gives you fast development AND high performance**, so you offload the screens native would cost you weeks on. (Tabs 3, 4, 5)

Everything in these docs serves one requirement: **"high performance" must be measurable on a projector, not asserted.** That is the job of the native performance HUD (see `ARCHITECTURE.md`), which is the spine of the whole demo. If a change would weaken or fake the HUD, it is the wrong change.

The predecessor talk is preserved at `flutter_module/lib/couple.md` ("The Power Couple") for tone reference. This demo replaces it.

## Repo inventory

| Path | What it is |
|---|---|
| `cool-ios/` | Native UIKit app. `ViewController.swift` = login form + a button presenting `FlutterViewController`. Storyboard entry point (`Main.storyboard` → `ViewController`). Podfile already wired to `flutter_module` via `podhelper.rb`. |
| `flutter_module/` | Add-to-app Flutter module. Flame 1.30, `flutter_shaders`, five written GLSL shaders (`water`, `sky`, `star`, `flame`, `rain_droplets`), a rain particle system, sprite sheets, and `MethodChannel("com.theamorn.flutter")`. |
| `flutter_native/` | Standalone Flutter app hosting a native camera — the reverse-direction demo from the old talk. **Not touched by this plan.** |
| `cool-android/` | **Does not exist yet.** No native Android host app is in this repo. Built from scratch in `07-android-host.md`. |

Toolchain is **Flutter 3.47.2** (stable, Dart 3.13.2), managed by fvm. Impeller is default on both platforms.

> `.fvmrc` currently pins **3.38.3, which is not installed** — `.fvm/flutter_sdk` is a dangling symlink to a directory that does not exist. The installed cache holds 3.41.1, 3.47.0, and 3.47.2. `00-toolchain.md` fixes this and must run first.

## Decisions already taken

Do not relitigate these. They were settled with the presenter.

| Decision | Choice |
|---|---|
| Android scope | Minimal host: tabs 1 + 3 only (native home + Flutter game) |
| Engine model | `FlutterEngineGroup`, three lazily-spawned engines |
| Tab 4 concept | Liquid Glass panel, touch-driven ripple over the live widget tree |
| Tab 5 concept | Low-poly island, day→night slider, tap-to-move character |
| 3D tech | `flutter_scene` — committed, no fallback |
| Native stack | iOS UIKit (extend what exists) + Android Jetpack Compose |
| Demo devices | Native FPS + memory HUD; live engine-spawn cost readout |

Two devices that were **considered and cut** — do not build them unless the presenter asks: a "reveal the seam" toggle that outlines Flutter-rendered pixels, and a tab-1 segmented control swapping between UIKit and a pixel-identical Flutter implementation.

### On the `flutter_scene` risk

`flutter_scene` depends on `flutter_gpu`, which is experimental. This was flagged; the presenter committed with **no fallback**. Subsequent reading of the 3.47.2 engine source made the risk specific rather than unknown — the add-to-app enablement mechanism exists and is documented in `01-scene-spike.md`. That doc still runs before all other feature work, so anything that does break, breaks in week 1 rather than week 7.

## Task docs

Every task doc uses the same sections: **Goal · Prerequisites · Repo facts you need · Files to create/modify · Implementation notes · Gotchas · Acceptance criteria · How to verify.**

| Doc | Task |
|---|---|
| `ARCHITECTURE.md` | Engine topology, telemetry contract, route + channel names. **Single source of truth for anything two tasks share.** |
| `00-toolchain.md` | SDK bump to 3.47.2 |
| `01-scene-spike.md` | `flutter_scene` / `flutter_gpu` validation |
| `02-ios-host.md` | Login → `UITabBarController`, engine group, HUD |
| `03-native-web.md` | Tab 1 (UIKit) + Tab 2 (WKWebView) |
| `04-flappy-cat.md` | Tab 3 (Flame) |
| `05-liquid-glass.md` | Tab 4 (shader over live widget tree) |
| `06-island-scene.md` | Tab 5 (`flutter_scene`, tap-to-move) |
| `07-android-host.md` | Minimal Compose host, tabs 1 + 3 |
| `08-polish.md` | Stage-readiness |

**Never invent a route name, channel name, or engine name.** Read them from `ARCHITECTURE.md`.

## Order and checkpoints

```
00 → 01 → (02, 03) → 04 → 05 → 06 → 07 → 08
```

Each checkpoint leaves a demo that could be given if the calendar collapsed:

- **After 02 + 03** — iOS shell, two tabs, live HUD. A short version of the talk works from here.
- **After 04** — the "a WebView could never do this" moment lands.
- **After 06** — the finale exists.
- **After 07** — the cross-platform parity claim exists.

## The one rule for verification

**Physical device, release mode.** Simulator results and debug-mode results do not support any claim in this talk. Debug-mode Flutter is several times slower than release and will make the demo look *worse* than it is; the simulator has no Impeller GPU path worth measuring. Every task doc's `How to verify` assumes a real device in release.

# The High-Performance Hybrid — Demo App

Build docs for a conference demo. **Read this file and `ARCHITECTURE.md` before touching any task doc.**

## The talk

**"The High-Performance Hybrid — Offloading Complex UI."** (50-minute Meetup slot — see `docs/presentation/SLIDE_PLAN.md`)

The argument is *not* "rewrite your app in Flutter." It is:

1. **Native is good.** Keep your native app. (Tab 1)
2. **WebView is genuinely the right tool for some screens** — and it has a measurable ceiling. (Tab 2)
3. **Flutter gives you fast development AND high performance**, so you offload the screens native would cost you weeks on. (Tabs 3, 4, 5)

Everything in these docs serves one requirement: **"high performance" must be measurable on a projector, not asserted.** That is the job of the native performance HUD (see `ARCHITECTURE.md`), which is the spine of the whole demo. If a change would weaken or fake the HUD, it is the wrong change.

The predecessor talk is preserved at `flutter_module/lib/couple.md` ("The Power Couple") for tone reference. This demo replaces it.

## Repo inventory

| Path | What it is |
|---|---|
| `cool-ios/` | Native UIKit app. `LoginViewController` opens a five-tab `MainTabBarController`; `AppEngines` lazily owns three Flutter engines and the window-level native HUD displays telemetry. Podfile integrates `flutter_module`. |
| `flutter_module/` | Shared Flutter module: Flame game, Liquid Glass shader, `flutter_scene` island, telemetry, plus the previous standalone home at `/`. |
| `flutter_native/` | Standalone Flutter app hosting a native camera — the reverse-direction demo from the old talk. **Not touched by this plan.** |
| `cool-android/` | Compose Home + cached-engine Flutter Game, native HUD, and a Gradle source integration of the same module. |

Toolchain is **Flutter 3.47.2** (stable, Dart 3.13.2), managed by fvm. Impeller is default on both platforms.

`.fvmrc` now pins **3.47.2**. Run `fvm install` and `fvm flutter pub get` inside the module on a fresh checkout. Task `08` is the current stage: implementation and release builds exist, while physical-device measurements and full stage rehearsal still need to be recorded in [MEASUREMENTS.md](MEASUREMENTS.md).

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

**Physical device, release mode for stage numbers.** Use profile mode for DevTools inspection. Simulator and debug builds are useful for correctness and visual iteration, including the scene, but their performance results do not support device claims. See `ARCHITECTURE.md` for metric limitations and `08-polish.md` for outstanding rehearsal steps. The Web page's synthetic stress is an explicitly injected workload, not a universal WebView ceiling.

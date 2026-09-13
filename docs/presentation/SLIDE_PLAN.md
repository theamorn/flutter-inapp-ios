# Presentation Plan: "The High-Performance Hybrid — Offloading Complex UI"

> **Audience:** iOS & Android Native Mobile Developers  
> **Event:** Mobile Native Meetup  
> **Duration:** 50 minutes (42 min story + demo, 8 min Q&A)  
> **Demo Codebase:** `flutter-inapp-ios` (`cool-ios`, `cool-android`, `flutter_module`)  
> **Speaker materials:** [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md) · [THEORY_BOARDS.md](THEORY_BOARDS.md) · [DEMO_SCRIPT.md](DEMO_SCRIPT.md)

The extra time vs the old 35–40 minute cut goes into **foundation**, not more feature listing. Do not rewrite the app. Do not dump source code. Teach *why* a canvas engine exists, then prove it on the phone.

---

## 0. Locked decisions

Do not relitigate these.

| Decision | Choice |
|---|---|
| Thesis | Native keeps the shell. Flutter is a **guest** — an owned canvas for the screens two GPU pipelines would kill. |
| Open | Greeting → 18 years of native (July 2008 / iPhone 3G / App Store) → replacement stacks failed as *replacements* → Flutter cooperates → this repo cooperates → today is pros, cons, tradeoffs, capability. |
| Login title | **Mobile Native Meetup** (whole line), native UIKit + Compose. |
| Add-to-app | A **pattern**, not a Flutter trademark. Name RN brownfield and Unity as a Library in Act 1, then move. |
| Cons | Spoken after the 20s production names. **No new slide.** |
| AI | No on-device AI tab. Q&A only: AI drafts a second implementation; it does not share a renderer. |
| Demo | Airplane mode, release, native HUD. Ultra: extra props + NPC; no water-bump. Android optional for Home + game only. |
| If over 33:00 | Cut Unity-vs-Flutter comparison first. Then Duo from the cons beat. Keep the 8.3 ms board. |

---

## 1. Narrative arc

```
[Open: 18 years → cooperate, not replace]
        │
[Holy war is the wrong exam question]
        │
[Precedents: Unity in games & WebViews at Meta]
        │
[Safe-to-use names, then Flutter cons]
        │
[Foundation: who owns the pixels + 120 Hz budget]
        │
[Add-to-App, Impeller, FlutterEngineGroup]
        │
[The cancelled-animation heartbreak]
        │
[Live five-tab proof + MethodChannel score]
        │
[Decision matrix, punchline, Q&A]
```

If the room is hungry for theory, steal 2 minutes from demo tab 3. If the room is restless, **cut the Unity-vs-Flutter comparison first** and keep the frame-budget board.

---

## 2. Timing

| Clock | Act | Goal |
|---|---|---|
| 0:00–3:00 | 1 Open | 18 years of native; replace failed; Flutter cooperates |
| 3:00–10:00 | 2 Precedents | Unity + WebView + names + cons |
| 10:00–20:00 | 3 Foundation | Three drawing models + 8.3 ms budget |
| 20:00–28:00 | 4 Add-to-App theory | Engine group, memory, Impeller in one sentence |
| 28:00–33:00 | 5 Heartbreak | Five-beat cancelled-animation story |
| 33:00–45:00 | 6 Live demo | Tabs 1–5 + score back on Home |
| 45:00–50:00 | 7 Close + Q&A | Decision matrix and punchline |

**Rehearsal gate:** Acts 1–5 must finish by **33:00**. Script word counts in [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md) target ~130 words/minute (~3,670 spoken words + ~4:45 stage).

---

## 3. Hard facts cheat sheet

| Topic | Quote these numbers | Source |
|---|---|---|
| Native third-party era | **July 2008:** App Store + iPhone OS 2.0 with iPhone 3G. Original iPhone (2007) was web-apps-only for third parties. Android 1.0 Sept 2008. “Over 18 years” is correct as of 2026. | [Apple, 10 Jul 2008](https://www.apple.com/newsroom/2008/07/10iPhone-3G-on-Sale-Tomorrow/) |
| Unity dominance | >70% of the top 1,000 mobile games | Unity industry reports |
| Dual pipelines | 2x–3x engineering cost | Graphics-team reality, not a lab number |
| Frame budget | 60 Hz = 16.6 ms · **120 Hz = 8.3 ms** | Display timing |
| Flutter HUD | UI + raster batches typically **2–5 ms** | Native HUD on this demo |
| Bundle | ~4–6 MB compressed engine | Flutter add-to-app docs |
| First engine RAM | ~13 MB iOS / ~19 MB Android | Flutter multi-engine benchmarks |
| Extra engine | **~180 KB iOS / ~1.4 MB Android** via `FlutterEngineGroup` | Same |
| Unity as library | 3–6 s load, 50–100 MB+ · one runtime · typically full-screen | Engine telemetry (cut this beat first if over) |
| Flutter spawn | Hundreds of ms cold, ~5–15 ms cached spawn | Demo + docs |
| Add-to-app is not unique | React Native: official [Integration with Existing Apps](https://reactnative.dev/docs/integration-with-existing-apps); Expo brownfield (integrated + isolated AAR/XCFramework). Unity as a Library. WebView. Distinctive here: owned canvas + `FlutterEngineGroup`. | RN docs; Expo brownfield; Unity UaaL |
| Flutter in the wild (20 seconds, then stop) | Apptopia via Flutter/Google: ~**10% → ~30%** of tracked free iOS apps (2021→2024). Names only: BMW, Alibaba Xianyu, Google Pay, NotebookLM, eBay Motors, Nubank, Toyota infotainment, LG webOS. Do **not** quote unofficial “500k Play apps” counts. | [I/O 2025](https://flutter.dev/blog/dart-flutter-momentum-at-google-i-o-2025), [Production era](https://developers.googleblog.com/celebrating-flutters-production-era/) |
| Flutter cons (~60–90s, no new slide) | **iOS 26:** Flutter *runs* on it. Missing is Cupertino / Liquid Glass parity ([flutter#170310](https://github.com/flutter/flutter/issues/170310)), not the OS target. Wait or fake; not Settings. **Duo:** layout reflow is fine; `AppBar` / `CupertinoNavigationBar` will not go vertical like Apple chrome. `displayFeatures` is Android-shaped / empty on Duo. **Compress:** Dart `image` is ~20–35× slower than `libjpeg-turbo`. Isolates ≠ speed. Call the platform. | Official iOS 26 docs; Apple Duo chrome; speaker KBTG / `theamorn/flutter-rust-image` |

Do not invent HUD numbers on stage. Read what the phone shows. Do not linger on the adoption names — two logos + the 10%→30% line is enough. After the names, spend one breath on the tax, then leave Flutter-as-product.

---

## 4. Act-by-act beats

### Act 1 — Open (0:00–3:00)

Greeting, then the 18-year beat:

> July 2008: iPhone 3G, App Store, third-party native apps. Over 18 years of stacks tried to *replace* native. None replaced the shell. Performance is why the replacement religion dies.

Do **not** say “none of those ever works.” RN, Flutter, and Unity ship. They failed as replacements. They succeed as guests.

> Flutter is not here to compete with native. It is here to cooperate with it.

Add-to-app is a pattern, not a Flutter trademark. Name React Native brownfield and Unity as a Library in one breath, then land: this repo’s login, tabs, and HUD stay native. Today is pros, cons, tradeoffs, capability.

Show of hands: “Who shipped a proud iOS animation and then heard *how long for Android?*”

Land with: I am not here to tell you to rewrite your native app.

### Act 2 — Precedents (3:00–10:00)

Holy war is the wrong question. The waste is duplicating custom graphics twice.

**Unity:** Apple has Metal/SceneKit; Google has Vulkan/Filament; still >70% of top mobile games use one engine.

**WebView:** Settings, Help, legal. Concede this hard. Right tool when copy changes weekly.

**Missing middle:** Native is too expensive for identical canvas work. WebView has a ceiling. Where do mini-games, liquid glass, and a 3D island go?

**Safe-to-use, then stop:** Apptopia 10%→30% of tracked free iOS apps. BMW, Google Pay, Xianyu.

**Cons, then stop (~60–90s, no new slide):** Flutter is not free and not everything. iOS 26: runs; Cupertino ≠ Liquid Glass. Duo: layout stretches, `AppBar` stays on top. Compress: codec tax — call native. Closer: Swift/Kotlin vs C++ — pick the layer. Then back to architecture — this is not a Flutter keynote.

If over: cut Duo first. Keep Liquid Glass + “call the platform” + the C++ closer.

### Act 3 — Foundation (10:00–20:00)

Whiteboard / theory slides only. No code.

1. **Three ways a mobile screen draws** — platform widgets, Web DOM, owned canvas.
2. **Frame budget** — 8.3 ms at 120 Hz; UI thread + Raster/Impeller; HUD is native-owned.
3. **Identical pixels is an architecture choice** — two teams, two bugs, two “looks close enough.”

Stop. Do not explain Impeller internals yet.

### Act 4 — Add-to-App (20:00–28:00)

Myth: rewrite the app. No. Flutter is a lazily spawned view. Callback: OS chrome and codecs stay native.

This repo: one `FlutterEngineGroup("hybrid-demo")`, engines on first visit (`/game`, `/glass`, `/scene`), hidden tabs pause rendering.

Quote the cost table once, then move. Impeller in one sentence: shaders compile AOT to Metal/Vulkan, so the flame dissolve does not hitch on first death.

Leave the Native / WebView / Flutter cheat sheet up.

### Act 5 — Heartbreak (28:00–33:00)

Five beats, not a slide dump:

1. Design ships a physics-heavy interaction  
2. iOS spends two weeks in Core Animation  
3. Android: three sprints, maybe jank  
4. PM: cut it, make a static card  
5. App gets boring  

Punch: build that interaction once on the canvas; keep login and Home native.

### Act 6 — Demo (33:00–45:00)

See [DEMO_SCRIPT.md](DEMO_SCRIPT.md). Airplane mode. Release. Native HUD visible.

### Act 7 — Close (45:00–50:00)

Decision matrix. Punchline:

> Software engineers solve problems with software. If the tool helps the user, use it.

Expected Qs: binary size, KMP/CMP, can we delete Flutter later, 3D on older phones, **“why not AI-port iOS to Android?”**, iOS 26 / Liquid Glass, iPhone Duo, image compress, **“can’t React Native do add-to-app too?”**

One-breath counters (full wording in [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md)):

| Q | Say |
|---|---|
| AI-port iOS → Android? | AI drafts a second implementation. It cannot share a renderer or an 8.3 ms budget. Use AI to write the *one* canvas. |
| iOS 26 / Liquid Glass? | Flutter runs. Gap is Cupertino visual parity, not the OS target. Wait or fake. Not Settings. |
| iPhone Duo? | Layout reflow is fine. Apple chrome goes vertical; a Flutter `AppBar` will not. Detect or wait. Flutter still runs. |
| Image compress? | Dart `image` ≠ `libjpeg-turbo`. Isolates fix jank, not speed. Call the platform. |
| RN add-to-app? | Yes — official brownfield. Unity as a Library too. Which guest: native widgets + JS, a 50 MB game engine, or an owned canvas with cheap extra engines. |

---

## 5. What not to say or spend time on

- Line-by-line Dart, Swift, or Gradle
- Flutter widget catalog
- The cancelled “seam outline” / pixel-identical Home experiment
- Toolchain archaeology (fvm, 3.47.2) unless someone asks
- A dedicated “cons of Flutter” slide — speak it after the names, then leave
- An on-device AI tab
- Unofficial “500k Play apps” counts
- Invented HUD numbers
- **Wrong:** “Flutter doesn’t support iOS 26 / Duo / image compress”
- **Wrong:** “Only Flutter can add-to-app”
- **Wrong:** “None of those cross-platform stacks ever worked” — they failed as *replacements*

---

## 6. Speaker prep

- [ ] ProMotion iPhone, release, `CADisableMinimumFrameDurationOnPhone`, `FLTEnableFlutterGPU`
- [ ] Airplane mode
- [ ] Optional Android for Home + Flappy Cat parity only
- [ ] Dry-run Acts 1–5 to 33:00 using [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md)
- [ ] Walk [DEMO_SCRIPT.md](DEMO_SCRIPT.md) once on the device you will present
- [ ] If names run long: Apptopia 10%→30% + BMW + Google Pay only
- [ ] If cons run long: cut Duo first

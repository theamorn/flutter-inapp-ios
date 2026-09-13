# Presentation Plan: "The High-Performance Hybrid — Offloading Complex UI"

> **Audience:** iOS & Android Native Mobile Developers  
> **Event:** Mobile Native Meetup  
> **Duration:** 50 minutes (42 min story + demo, 8 min Q&A)  
> **Demo Codebase:** `flutter-inapp-ios` (`cool-ios`, `cool-android`, `flutter_module`)  
> **Speaker materials:** [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md) · [THEORY_BOARDS.md](THEORY_BOARDS.md) · [DEMO_SCRIPT.md](DEMO_SCRIPT.md)

The extra time vs the old 35–40 minute cut goes into **foundation**, not more feature listing. Do not rewrite the app. Do not dump source code. Teach *why* a canvas engine exists, then prove it on the phone.

---

## 1. Narrative arc

```
[Open and defuse]
        │
[Holy war & binary mindset]
        │
[Precedents: Unity in games & WebViews at Meta]
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
| 0:00–3:00 | 1 Open and defuse | Line one kills the rewrite-your-app fear |
| 3:00–10:00 | 2 Precedents | Unity + WebView prove teams already pick tools |
| 10:00–20:00 | 3 Foundation | Three drawing models + 8.3 ms budget |
| 20:00–28:00 | 4 Add-to-App theory | Engine group, memory, Impeller in one sentence |
| 28:00–33:00 | 5 Heartbreak | Five-beat cancelled-animation story |
| 33:00–45:00 | 6 Live demo | Tabs 1–5 + score back on Home |
| 45:00–50:00 | 7 Close + Q&A | Decision matrix and punchline |

**Rehearsal gate:** Acts 1–5 must finish by **33:00**. Script word counts in [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md) target ~130 words/minute.

---

## 3. Hard facts cheat sheet

| Topic | Quote these numbers | Source |
|---|---|---|
| Unity dominance | >70% of the top 1,000 mobile games | Unity industry reports |
| Dual pipelines | 2x–3x engineering cost | Graphics-team reality, not a lab number |
| Frame budget | 60 Hz = 16.6 ms · **120 Hz = 8.3 ms** | Display timing |
| Flutter HUD | UI + raster batches typically **2–5 ms** | Native HUD on this demo |
| Bundle | ~4–6 MB compressed engine | Flutter add-to-app docs |
| First engine RAM | ~13 MB iOS / ~19 MB Android | Flutter multi-engine benchmarks |
| Extra engine | **~180 KB iOS / ~1.4 MB Android** via `FlutterEngineGroup` | Same |
| Unity as library | 3–6 s load, 50–100 MB+ | Engine telemetry (cut this beat first if over) |
| Flutter spawn | Hundreds of ms cold, ~5–15 ms cached spawn | Demo + docs |

Do not invent HUD numbers on stage. Read what the phone shows.

---

## 4. Act-by-act beats

### Act 1 — Open (0:00–3:00)

Say this first, out loud:

> I am not here to tell you to rewrite your native app in Flutter.

Native keeps the shell: login, tabs, Home, HealthKit, Bluetooth. Today is the screens that make two platform teams cry: games, shaders, 3D.

Show of hands: “Who shipped a proud iOS animation and then heard *how long for Android?*”

### Act 2 — Precedents (3:00–10:00)

Holy war is the wrong question. The waste is duplicating custom graphics twice.

**Unity:** Apple has Metal/SceneKit; Google has Vulkan/Filament; still >70% of top mobile games use one engine.

**WebView:** Settings, Help, legal. Concede this hard. Right tool when copy changes weekly.

**Missing middle:** Native is too expensive for identical canvas work. WebView has a ceiling. Where do mini-games, liquid glass, and a 3D island go?

### Act 3 — Foundation (10:00–20:00)

Whiteboard / theory slides only. No code.

1. **Three ways a mobile screen draws** — platform widgets, Web DOM, owned canvas.
2. **Frame budget** — 8.3 ms at 120 Hz; UI thread + Raster/Impeller; HUD is native-owned.
3. **Identical pixels is an architecture choice** — two teams, two bugs, two “looks close enough.”

Stop. Do not explain Impeller internals yet.

### Act 4 — Add-to-App (20:00–28:00)

Myth: rewrite the app. No. Flutter is a lazily spawned view.

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

Expected Qs: binary size, KMP/CMP, can we delete Flutter later, 3D on older phones.

---

## 5. What not to spend time on

- Line-by-line Dart, Swift, or Gradle
- Flutter widget catalog
- The cancelled “seam outline” / pixel-identical Home experiment
- Toolchain archaeology (fvm, 3.47.2) unless someone asks

---

## 6. Speaker prep

- [ ] ProMotion iPhone, release, `CADisableMinimumFrameDurationOnPhone`, `FLTEnableFlutterGPU`
- [ ] Airplane mode
- [ ] Optional Android for Home + Flappy Cat parity only
- [ ] Dry-run Acts 1–5 to 33:00 using [SPEAKER_SCRIPT.md](SPEAKER_SCRIPT.md)
- [ ] Walk [DEMO_SCRIPT.md](DEMO_SCRIPT.md) once on the device you will present

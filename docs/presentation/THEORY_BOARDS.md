# Theory boards — draw these, do not code them

Three boards for Act 3 (10:00–20:00) and the engine-group diagram for Act 4 (20:00–28:00). Use a whiteboard, or the matching slides in `index.html` / `SLIDES.md`.

---

## Board 1 — Three ways a mobile screen draws

```text
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│  1. Platform widgets│   │  2. Web document    │   │  3. Owned canvas    │
│  UIKit / Compose    │   │  DOM + compositor   │   │  UIView / Surface   │
│                     │   │                     │   │                     │
│  OS owns layout,    │   │  Great for copy     │   │  You paint every    │
│  a11y, look         │   │  that changes weekly│   │  pixel (Unity,      │
│                     │   │                     │   │  custom Metal,      │
│  Login, Home, forms │   │  Weak at 120 fps    │   │  Flutter Add-to-App)│
│                     │   │  physics / shaders  │   │                     │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
```

Say: Flutter Add-to-App is column 3. *Give me a canvas.*

---

## Board 2 — Frame budget

```text
  60 Hz   ──────── 16.6 ms per frame
 120 Hz   ────────  8.3 ms per frame   ← ProMotion budget

  Flutter (inside the native window)
    UI isolate     layout, widgets, game tick
    Raster         Impeller → Metal (iOS) / Vulkan (Android)
                   both must finish inside 8.3 ms

  HUD (owned by the host, not by Flutter)
    CADisplayLink / Choreographer     host cadence
    task_info / Debug.getPss          process memory
    MethodChannel timings             UI + raster batches only
```

Say: if Flutter graded itself, you would be right to call the meter rigged.

---

## Board 3 — Identical pixels is architecture

```text
  Two teams, one shader
        │
        ├── iOS Metal implementation
        └── Android AGSL / RenderNode "equivalent"
                │
                ▼
        two bugs + "looks close enough"

  One owned canvas
        │
        └── one picture on both phones
            (how game studios already work)
```

Stop. Do not open Impeller internals on this board.

---

## Board 4 — FlutterEngineGroup (Act 4)

```text
  Native window + native HUD
            │
            ├── Tab 1  UIKit / Compose Home
            ├── Tab 2  WKWebView settings
            └── FlutterEngineGroup("hybrid-demo")
                    ├── engine A   /game    first visit to tab 3
                    ├── engine B   /glass   first visit to tab 4
                    └── engine C   /scene   first visit to tab 5

  Lazy spawn: HUD can show the incremental memory cost live.
  Hidden tabs pause rendering: Flappy Cat must not run behind Home.
```

Quote once, then move:

| Cost | Number |
|---|---|
| Compressed engine in the bundle | ~4–6 MB |
| First engine RAM | ~13 MB iOS / ~19 MB Android |
| Extra engine in the group | ~180 KB iOS / ~1.4 MB Android |
| Impeller | AOT to Metal/Vulkan — no first-death hitch |

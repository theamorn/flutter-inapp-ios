---
marp: true
theme: default
paginate: true
header: "The High-Performance Hybrid: Offloading Complex UI"
footer: "Mobile Native Meetup"
style: |
  section {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    font-size: 26px;
    padding: 40px;
  }
  h1 {
    color: #0b57d0;
  }
  h2 {
    color: #1a73e8;
  }
  code {
    background-color: #f1f3f4;
    color: #d93025;
  }
  .highlight {
    background-color: #e8f0fe;
    padding: 10px;
    border-left: 5px solid #1a73e8;
    border-radius: 4px;
  }
  .stats-box {
    display: flex;
    justify-content: space-between;
    margin: 20px 0;
  }
  .stat-card {
    background: #f8f9fa;
    border: 1px solid #dadce0;
    border-radius: 8px;
    padding: 16px;
    width: 30%;
    text-align: center;
  }
  .stat-num {
    font-size: 36px;
    font-weight: bold;
    color: #1a73e8;
  }
---

# The High-Performance Hybrid
## Offloading Complex UI Without Rewriting Your App

**Speaker:** [Your Name]  
**Topic:** Pragmatic Mobile Architecture & Add-to-App  
**Target:** iOS & Android Native Developers  

<!-- 
Presenter Notes:
- Greeting. Native is a little over 18 years old: July 2008, iPhone 3G, App Store.
- Lots of stacks tried to replace native. They failed as replacements (do not say “none ever worked”). Performance is the reason people remember.
- Flutter cooperates with native; this repo does too. Add-to-app is also React Native brownfield and Unity as a Library.
- Land with: I am NOT here to tell you to rewrite your native app. Today is pros, cons, tradeoffs, capability.
-->

---

## The Eternal Holy War

```
  ┌─────────────────────────┐          ┌─────────────────────────┐
  │      TEAM NATIVE        │   VS     │   TEAM CROSS-PLATFORM   │
  │  "100% Swift / Kotlin"  │          │ "Rewrite everything!"   │
  │  Flawless performance   │          │ Single codebase promise │
  │  Deep system APIs       │          │ Compromised fidelity?   │
  └─────────────────────────┘          └─────────────────────────┘
```

- For a decade, mobile architecture has been treated as an **all-or-nothing religion**.
- Either you commit to dual native teams, or you rewrite your entire company's app in a cross-platform framework.
- **The reality on the ground:**
  - Product teams want features delivered *yesterday*.
  - Design teams want pixel-perfect, identical animations and custom UI across both iOS & Android.
  - Engineering teams are stuck duplicating complex pixel code twice.

<!-- 
Presenter Notes:
- Ask the room for a show of hands: "Who here has built a complex, custom animation in Swift/CoreAnimation, felt super proud of it, and then the product manager asked: 'Awesome! How long until it's on Android?'"
- Hands will go up. 
- That feeling—effort duplication and keeping complex graphics in sync—is the real pain point.
-->

---

## Precedent 1: Mobile Gaming
### Why Does Unity Own Mobile Games?

<div class="stats-box">
  <div class="stat-card">
    <div class="stat-num">&gt; 70%</div>
    <p>of the top 1,000 mobile games are built on Unity</p>
  </div>
  <div class="stat-card">
    <div class="stat-num">Apple</div>
    <p>SceneKit, SpriteKit, Metal, RealityKit</p>
  </div>
  <div class="stat-card">
    <div class="stat-num">Google</div>
    <p>Vulkan, OpenGL ES, Filament</p>
  </div>
</div>

- Apple and Google have provided world-class native graphics frameworks for years.
- **Why did native game frameworks lose?**
  - Building custom rendering pipelines, physics, and shaders twice is **2x–3x the engineering cost**.
  - Studios gladly trade off a ~20MB runtime for **one unified, deterministic rendering engine**.

<!-- 
Presenter Notes:
- Point to the 70% stat. This is an indisputable industry fact.
- Why didn't game studios write their games in Swift + Metal for iOS and Kotlin + Vulkan for Android?
- Because game studios understand that custom rendering across platforms is a nightmare to duplicate.
- They accepted an embedded runtime because the ROI was undeniable.
-->

---

## Precedent 2: The Practical Shortcut
### Why Does Meta (Facebook) Use WebViews?

- Look inside the Facebook, Instagram, or Amazon native apps:
  - Settings screens
  - Help Centers & Support
  - Terms of Service & Privacy Policies
- **Why WebViews?**
  - Requirements change weekly without app store reviews.
  - Zero requirement for 120fps fluid physics or custom shaders.
  - Building two separate native table/view hierarchies for static legal text is poor resource allocation.
- **The Lesson:** Mature engineering teams already choose the right tool for the right screen.

<!-- 
Presenter Notes:
- Conceding WebViews is essential. WebViews are NOT evil; they are a valid engineering choice for text-heavy, dynamic screens.
- But WebViews have a very hard performance ceiling.
- What happens when the design team asks for a fluid mini-game, a custom shader effect, or 3D product view? A WebView collapses.
-->

---

## The Missing Middle

| Solution | Strengths | Where It Breaks Down |
|---|---|---|
| **Pure Native** (Swift / Kotlin) | Peak OS integration, zero bridge overhead, system widgets | **2x–3x effort** for complex identical canvas/shaders/3D; dual bug surface |
| **WebView** (WebKit) | Dynamic updates, shared web code | Severe performance ceiling under heavy animation; layout thrashing, DOM overhead |
| **The Pragmatic Hybrid** *(Add-to-App)* | **120fps hardware rendering**, identical pixels, 50%–70% less graphics code | Small binary & initial memory increment |

> **"Don't replace your native foundation. Offload the screens that would cost you weeks of duplicate native effort."**

<!-- 
Presenter Notes:
- Introduce the thesis clearly.
- If you have an ordinary form, a navigation stack, a login screen, or widgets: Keep them native!
- But if you have an interactive promo, an in-app game, a liquid glass shader, or a 3D visualizer: why duplicate that in Metal and Vulkan?
- Offload it to a dedicated rendering engine inside your native app!
-->

---

## Foundation: Three Ways a Screen Draws

| Model | Who owns the pixels | Use it for |
|---|---|---|
| **Platform widgets** | OS (UIKit / Compose) | Login, Home, forms, a11y |
| **Web document** | DOM + compositor | Legal, FAQ, CMS |
| **Owned canvas** | You paint a `UIView` / `Surface` | Games, shaders, 3D |

Flutter Add-to-App is column 3: *give me a canvas.* Do not put a form on a canvas.

<!--
Presenter Notes:
- This is the 10-minute foundation block. Whiteboard it if you can.
- Accessibility is why login stays native.
-->

---

## Foundation: The 8.3 ms Budget

- 60 Hz = 16.6 ms. **120 Hz ProMotion = 8.3 ms.**
- Two Flutter clocks: **UI isolate** (layout, game tick) and **Raster** (Impeller → Metal / Vulkan).
- HUD is **native-owned** (`CADisplayLink` / `Choreographer` + memory). Flutter only reports UI/raster batches.

> If Flutter graded itself, you would be right to call the meter rigged.

<!--
Presenter Notes:
- Jank is two diseases. Read both clocks.
- Users feel the worst frame, not the mean. Say "average" when you quote the HUD.
-->

---

## Foundation: Identical Pixels Is Architecture

- Two teams, two shaders → two bugs and “looks close enough.”
- One owned canvas → one picture. That is how game studios already work.
- Stop before Impeller internals.

---

## What Does Offloading Actually Cost?
### Addressing the Native Developer's Concerns

1. **"Isn't the binary size huge?"**
   - Flutter engine adds ~4MB–6MB compressed to your native bundle.
2. **"Doesn't running an engine consume 50MB–100MB of RAM?"**
   - A standalone engine takes ~13MB (iOS) to ~19MB (Android).
   - **`FlutterEngineGroup`:** Shares isolate group snapshot, GPU context, and font metrics.
   - Subsequent engines cost only **~180 KB on iOS** and **~1.4 MB on Android**!
3. **"What about shader stutter (Jank)?"**
   - Impeller compiles GLSL shaders Ahead-Of-Time (AOT) to Metal (iOS) and Vulkan (Android).
   - Zero runtime shader compilation hitching.

<!-- 
Presenter Notes:
- This is where you address the technical myths.
- Many native developers think of Flutter from 2019: Skia runtime shader jank and huge memory overhead.
- Flutter in 2026 runs Impeller (Metal on iOS, Vulkan on Android) with AOT shader precompilation.
- And with FlutterEngineGroup, you can lazily spawn multiple engine instances for tabs or modal sheets for a fraction of a megabyte each.
-->

---

## The Testbed App Architecture

```
                       ┌────────────────────────┐
                       │   Native App Window    │
                       │ (Native Telemetry HUD) │
                       └──────────┬─────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
         ▼                        ▼                        ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────────┐
│  Tab 1: Native   │    │   Tab 2: Web     │    │  Tabs 3, 4, 5:       │
│  UIKit / Compose │    │    WKWebView     │    │  FlutterEngineGroup  │
│  (120fps Baseline│    │ (Settings page + │    │  ├── /game  (Flame)  │
│   Highest Score) │    │  Stress Test)    │    │  ├── /glass (Shader) │
└──────────────────┘    └──────────────────┘    │  └── /scene (3D GPU) │
                                                └──────────────────────┘
```

- **The Native HUD:** Pinned to `UIWindow` / Android DecorView.
  - Native `CADisplayLink` / `Choreographer` (Host FPS).
  - Native `task_info()` / `Debug.getPss()` (Process Memory in MiB).
  - Telemetry MethodChannel: Batch-averaged Flutter UI & Raster frame timings.
- **Engine group:** `FlutterEngineGroup("hybrid-demo")` lazily spawns `/game`, `/glass`, `/scene` on first tab visit. Hidden tabs pause rendering.

<!-- 
Presenter Notes:
- Introduce the demo app architecture.
- Emphasize the Native HUD: "I know you wouldn't believe me if Flutter reported its own numbers. 
  So the host UIKit app owns the HUD. It measures CADisplayLink and iOS task_vm_info.phys_footprint natively. 
  Flutter only reports its internal UI/Raster timing batches."
-->

---

## Live Demo: Tab 1 — Pure Native
### The Baseline We Must Never Ruin

- **Screen:** Native `HomeViewController` (UIKit / Jetpack Compose).
- Standard native components: `UITableView`, `UISegmentedControl`, `UISwitch`.
- **The Point:**
  - Pinned at **120 fps** ProMotion.
  - Low memory footprint (~35–45 MiB).
  - **Verdict:** Never rewrite this screen in cross-platform. It is already perfect.

*(Live Switch to Phone: Show Tab 1 scrolling and HUD readouts)*

<!-- 
Presenter Notes:
- Switch to the live phone screen.
- Scroll hard on Tab 1. Show that host CADisplayLink sits at 120fps.
- Reiterate: "This is what native does best. Fast, accessible, platform-native gestures. Don't touch it."
-->

---

## Live Demo: Tab 2 — WKWebView
### The Right Tool... Until You Hit the Ceiling

- **Screen:** Local bundled `settings.html` running in `WKWebView`.
- **Normal Web Mode:**
  - Fast, responsive text settings. Legitimate engineering choice.
- **Stress Test Mode (Heavy layout + blur + JS loop):**
  - Watch the page cadence drop to 30–40 fps.
  - WebKit content process desyncs from the native host UI thread.
  - **Verdict:** WebViews fail when you need demanding animations or custom canvas interactions.

*(Live Demo: Toggle Stress Test, watch the page drop frames)*

<!-- 
Presenter Notes:
- Switch to Tab 2.
- Explain: "We bundle the HTML locally—airplane mode safe."
- First show Normal mode: It scrolls smoothly! Concede that for settings, web is great.
- Now toggle 'Stress Test' (which adds real-world composite filters and layout thrashing).
- Point to the page meter vs native HUD: The page drops frames, stuttering under touch.
- "So what do we do when product demands a complex interactive feature that a WebView can't handle?"
-->

---

## Live Demo: Tab 3 — Flappy Cat (2D Game)
### 120fps Physics & Particles with Flame

- **Route:** `/game` (lazily spawned from `FlutterEngineGroup`).
- **Under the hood:**
  - 2D Flame game engine with collision detection & sprite animations.
  - Background: GLSL fragment shader (`shaders/sky.glsl`).
  - Death effect: Dissolve fragment shader (`shaders/flame.glsl`).
- **Telemetry Check:**
  - Host FPS: **120 fps** ProMotion.
  - Flutter UI Batch: **~2.1 ms** | Raster Batch: **~3.4 ms** (Budget: 8.3ms).
  - Incremental Memory: **~2–4 MiB**.

*(Live Demo: Play Flappy Cat, flap past pipes, trigger death shader)*

<!-- 
Presenter Notes:
- Switch to Tab 3.
- Flap through a couple of pipes!
- Point to the HUD: 120fps host cadence, UI and Raster both well below the 8.3ms frame deadline.
- Deliberately die: Watch the flame dissolve shader ignite without a single dropped frame.
- "Could a WebView do this at 120fps? No. Could you write it in SpriteKit? Yes. But now do you want to rewrite it from scratch in Android Canvas or C++?"
-->

---

## Live Demo: Tab 4 — Liquid Glass
### Shaders Over the Live Native Widget Tree

- **Route:** `/glass`
- **The Concept:** Apple's Liquid Glass aesthetic, implemented once in GLSL.
- **Why It's Hard in Native:**
  - In UIKit: Refracting a live scrolling view hierarchy requires private APIs or offscreen render passes that crush framerates.
  - In Android: No native equivalent API exists; you have to hand-roll custom RenderNodes.
- **In Flutter:**
  - `AnimatedSampler` captures the **live, scrolling widget tree** each frame.
  - GLSL fragment shader displaces UVs with SDF refraction, chromatic aberration, and touch ripples.

*(Live Demo: Drag ripple while scrolling the list beneath the glass)*

<!-- 
Presenter Notes:
- Switch to Tab 4.
- Show the scrolling list behind the glass. Notice how the text and cards visibly refract through the rounded glass lens.
- Touch the glass: Drag a finger across it to send dynamic ripples propagating across the surface.
- Sweep the sliders: refraction strength, thickness, day/night tint.
- Check the HUD: Host is still at 120fps!
- "This runs identically on Android. One shader file, one codebase, zero duplicate platform graphics code."
-->

---

## Live Demo: Tab 5 — 3D Island Scene
### `flutter_scene` + `flutter_gpu`

- **Route:** `/scene`
- Low-poly 3D world with CC0 3D models (`.glb` converted via build hooks).
- **Interactive Features:**
  - Orbit camera with smooth inertia.
  - Real-time Day $\rightarrow$ Night ambient light transitions.
  - **Tap-to-Move:** Screen-space raycasting intersects ground plane `y=0`; character unprojects and navigates in real-time.
- **The Takeaway:**
  - Full 3D scene graph embedded in a native tab.
  - No 100MB Unity binary penalty; instant launch.

*(Live Demo: Orbit island, change day/night, tap to make character walk)*

<!-- 
Presenter Notes:
- Switch to Tab 5.
- Orbit around the low-poly island.
- Drag the Day/Night slider to show dynamic lighting and shadow shifts.
- Tap on different parts of the island: The raycaster projects the touch into 3D world space and the character walks there.
- Ultra: extra props + wandering NPC. Water bump is off so the phone stays live on stage.
- "This is running directly on the GPU via Flutter's low-level graphics pipeline. 
  Inside your native iOS app, without importing Unity, Unreal, or maintaining separate SceneKit and Vulkan codebases."
-->

---

## The Walled Garden Myth
### Two-Way Communication via Platform Channels

```dart
// Flutter side: lib/tabs/game/game_app.dart
void _reportScore(int score) {
  _gameChannel.invokeMethod('reportScore', {'score': score});
}
```

```swift
// Native iOS side: cool-ios/HomeViewController.swift
private var highestScoreRow: Row {
    let score = GameScoreManager.shared.highestScore
    return Row(
        title: "Highest Score: \(score)",
        subtitle: "Flappy Cat",
        symbol: "gamecontroller.fill",
        kind: .value("\(score)")
    )
}
```

- Flutter is **never a dead-end island**.
- Scores, auth tokens, navigation intents, and analytics flow back and forth with microsecond latency.

<!-- 
Presenter Notes:
- Switch from Tab 3 (Game) back to Tab 1 (Native Home).
- Point to the 'Highest Score' row in the native UIKit table.
- "When I scored 5 points in Flappy Cat, Flutter invoked a MethodChannel. 
  The native Swift GameScoreManager caught it, stored it in UserDefaults, and updated the UIKit table view.
  It is a first-class citizen inside your native view hierarchy."
-->

---

## The Cold Hard Numbers

| Metric | Standalone Flutter Engine | `FlutterEngineGroup` (Our Demo) |
|---|---|---|
| **Base Engine RAM** | ~13 MB (iOS) / ~19 MB (Android) | Shared isolate & GPU context |
| **Incremental Engine RAM** | ~13 MB each | **~180 KB (iOS)** / **~1.4 MB (Android)** |
| **Engine Spawn Time** | ~50–100 ms | **~5–15 ms** (synchronous call) |
| **Frame Timings** | N/A | **2–5 ms** UI/Raster batch averages |
| **Development Velocity** | 1x (if rewriting whole app) | **2x–3x faster** on complex UI features |

> *Source: Official Flutter Multi-Engine Benchmarks & Demo Native HUD Measurements*

<!-- 
Presenter Notes:
- Walk through the table.
- The key takeaway here is FlutterEngineGroup. 
- You do not pay the full engine initialization tax for every tab or screen. 
- 180 KB on iOS! That is practically free compared to the cost of a single WebKit process (which is often 40-80MB).
-->

---

## The Pragmatic Decision Matrix

```
                      Do you need this screen to be...
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
  Standard Platform UI?       Dynamic Legal/FAQ?          Complex Interactive?
  (Settings, Forms, Lists,   (Changes weekly, zero      (Mini-game, Canvas, Shaders,
   Deep System APIs)          animation needs)           3D, Branded Onboarding)
         │                           │                           │
         ▼                           ▼                           ▼
   PURE NATIVE                   WEBVIEW                 FLUTTER ADD-TO-APP
 (Swift / Kotlin)               (WebKit)                  (Offloaded Engine)
```

- Stop treating architectures as religions.
- Use Native where system fidelity is mandatory.
- Use Web where instant content updates trump performance.
- Use Flutter where cross-platform graphics complexity would drain your roadmap.

<!-- 
Presenter Notes:
- Summarize the decision matrix.
- "If someone on your team suggests rewriting your native iOS navigation stack in Flutter, tell them no.
  If someone suggests putting a real-time game in a WebView, tell them no.
  Be the engineer who knows which tool fits which job."
-->

---

## Summary & Key Takeaways

1. **Don't rewrite your native app:** Keep your native shell, navigation, system integrations, and standard screens.
2. **Recognize the graphics tax:** Writing custom canvas, shaders, and 3D twice across iOS and Android costs **2x–3x in engineering time**.
3. **Flutter is the "Unity for App UI":** With Impeller and `FlutterEngineGroup`, it delivers **120fps Metal/Vulkan performance** with negligible memory overhead.
4. **Seamless two-way integration:** `MethodChannel` ensures state, tokens, and events flow between Native and Flutter effortlessly.

> **"We are engineers who solve problems with software. Whatever tool fits the job—if it helps our users, use it."**

---

# Thank You!

### Questions & Discussion?

- **Demo Repo:** `github.com/theamorn/flutter-inapp-ios`
- **Tech Stack:** Swift (UIKit), Kotlin (Compose), Flutter (Impeller), Flame, `flutter_scene`
- **Contact / Twitter / LinkedIn:** [@YourHandle]

*(Open floor for Q&A)*

<!-- 
Presenter Notes:
Anticipated Q&A:
1. "How hard is it to setup CI/CD for Add-to-App?"
   - Answer: Flutter compiles down to a CocoaPod / XCFramework for iOS and an AAR / Gradle module for Android. Your native CI doesn't even need Flutter installed if you distribute prebuilt artifacts via Artifactory/GitHub Packages.
2. "Does Flutter Scene work in production today?"
   - Answer: flutter_scene relies on flutter_gpu, which is experimental in Flutter 3.47.2. But 2D Flame and fragment shaders (tabs 3 & 4) are completely production-ready and battle-tested today.
3. "What about accessibility (a11y)?"
   - Answer: Flutter generates native accessibility semantics trees (UIAccessibility on iOS, AccessibilityNodeInfo on Android). Standard buttons and text in Flutter announce correctly to VoiceOver and TalkBack.
-->

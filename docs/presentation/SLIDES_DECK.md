---
marp: false
theme: default
paginate: true
header: "The High-Performance Hybrid — Offloading Complex UI"
footer: "Mobile Native Meetup"
style: |
  section {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 28px;
    padding: 48px;
  }
  h1 { color: #0b57d0; margin-bottom: 8px; }
  h2 { color: #1a73e8; margin-top: 0; margin-bottom: 24px; font-size: 32px; }
  h3 { color: #5f6368; font-size: 24px; margin-top: 0; }
  ul { line-height: 1.6; }
  .prompt-box {
    background: #f1f3f4;
    border-left: 4px solid #fbbc04;
    padding: 12px 16px;
    font-size: 18px;
    border-radius: 4px;
    margin-top: 20px;
    color: #3c4043;
  }
  .talk-box {
    background: #e8f0fe;
    border-left: 4px solid #1a73e8;
    padding: 12px 16px;
    font-size: 18px;
    border-radius: 4px;
    margin-top: 14px;
    color: #174ea6;
  }
---

# The High-Performance Hybrid
## Offloading Complex UI Without Rewriting Your App

- **Target:** iOS & Android Native Developers
- **Core Stance:** Native-first, pragmatic offloading
- **The Goal:** Stop wasting sprints duplicating complex graphics

> **Image Prompt:**  
> Minimalist dark-themed tech conference cover slide illustration. Split-screen concept: sleek Apple Swift orange bird icon and Android green robot standing together beside a glowing neon cross-platform graphics pipeline engine. 8k, modern clean vector 3D render, subtle blue-purple ambient lighting, professional presentation visual.

<!--
Talking Points:
- Defuse skepticism immediately: "I am not here to tell you to rewrite your native app in Flutter."
- Introduce the premise: Native is great for your core app, but there is a smarter way to handle complex UI.
-->

---

# The Holy War
## A Decade of All-or-Nothing

- **Team Native vs. Team Cross-Platform**
- **The Dilemma:** Dual native rewrites vs. compromised hybrid
- **The Pain:** Rebuilding custom animations & shaders twice

> **Image Prompt:**  
> Split conceptual illustration showing two frustrated mobile developers at desks: one coding Swift Metal shaders on a Mac, the other coding Android Vulkan C++ shaders on a PC, trying to match the exact same bouncing fluid animation curves on two phones. Modern tech flat illustration, subtle humorous contrast.

<!--
Talking Points:
- For ten years, mobile development has felt like a binary religion.
- Ask for show of hands: "Who built a custom animation in CoreAnimation/Swift and was immediately asked 'When is it on Android?'"
- That feeling—effort duplication and keeping complex graphics in sync—is the real enemy.
-->

---

# Precedent 1: Mobile Gaming
## Why Unity Owns 70% of Top Mobile Games

- **&gt;70% of top 1,000 games** run on Unity
- **Apple & Google provided:** SceneKit, SpriteKit, Metal, Vulkan
- **The Trade-off:** 1 unified rendering engine &gt; 2x native rewrites

> **Image Prompt:**  
> A bold tech infographic visual showing a giant glossy 3D Unity logo dominating 70% of a pie chart, surrounded by smaller logos for Apple Metal, SceneKit, and Android Vulkan. Sleek data visualization, dark background, futuristic clean glassmorphism.

<!--
Talking Points:
- Game studios didn't write games in Swift for iOS and Kotlin for Android.
- Why? Rebuilding graphics pipelines twice is commercial suicide.
- They accepted an embedded runtime because cross-platform rendering parity is worth it.
-->

---

# Precedent 2: The Smart Shortcut
## Why Meta Uses WebViews for Settings

- **Used by:** Facebook, Instagram, Amazon, Uber
- **Use Cases:** Settings, Help Centers, Terms of Service
- **The Trade-off:** High copy churn, zero 120fps physics requirement

> **Image Prompt:**  
> Clean smartphone mockup showing an Instagram/Facebook Settings screen with a magnifying glass revealing clean HTML/CSS web code under the surface, seamlessly hosted within a native navigation bar. Clean vector editorial style.

<!--
Talking Points:
- Concede that WebViews are the right choice for static or server-driven text.
- Pragmatic teams don't build native table views for legal disclaimers that change every two weeks.
- But what happens when UI requirements demand 120fps fluid physics or custom shaders?
-->

---

# The Missing Middle
## When Web Is Too Weak and Native Is Too Expensive

- **Native:** High craft, but 2x–3x cost for custom graphics
- **WebView:** Low cost, but hard 30–45 fps animation ceiling
- **The Gap:** Where do rich animations, games, & shaders belong?

> **Image Prompt:**  
> A clean 3-column architecture comparison diagram. Column 1: Native (Speedometer at max, but two separate stacks). Column 2: WebView (One stack, but speedometer lagging). Column 3: The Empty Middle Ground with a glowing question mark. High-tech modern UI diagram.

<!--
Talking Points:
- Native is too expensive to duplicate for intricate graphics.
- WebViews choke under heavy layout and animation.
- There is a massive gap in the middle.
-->

---

# Foundation: Three Drawing Models
## Widgets · Web · Owned canvas

- **Platform widgets:** OS owns layout and a11y — login, Home, forms
- **Web document:** DOM for weekly copy — legal, FAQ, CMS
- **Owned canvas:** you paint a `UIView` / `Surface` — Unity, Metal, Flutter Add-to-App

<!--
Talking Points:
- Flutter Add-to-App is column 3: give me a canvas.
- Do not put a form on a canvas.
-->

---

# Foundation: 8.3 ms
## The entire 120 Hz budget

- 60 Hz = 16.6 ms · **120 Hz = 8.3 ms**
- UI isolate + Raster (Impeller → Metal / Vulkan)
- HUD is native-owned; Flutter reports batches only

<!--
Talking Points:
- If Flutter graded itself, the meter is rigged.
-->

---

# Foundation: Identical Pixels
## Two shaders is two bugs

- Metal + “equivalent” AGSL → looks close enough
- One owned canvas → one picture
- Stop before Impeller internals

---

# Add-to-App Topology
## FlutterEngineGroup("hybrid-demo")

- Lazy spawn: `/game`, `/glass`, `/scene` on first tab visit
- Hidden tabs pause rendering
- Extra engine: ~180 KB iOS / ~1.4 MB Android

---

# Enter the Middle Ground
## Introducing Flutter for Offloading

- **Not a replacement:** A targeted graphics tool
- **Built like a game engine:** Own rendering pipeline (Impeller)
- **Direct to Metal & Vulkan:** Zero web bridge, zero DOM overhead

> **Image Prompt:**  
> Elegant illustration of a bridge spanning between a native iOS castle and an Android castle. In the center of the bridge sits a modern high-performance rendering engine emitting smooth 120fps laser beams. Modern 3D isometric vector art.

<!--
Talking Points:
- "I want to introduce the middle ground: Flutter."
- Don't view Flutter as an app replacement. View it as a specialized, high-performance rendering engine inside your native app.
-->

---

# Why Flutter?
## Game-Engine Architecture at C++ Machine Level

- **Pixel-Perfect Rendering:** Draws every pixel itself
- **Native Performance:** AOT-compiled to native machine code
- **Hardware Accelerated:** Impeller compiles shaders directly to Metal / Vulkan

> **Image Prompt:**  
> Technical breakdown infographic showing the Flutter Impeller pipeline: GLSL code compiling AOT into Apple Metal command buffers on iOS and Vulkan command buffers on Android, bypassing the OEM widget tree to talk straight to the GPU. Clean dark-mode engineering schematic.

<!--
Talking Points:
- Why does Flutter fit this role?
- Just like Unity, Flutter doesn't map to OEM system widgets. It owns the canvas.
- It compiles to C++ machine code and talks directly to Apple Metal and Android Vulkan.
- Every bezier curve, shadow, and frame is 100% deterministic and pixel-perfect on both OSs.
-->

---

# The Big Misconception
## "Don't I Have to Rewrite My Entire App?"

- **The Myth:** Flutter is all-or-nothing
- **The Reality:** Flutter is just a UI framework asking for a canvas
- **The Contract:** Native gives a view controller; Flutter draws the pixels

> **Image Prompt:**  
> Blueprint diagram showing a native iOS UIViewController and an Android FragmentActivity providing an empty rectangular picture frame to Flutter. A sleek Flutter mechanical arm reaches in and paints stunning glowing graphics onto that canvas. Minimalist clean architectural diagram.

<!--
Talking Points:
- "Wait, I thought Flutter meant throwing away our Swift/Kotlin app and rewriting everything?"
- Absolutely NOT.
- Under the hood, Flutter is just a view. It asks iOS: 'Give me a UIViewController.' It asks Android: 'Give me a FragmentActivity.'
- It says: 'Just give me the canvas, and I'll handle drawing the complex stuff.'
-->

---

# Add-to-App
## Leaving the Canvas to Flutter

- **Keep Native Core:** Shell, navigation, system APIs, background sync
- **Embed Where Needed:** Specific tabs, modal sheets, or interactive views
- **Seamless Integration:** Native treats it like any standard `UIViewController`

> **Image Prompt:**  
> A high-end native smartphone UI with a bottom tab bar. Tabs 1 and 2 are standard UIKit native views, while Tab 3 opens an embedded Flutter canvas glowing with vibrant interactive graphics. Seamless visual flow, premium iOS design.

<!--
Talking Points:
- This pattern is called Add-to-App.
- Keep your UIKit navigation stack, your Jetpack Compose architecture, your push notifications, your Bluetooth.
- When you reach that one screen with impossible cross-platform animation requirements, hand the canvas to Flutter.
-->

---

# The Add-to-App Myth
## "Doesn't It Consume Huge Memory?"

- **Standalone Engine:** ~13–19 MB base RAM
- **`FlutterEngineGroup`:** **~180 KB on iOS** / **~1.4 MB on Android**
- **Resource Sharing:** Shares GPU context, isolate snapshot, & font tables

> **Image Prompt:**  
> Infographic comparing memory consumption: A heavy 50MB block labeled "Old Isolated Engines" shrinking down into a sleek stack of lightweight layered cards labeled "FlutterEngineGroup ~180KB shared context". Bright glowing cyan accents, minimal clean tech chart.

<!--
Talking Points:
- "Okay, but doesn't spinning up an engine eat tons of memory?"
- No. With FlutterEngineGroup, multiple engines share the same GPU context and Dart isolate snapshot.
- The incremental cost of each extra screen is just ~180 KB on iOS!
- That is less memory than loading a single high-res PNG image.
-->

---

# Isn't That Just Unity in an App?
## Yes—Without the 100MB Pain

- **Unity:** 3–6 second cold load, 50–100MB+ binary bloat
- **Flutter:** **100–200 ms** cold launch; **5–15 ms** spawn time
- **Binary Footprint:** ~4–6 MB compressed vs. heavy game runtime

> **Image Prompt:**  
> Direct visual comparison card. Left side: Heavy Unity game crate with a loading spinner marked "5s load / 100MB". Right side: Sleek feather-light Flutter engine marked "150ms instant load / 5MB". High contrast clean presentation card.

<!--
Talking Points:
- "So you basically put Unity inside your app?"
- Conceptually, yes—you get a unified 2D/3D canvas.
- BUT without the game-engine baggage: Unity takes 3-6 seconds to load its runtime and adds 100MB to your app.
- Flutter boots in 150ms, spawns cached tabs in 5-15ms, and adds just a few megabytes.
-->

---

# The Developer Heartbreak
## The Real Pain Point Behind Two Apps

- **Design:** Creates a gorgeous, fluid, physics-driven animation
- **iOS:** Spends 2 weeks building it in CoreAnimation
- **Android:** "This will take 3 sprints and might drop frames"
- **Product Owner:** "Cut the feature. We'll make it static."

> **Image Prompt:**  
> Editorial split comic illustration. Panel 1: An excited designer showing a fluid, interactive UI prototype. Panel 2: iOS dev says "Done!". Panel 3: Android dev looks overwhelmed by complex graphics API math. Panel 4: Sad team looking at a boring static grey box after the feature got cancelled.

<!--
Talking Points:
- "That's all technical data. Why should you actually care as an engineer?"
- Tell the story every mobile dev knows:
  Design comes up with an incredible fluid interaction.
  iOS builds it. Android struggles or doesn't have the equivalent API.
  In the end, Product kills the animation to keep feature parity.
  Everyone loses, and the app feels boring.
-->

---

# Pixel-Perfect Parity
## Advanced Animations That Run Everywhere

- **Single Pipeline:** Identical bezier curves, shaders, and physics
- **Cross-Platform Parity:** Runs on iOS, Android, and Web simultaneously
- **Zero Compromise:** Product doesn't have to downgrade the design

> **Image Prompt:**  
> Two phones side-by-side (iPhone 16 Pro and Google Pixel 9) showing an identical glowing fluid wave animation at the exact same microsecond, demonstrating sub-pixel parity across operating systems. Clean photorealistic renders.

<!--
Talking Points:
- This is the superpower of Flutter's rendering architecture.
- You build the complex animation once.
- It runs with identical timing, color-space, and 120fps physics on both platforms.
- Product doesn't have to cut the feature, and you don't spend weeks in synchronization meetings.
-->

---

# The Showcase: What Can It Do?
## Pushing the Limits of Embedded UI

- **Tab 3:** 120fps 2D Arcade Game with Flame & Dissolve Shaders
- **Tab 4:** Liquid Glass Shader over Live Scrolling Widget Tree
- **Tab 5:** Full 3D Low-Poly Island Scene with Raycast Tap-to-Move

> **Image Prompt:**  
> Triple showcase banner previewing the three demo modes: 1) Cartoon Flappy Cat arcade game, 2) Frosted liquid glass card refracting live UI with water ripples, 3) Stylized low-poly 3D island with character. Bold, vibrant colors, cinematic layout.

<!--
Talking Points:
- "Let's see what we mean by advanced UI that native struggles to do identically."
- Introduce the showcase: We built a real app with a live native HUD to prove what happens when you push Flutter hard.
-->

---

# Live Showcase: 2D Game & Shaders
## Tab 3: Flappy Cat (Flame Engine)

- **120 fps ProMotion:** Batch averages **~2–4 ms** (Budget: 8.3ms)
- **Features:** Collision physics, particle weather, sky shader
- **Death Dissolve:** Custom GLSL flame shader with zero jank

> **Image Prompt:**  
> Playful pixel/vector game screen of "Flappy Cat": an orange cartoon cat flying between green obstacle pipes under a dynamic sunset sky shader, with smooth arcade particle trails. Pinned top corner HUD reading "120 FPS • 3.2ms Raster".

<!--
Talking Points:
- (Switch to phone demo - Tab 3)
- Play a round: point out the 120fps cadence on the native HUD.
- Die: Show the flame dissolve shader ignite without dropping a single frame.
- "Try writing this once in SpriteKit, then ask yourself if you want to rewrite it in Android Canvas."
-->

---

# Live Showcase: Liquid Glass
## Tab 4: Fragment Shader Over Live UI

- **The Aesthetic:** Apple Liquid Glass, running identically on Android
- **Under the Hood:** `AnimatedSampler` feeds live widget tree into GLSL
- **Interactive:** Real-time refraction, SDF chromatic aberration, touch ripples

> **Image Prompt:**  
> High-end futuristic iOS control panel screen where a frosted translucent liquid glass card refracts and distorts a live scrolling list behind it. Glowing dynamic water ripples expanding from where a fingertip touches the glass surface. Photorealistic glassmorphism render.

<!--
Talking Points:
- (Switch to phone demo - Tab 4)
- Scroll the list under the glass: it visibly refracts in real time.
- Drag across the glass: Touch ripples propagate across the surface at 120fps.
- "In UIKit, this requires private APIs or slow offscreen snapshots. In Flutter, it's one shader file running identically on Android."
-->

---

# Live Showcase: 3D Graphics
## Tab 5: `flutter_scene` + `flutter_gpu`

- **Embedded 3D:** Low-poly 3D world inside a native tab
- **Real-Time Lighting:** Day $\rightarrow$ Night ambient transition
- **Tap-to-Move:** Screen-space raycasting intersects ground plane $y=0$

> **Image Prompt:**  
> Beautiful low-poly 3D diorama of a tropical island floating in stylized turquoise sea: palm trees, procedural terrain, a blocky low-poly character standing on grass, with an ambient sun/moon slider. 3D Blender/Game-engine stylized isometric view.

<!--
Talking Points:
- (Switch to phone demo - Tab 5)
- Orbit around the 3D island with your finger.
- Drag the Day/Night slider.
- Tap the ground: The raycaster unprojects the screen touch into 3D world space and the character walks there.
- "Full 3D graphics in your native app without the 100MB Unity runtime."
-->

---

# The Bridge: Not a Walled Garden
## Returning Values Back to Native

- **Two-Way State:** `MethodChannel` syncs data with microsecond latency
- **The Demo:** Flappy Cat reports score $\rightarrow$ Native `GameScoreManager`
- **Native UI:** Tab 1 UIKit Table immediately displays **"Highest Score"**

```dart
// Flutter side
_gameChannel.invokeMethod('reportScore', {'score': score});
```
```swift
// Native Swift side: HomeViewController.swift
let score = GameScoreManager.shared.highestScore // Updated live!
```

> **Image Prompt:**  
> Diagram illustrating two-way communication: A game score badge traveling across a glowing fiber-optic bridge from the Flutter Game engine directly into a native iOS UIKit table cell. High-tech clean schematic.

<!--
Talking Points:
- (Switch to Tab 1 Native Home)
- Point to the "Highest Score" row in the native table view.
- "The score I just achieved in Tab 3 is now in native UserDefaults and rendered by UIKit. Flutter is never an isolated silo."
-->

---

# The Pragmatic Decision Matrix
## Choose Tools Like an Architect

- **Keep Native (Swift/Kotlin):**  
  App shell, navigation, system widgets, HealthKit, Bluetooth
- **Use Web (WKWebView):**  
  Legal disclaimers, FAQs, weekly marketing copy changes
- **Offload to Flutter (Add-to-App):**  
  Interactive mini-games, complex canvas, shaders, 3D showcases

> **Image Prompt:**  
> A simple 3-branch flowchart decision tree with modern clean icons: Apple/Android logo for "System Core", Web browser icon for "Static Dynamic Text", and Flutter bird icon for "High-Performance Complex Canvas".

<!--
Talking Points:
- Don't let dogmatic purity dictate architecture.
- If someone says rewrite your native iOS navigation in Flutter, say no.
- If someone says write custom Metal and Vulkan shaders twice, say no. Use the right tool.
-->

---

# Summary & Takeaways
## Be a Pragmatic Mobile Engineer

- **1. Native is king:** Keep your native core foundation.
- **2. Respect the graphics tax:** Writing custom canvas twice costs 2x–3x.
- **3. Flutter as the "Unity for App UI":** 120fps hardware rendering at ~180KB RAM.
- **4. Two-way bridge:** Seamless state flow via MethodChannel.

> **"We are engineers who solve problems with software. Whatever tool fits the job—if it helps our users, use it."**

> **Image Prompt:**  
> Closing slide graphic: A modern minimalist badge showing Swift, Kotlin, and Flutter logos interlocking like precision mechanical watch gears around a central glowing "User Value" emblem. Elegant dark blue background.

<!--
Talking Points:
- Remind the room of our true mission: We aren't defined by our language or framework loyalty. We are engineers who solve problems for users.
- If native is best, use native. If web works, use web. If an embedded engine solves a multi-sprint animation bottleneck, use it.
- Thank the audience and transition to Q&A.
-->

---

# Q & A
## The High-Performance Hybrid

- **Codebase:** `github.com/theamorn/flutter-inapp-ios`
- **Stack:** UIKit + Compose + Flutter Impeller + Flame + `flutter_scene`
- **Slides & Docs:** `docs/presentation/`

<!--
Talking Points:
- Open the floor for questions.
- Reiterate that all code is open-source in the repo.
-->

---
marp: true
theme: default
paginate: true
header: "The High-Performance Hybrid — Offloading Complex UI"
footer: "Mobile Native Meetup"
style: |
  section {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 60px;
  }
  h1 {
    font-size: 56px;
    color: #0b57d0;
    margin: 0 0 16px 0;
    line-height: 1.15;
  }
  h2 {
    font-size: 34px;
    color: #5f6368;
    font-weight: 400;
    margin: 0;
    line-height: 1.3;
  }
  .big-stat {
    font-size: 110px;
    font-weight: 900;
    color: #1a73e8;
    margin: 10px 0;
    letter-spacing: -2px;
  }
  .visual-card {
    background: #f8f9fa;
    border: 1px dashed #dadce0;
    border-radius: 8px;
    padding: 14px 20px;
    font-size: 18px;
    color: #444746;
    margin-top: 28px;
    max-width: 85%;
    text-align: left;
  }
---

# The High-Performance Hybrid
## Offloading Complex UI Without Rewriting Your App

<div class="visual-card">
  <strong>Visual:</strong> Split-screen illustration. Swift orange bird and Android green robot standing beside a glowing, high-performance graphics pipeline engine. Minimalist, modern dark mode.
</div>

<!--
Talking Points:
- "Good evening! Welcome everyone."
- Defuse skepticism in the first 5 seconds: "I am not here to tell you to rewrite your native app in Flutter."
- Today is about pragmatic engineering: keeping your native app, and offloading the screens that cost you weeks of duplicate work.
-->

---

# Keep your native app.
## We are not here to replace Swift or Kotlin.

<div class="visual-card">
  <strong>Visual:</strong> Clean, elegant Apple and Android logos glowing side-by-side with a golden badge: "Native-First Architecture".
</div>

<!--
Talking Points:
- Native iOS and Android are kings of system integration, background tasks, widgets, and platform feel.
- We love native. Don't touch what native is already great at.
-->

---

# Ten years of all-or-nothing.
## "Team Native" vs "Team Cross-Platform"

<div class="visual-card">
  <strong>Visual:</strong> High-contrast split tug-of-war graphic between "100% Swift/Kotlin" and "Rewrite Everything in Cross-Platform".
</div>

<!--
Talking Points:
- For a decade, mobile architecture has been treated as a binary religion.
- You either commit to two separate native teams rewriting everything twice, or you compromise on a cross-platform rewrite.
- It's time to escape that trap.
-->

---

# "It's ready on iOS. When is it on Android?"

<div class="visual-card">
  <strong>Visual:</strong> A developer looking at an iPhone running a fluid, custom bouncing animation, while an Android phone beside it shows a red loading error / sync icon.
</div>

<!--
Talking Points:
- Ask for a show of hands: "Who has spent 2 weeks perfecting a custom animation in Swift, only for Product to ask when Android gets it?"
- The real enemy isn't native or cross-platform. The enemy is wasting sprints duplicating pixel-pushing.
-->

---

<div class="big-stat">&gt; 70%</div>

## of top 1,000 mobile games run on Unity.

<div class="visual-card">
  <strong>Visual:</strong> Bold pie chart where a glossy 3D Unity logo occupies 70%+, surrounded by small icons for SceneKit, Metal, and Vulkan.
</div>

<!--
Talking Points:
- Look at mobile gaming. Apple has SceneKit, Metal, and SpriteKit. Google has Vulkan and Filament.
- Yet over 70% of top mobile games use Unity. Why?
- Because game studios realized early on: writing 3D graphics and shaders twice is commercial suicide.
-->

---

# Nobody writes rendering pipelines twice.
## Studios trade a small runtime for guaranteed parity.

<div class="visual-card">
  <strong>Visual:</strong> A single 3D game character rendering identically with identical lighting across both an iPhone and an Android tablet.
</div>

<!--
Talking Points:
- Game developers don't care about OS UI conventions; they care about deterministic, identical graphics.
- They accepted an embedded engine because the return on investment was undeniable.
-->

---

# Meta uses WebViews for Settings.
## The pragmatic choice for low-velocity screens.

<div class="visual-card">
  <strong>Visual:</strong> Smartphone showing Instagram/Facebook Settings, with a magnifying glass revealing clean HTML/CSS under the native navigation bar.
</div>

<!--
Talking Points:
- At the other extreme: Why does Facebook use WebViews for Settings and Help Centers?
- Because legal copy and FAQs change weekly.
- Nobody needs 120fps physics for a privacy policy. Pragmatic teams use the web where it makes sense.
-->

---

# The Missing Middle.
## Too heavy for Web. Too expensive to write twice.

<div class="visual-card">
  <strong>Visual:</strong> A canyon between "Web" (lagging at 30fps) and "Native" (costing 3x engineering time). A glowing question mark floats in the middle.
</div>

<!--
Talking Points:
- So what happens in the middle?
- When design wants a fluid interactive promo, an in-app mini-game, custom shaders, or 3D product view?
- Web is too weak—it drops frames. Native is too expensive to duplicate.
-->

---

# Three ways a screen draws.
## Widgets. Web. Owned canvas.

<div class="visual-card">
  <strong>Board:</strong> Three columns. (1) UIKit/Compose owns layout and a11y. (2) DOM for weekly copy. (3) UIView/Surface you paint — Unity, Metal, Flutter Add-to-App.
</div>

<!--
Talking Points:
- Flutter Add-to-App is column 3: give me a canvas.
- Do not put login or Home on a canvas. You will lose VoiceOver.
-->

---

# 8.3 milliseconds.
## That is the entire 120 Hz budget.

<div class="visual-card">
  <strong>Board:</strong> 60 Hz = 16.6 ms. 120 Hz = 8.3 ms. UI isolate + Raster/Impeller. HUD is native CADisplayLink / Choreographer. Flutter only reports batches.
</div>

<!--
Talking Points:
- If Flutter graded itself, the meter is rigged.
- Jank is two clocks. Read both.
-->

---

# Identical pixels is architecture.
## Two shaders is two bugs.

<div class="visual-card">
  <strong>Board:</strong> Metal + AGSL "equivalent" → looks close enough. One owned canvas → one picture. Stop before Impeller internals.
</div>

<!--
Talking Points:
- Game studios already paid this tax. A promo screen is the same problem.
-->

---

# Enter the Middle Ground.
## Introducing Flutter for offloading complex UI.

<div class="visual-card">
  <strong>Visual:</strong> The glowing bridge across the canyon: Flutter depicted as an embedded hardware-accelerated graphics card slotted inside a native smartphone.
</div>

<!--
Talking Points:
- I want to introduce the pragmatic middle ground: Flutter.
- Don't think of Flutter as an app replacement.
- Think of it as a specialized, high-performance rendering engine embedded inside your native app.
-->

---

# Flutter owns the canvas.
## Direct to Metal and Vulkan at C++ machine level.

<div class="visual-card">
  <strong>Visual:</strong> Technical diagram: Flutter's Impeller engine bypassing the OS widget hierarchy to send precompiled AOT Metal/Vulkan command buffers straight to the GPU.
</div>

<!--
Talking Points:
- Why Flutter? Because like Unity, Flutter does NOT map to OEM native buttons or DOM elements.
- It asks for a surface and paints every pixel itself.
- With Impeller, it compiles AOT to native machine code with zero runtime shader compilation jank.
-->

---

# You don't rewrite your app.
## Flutter is just a view asking for a canvas.

<div class="visual-card">
  <strong>Visual:</strong> An iOS UIViewController and Android FragmentActivity handing an empty picture frame to a sleek Flutter mechanical painter.
</div>

<!--
Talking Points:
- "Wait, doesn't Flutter mean throwing away our Swift/Kotlin app?"
- Absolutely NOT.
- Under the hood, Flutter is just a view controller.
- It asks iOS: "Give me a UIViewController." It asks Android: "Give me a FragmentActivity."
-->

---

# Add-to-App.
## Native owns the app; Flutter paints the screen.

<div class="visual-card">
  <strong>Visual:</strong> Native iOS tab bar with 5 icons. The first two tabs are native UIKit, while the active tab is an embedded, vibrant Flutter canvas.
</div>

<!--
Talking Points:
- This pattern is called Add-to-App.
- Keep your native navigation, push notifications, Bluetooth, and standard forms.
- When you reach that one screen with impossible animation requirements, hand the canvas to Flutter.
-->

---

# One group. Three lazy engines.
## Hidden tabs pause. First visit shows the cost.

<div class="visual-card">
  <strong>Board:</strong> Native HUD over Tab 1 Home, Tab 2 WebView, and FlutterEngineGroup("hybrid-demo") spawning /game, /glass, /scene on first visit.
</div>

<!--
Talking Points:
- Do not pre-warm at launch.
- Quote 4–6 MB bundle, ~13–19 MB first engine, ~180 KB / 1.4 MB extras, then move.
-->

---

<div class="big-stat">~180 KB</div>

## The memory cost of an extra Flutter engine on iOS.

<div class="visual-card">
  <strong>Visual:</strong> Infographic showing `FlutterEngineGroup`: a shared GPU context and isolate snapshot, with multiple lightweight tabs consuming only 180 KB each.
</div>

<!--
Talking Points:
- "Doesn't embedding Flutter eat 100MB of RAM?"
- No. That's the old 2019 myth.
- With FlutterEngineGroup, engines share the GPU context and isolate snapshots.
- An additional engine costs ~180 KB on iOS and ~1.4 MB on Android. That's less than loading a single high-res image!
-->

---

# Like Unity in an app.
## Without the 100MB baggage.

<div class="visual-card">
  <strong>Visual:</strong> Side-by-side comparison: Heavy Unity crate labeled "3–6s boot / 100MB" vs. feather-light Flutter badge labeled "150ms instant launch / 4MB".
</div>

<!--
Talking Points:
- "So it's basically like putting Unity in your app?"
- Conceptually, yes—you get a unified 2D/3D canvas.
- But without the game engine tax: Unity takes 3 to 6 seconds to boot and adds 100MB.
- Flutter launches in 150ms and spawns cached tabs in 10ms.
-->

---

# "Product Owner: Cut the animation."
## The heartbreak of dual native development.

<div class="visual-card">
  <strong>Visual:</strong> Comic strip: Designer presents an incredible fluid UI prototype. iOS finishes in 2 weeks. Android says "3 sprints". A red "FEATURE CANCELLED" stamp hits the desk.
</div>

<!--
Talking Points:
- That's the technical data. But here is the real human story.
- Design creates a breathtaking fluid interaction.
- iOS builds it. Android can't make it smooth in time.
- Product says: "We need feature parity—cut the animation."
- Everyone loses, and our apps stay boring.
-->

---

# Build once. 120fps everywhere.
## Sub-pixel rendering parity across iOS, Android, & Web.

<div class="visual-card">
  <strong>Visual:</strong> iPhone Pro and Google Pixel 9 side-by-side rendering the exact same fluid wave and particle effect with identical microsecond curves.
</div>

<!--
Talking Points:
- This is Flutter's superpower.
- You build the complex animation once.
- It runs with identical bezier curves, shaders, and 120fps physics on both platforms.
- Product never has to cancel a design again.
-->

---

# Let's see it on real hardware.
## 5 tabs, native HUD, zero compromises.

<div class="visual-card">
  <strong>Visual:</strong> iPhone photo on a podium with a floating transparent native HUD reading: "Host CADisplayLink: 120 FPS • Process: 42 MiB".
</div>

<!--
Talking Points:
- Don't take my word for it. Let's look at the real app.
- We built a native UIKit app on iOS and Compose on Android with a window-level native HUD.
- The host app measures CADisplayLink and memory natively so you know the numbers are real.
-->

---

# Tab 1: Pure Native UIKit.
## 120fps baseline. Never rewrite what's already great.

<div class="visual-card">
  <strong>Visual:</strong> Live screenshot of Tab 1: Clean native iOS table view, switches, and avatar with a green "120 FPS Pinned" badge.
</div>

<!--
Talking Points:
- (Switch to phone - Tab 1)
- Scroll hard on Tab 1. Host HUD sits at 120fps.
- Reiterate: "This is what native does best. Fast, accessible, platform-native. Don't touch it."
-->

---

# Tab 2: WKWebView.
## Great for text—until you hit the 30fps wall.

<div class="visual-card">
  <strong>Visual:</strong> Tab 2 screenshot showing the local Settings page with the Stress Test toggle active and frame times spiking.
</div>

<!--
Talking Points:
- (Switch to Tab 2)
- Normal mode scrolls fine—proving we aren't strawmanning web.
- Toggle Stress Test: watch the page meter drop to 30–40 fps under composite blur and layout thrash.
- Web has a ceiling.
-->

---

# Tab 3: Flappy Cat.
## 120fps arcade physics & shaders in Flame.

<div class="visual-card">
  <strong>Visual:</strong> Colorful arcade game screen of Flappy Cat flying past pipes with dynamic sky and fire dissolve shaders at 120fps.
</div>

<!--
Talking Points:
- (Switch to Tab 3)
- Play a round: point out the 120fps cadence on the native HUD. UI and raster batch at ~3ms.
- Die: Show the flame dissolve shader ignite without dropping a single frame.
- "Try writing this in SpriteKit, then rewriting it in Android Canvas."
-->

---

# Tab 4: Liquid Glass.
## GLSL refraction over a live, scrolling widget tree.

<div class="visual-card">
  <strong>Visual:</strong> Frosted translucent liquid glass card refracting live scrolling text behind it with interactive touch ripples.
</div>

<!--
Talking Points:
- (Switch to Tab 4)
- Scroll the list under the glass: it visibly refracts in real-time.
- Drag across the glass: Touch ripples propagate across the surface at 120fps.
- "Impractical in UIKit, impossible in WebView, identical on Android."
-->

---

# Tab 5: 3D Island Scene.
## Full 3D graphics with tap-to-move raycasting.

<div class="visual-card">
  <strong>Visual:</strong> Low-poly 3D tropical island diorama with day/night ambient slider and blocky character walking to tapped coordinates.
</div>

<!--
Talking Points:
- (Switch to Tab 5)
- Orbit around the 3D island with your finger.
- Drag the Day/Night slider.
- Tap the ground: The raycaster unprojects screen touch into 3D world space and the character walks there.
- Ultra: extra props + wandering NPC. Water bump is off so the phone stays live.
- Full 3D graphics inside your native tab without Unity.
-->

---

# Flutter is not a walled garden.
## Scores sync live back to native UIKit.

<div class="visual-card">
  <strong>Visual:</strong> MethodChannel diagram showing Flappy Cat score passing seamlessly into native Swift `GameScoreManager` and updating the Tab 1 table cell.
</div>

<!--
Talking Points:
- (Switch back to Tab 1)
- Point to the "Highest Score" row in the native table view.
- "The score I just achieved in Tab 3 is now in native UserDefaults and rendered by UIKit. Flutter is never an isolated silo."
-->

---

# Choose tools like an architect.
## Stop treating frameworks as religions.

<div class="visual-card">
  <strong>Visual:</strong> Clean 3-tier architecture pyramid:
  - Base: Native Swift/Kotlin (Core shell, system APIs)
  - Middle: WebKit (Legal text, FAQs)
  - Peak: Flutter Add-to-App (High-performance canvas, games, 3D)
</div>

<!--
Talking Points:
- Don't let dogmatic purity dictate architecture.
- If someone says rewrite your native navigation in Flutter, say no.
- If someone says write custom Metal and Vulkan shaders twice, say no.
- Be the pragmatic architect who picks the right tool for the job.
-->

---

# We solve problems with software.
## Whatever tool fits the job—if it helps our users, use it.

<div class="visual-card">
  <strong>Visual:</strong> Modern minimalist badge showing Swift, Kotlin, and Flutter logos interlocking like precision mechanical watch gears, with a central glowing icon representing "User Value".
</div>

<!--
Talking Points:
- Remind the room what our craft is really about:
  "At the end of the day, our job title isn't 'Swift Developer' or 'Kotlin Developer' or 'Flutter Developer'.
  We are Software Engineers. Our purpose is to solve real problems for real users using software.
  If pure native is the best tool for the screen, use native.
  If web is the pragmatic choice for static copy, use web.
  And if an embedded graphics engine lets you ship an incredible 120fps experience without burning 3 sprints, use it.
  Whatever tool fits the job—as long as it helps our users, use it."
- Thank you!
-->

---

# Q & A
## The High-Performance Hybrid

<div class="visual-card">
  <strong>Repo:</strong> github.com/theamorn/flutter-inapp-ios<br>
  <strong>Stack:</strong> Swift UIKit • Kotlin Compose • Flutter Impeller • Flame • flutter_scene
</div>

<!--
Talking Points:
- Open the floor for questions.
- Address common questions: CI/CD setup with XCFrameworks, accessibility semantics, and production readiness.
-->

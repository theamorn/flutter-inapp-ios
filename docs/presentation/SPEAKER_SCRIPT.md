# Speaker script — Acts 1–5 (must end by 33:00)

Read this out loud in rehearsal. Target **~130 words/minute**. If you finish after 33:00, **cut the Unity-vs-Flutter comparison** in Act 4 first (the block marked CUT-FIRST). Do not steal from the frame-budget board.

Word counts are spoken text only.

| Act | Clock | Words | Read time @ 130 wpm |
|---|---|---|---|
| 1 Open | 0:00–3:00 | ~430 | ~3:20 |
| 2 Identical UI | 3:00–10:00 | ~880 | ~6:45 |
| 3 Foundation | 10:00–20:00 | ~1,100 | ~8:30 |
| 4 Add-to-App | 20:00–28:00 | ~770 | ~5:55 |
| 5 Heartbreak | 28:00–33:00 | ~520 | ~4:00 |
| Spoken 1–5 | | **~3,700** | **~28:30** |
| Stage business | hands, board drawing, pauses | | **~4:30** |
| **Acts 1–5** | **0:00–33:00** | | **~33:00** |

Then switch to the phone and [DEMO_SCRIPT.md](DEMO_SCRIPT.md). Draw the boards from [THEORY_BOARDS.md](THEORY_BOARDS.md) while you talk Act 3 and Act 4.

---

## Act 1 — Open (0:00–3:00)

Thanks for having me.

Native mobile development is a little over eighteen years old. July 2008: iPhone 3G, iPhone OS 2.0, the App Store. That is the moment Apple let third parties write real native applications. The original iPhone, a year earlier, did not — web apps only. Android shipped the same year. For eighteen years the job has been the same: respect the operating system.

In those eighteen years, a lot of technologies tried to *replace* native. Web wrappers. PhoneGap. Titanium. Xamarin. A decade of “write once, throw the Swift away.” Some of those stacks shipped real products. None of them replaced native as the default for the shell — login, tabs, HealthKit, the thing that has to feel like iOS and Android. The reason people remember is performance, and they are not wrong. Miss the frame and users feel it. Fake the chrome and users feel it. A replacement religion dies the first time the scroll is not as good as Settings.

Here is the sentence I want in the room before anyone looks at a logo. Flutter is not here to compete with native. It is here to cooperate with it. And that is not a Flutter trademark. React Native has official brownfield docs — Meta shipped that way. Unity as a Library embeds a game engine in a native host. A WebView already does this. Add-to-app is a pattern, not a brand.

What we are going to look at is one guest with a specific job: an owned canvas that paints its own pixels, sitting inside a native window. This repo does that. The login you saw — Mobile Native Meetup — is UIKit and Compose. The tab bar is native. The HUD is native. Flutter is a view we spawn when two GPU pipelines would kill the feature.

Today is the trade. Pros. Cons. What it can do. What it costs. I am not here to tell you to rewrite your native app.

Quick show of hands. Who here has shipped an animation on iOS that you were proud of — Core Animation, a custom transition, a spring that finally felt expensive in a good way — and then heard, “Great. How long until Android has it?”

Keep your hands up for a second if the honest answer was “we shipped a static card instead.”

That question is the talk. When the pixels have to match, and the physics have to match, who should own the canvas — and how do we do that without burning the native app down?

Here is the next half hour in one breath. When platform difference is fine, and when it is not. Then three drawing models and an 8.3-millisecond budget on a board. Then how this repo embeds a canvas without giving away the shell. Then the full cancelled-animation story. Then the phone. If at any point I start listing widgets, throw something.

---

## Act 2 — When identical UI is the point (3:00–10:00)

iOS and Android each paint with their own engine. UIKit and SwiftUI look like Apple. Views and Compose look like Google. The buttons differ. The fonts differ. The scroll physics differ. That is alright. That is the operating system doing its job. Nobody in this room wants an iPhone that looks like Material 3.

Your customer is not holding an iPhone and a Pixel side by side on the train. Even people who own both accept that Settings looks like iOS on iOS. Platform difference for the shell is not a bug. Testers will compare screenshots. Designers will. The person who paid for the app will not. They can live with a different switch.

Flutter comes in with a different point of view. It does not ask UIKit and Compose to agree. It owns the renderer. Impeller paints the same scene to Metal on iPhone and Vulkan on Pixel. You get nearly the same picture — not because we mapped every widget, because we stopped asking two engines to impersonate each other. I will not say pixel-perfect. Text, fonts, and notches still exist. I will say: one picture, two phones, close enough that design stops arguing whose build is the source of truth.

There is a trade. I want to be precise, because in this room “trade-off” usually means “it cannot do 120 frames.” That is not what I mean. This canvas can do 120 hertz. You will see it on the HUD. The tax is elsewhere. Own the pixels and you own catching up to OS chrome. Own the pixels and you do not get `libjpeg-turbo` for free. Heavy image compress in the Dart `image` package is tens of times slower than native. Isolates stop the UI from hitching. They do not make Huffman faster. Call the platform. That is the performance I mean: not vsync. Codecs. Chrome. A first-engine RAM bill.

So what is Flutter for? When do we actually need identical UI? What difference is *not* acceptable?

Not the login. Not the tab bar. Not a settings toggle. Those should look like the OS. Your user expects that. Difference there is a feature.

The difference that is not acceptable is a picture that *is* the product.

Animation is one. Design ships a spring, a dissolve, a card that feels like it has weight. iOS spends a few days in Core Animation. It ships. It is gorgeous. Android gets a whole sprint — and no guarantee it holds 120 on the phones you actually have in market, not the flagship on the poster. “Just port the animation” is not a ticket. It is a second GPU path.

A game is another. Physics, particles, a death effect that has to feel the same on both stores.

What else? Not the checkout. Not the API. Not the score rules. Business logic copies. AI will draft it by Friday. Two GPU pipelines will not.

A live shader — glass over a scrolling tree, a dissolve, particles that have to feel expensive on both phones.
A 3D view — a product you can orbit, an island you can walk. Two lighting models is two movies.
A branded promo that is a picture, not a form. Onboarding that is a performance, not a checklist.

The PM does the rational thing under a parity constraint. Cut it. Make a static card. Ship both stores equally beige.

That is the case for an owned canvas. Not “make every screen identical.” The case is: this picture is why someone opens the app, we cannot afford to build it twice, and we will not ship delight on one store.

Games already voted. Apple has SceneKit and Metal. Google has Vulkan and Filament. More than seventy percent of the top thousand mobile games still run on Unity. One picture. One team. Steal the lesson, not the 100-megabyte crate.

Help already voted the other way. Facebook, Instagram, Amazon — Settings, legal, FAQ — a lot of that is a WebView. Copy changes Thursday. Difference is fine. A document compositor is the right guest until you ask it for physics, a shader, or a 3D island. Watch for that ceiling in the demo: the native chrome stays smooth while the page falls off the display link.

Twenty seconds, then I will stop naming companies. This canvas is not a weekend experiment. Apptopia — quoted by the Flutter team — saw Flutter in about ten percent of tracked free iOS apps in 2021 and nearly thirty percent in 2024. BMW ships My BMW on it. Alibaba’s Xianyu, Google Pay, NotebookLM, eBay Motors, Nubank, Toyota infotainment, LG on webOS. I am not asking you to become those companies. I am asking you to treat an owned renderer as a known production tool.

The rest of the tax, in one breath. iOS 26 shipped Liquid Glass. Flutter *runs* on iOS 26. Cupertino does not look like iOS 26 yet. You wait, or you fake the glass. It will not match Settings. iPhone Duo moves Apple’s nav and tab bars to the side. A Flutter `AppBar` will not. Layout stretches. Chrome does not migrate unless we detect the device or Flutter adds it. You already heard the codec. Why is this app Swift and Kotlin, not C++ or assembly? We pick the layer that fits. Native for the shell. A canvas when identical motion is the product. Then we go back to architecture.

---

## Act 3 — Foundation (10:00–20:00)

I am going to leave the laptop alone for this act. This is a board. If you take one photo, take the frame-budget one.

There are three ways a mobile screen draws. Not three religions. Three contracts about who owns the pixels.

First: platform widgets. UIKit, SwiftUI, Android Views, Jetpack Compose. The operating system owns layout, accessibility, typography, the look-and-feel, the thing VoiceOver and TalkBack already understand. This is the correct default for almost every screen you ship. Your login belongs here. Your Home tab belongs here. Your settings toggles belong here. If someone on your team proposes rewriting the navigation stack in a canvas engine, the answer is no. That is not courage. That is burning the thing native is best at.

Second: the web. A DOM, CSS, a compositor, maybe a JavaScript framework you already have on the marketing site. One document, ship it to both phones, change it without waiting for review. Perfect for Help, legal, and CMS pages. Weak when you need the same 120-hertz physics on every device, because the browser’s job is documents, not a locked frame budget. You can get surprisingly far. You cannot get honest, deterministic 8.3-millisecond work out of a layout engine that was designed to paginate articles.

Third: an owned canvas. The operating system gives you a UIView or a Surface, and you draw every pixel. Unity does this. A custom Metal renderer does this. A custom Vulkan renderer does this. Flutter Add-to-App does this. You are not wrapping a `UIButton` and hoping the mapping layer keeps up. You are saying: give me the rectangle. I will paint.

Flutter inside a native app is the third model. That single sentence is the architecture. Everything else — Dart, widgets, hot reload — is how you feed that canvas. If you remember nothing else from the next twenty minutes, remember: we are not asking you to adopt a second UI toolkit for forms. We are asking you to treat one expensive screen as a GPU problem.

Now the budget. Draw two numbers. Sixty hertz is 16.6 milliseconds per frame. That is the number most of us grew up with. ProMotion at 120 hertz is 8.3 milliseconds. Half the time. If you miss that window, the user does not see a “slow animation.” They see a hitch. They may not have the vocabulary, but they feel it in their thumb.

On the Flutter side there are two clocks that matter, and native developers deserve the honest names. The UI isolate: layout, widgets, the game tick, the Dart you think of as “the app.” The rasterizer: Impeller turning that scene into Metal command buffers on iOS and Vulkan command buffers on Android. Both have to finish inside that 8.3 milliseconds, with time left for the host to composite the tab bar, the HUD, the status bar, whatever else is in the window.

That split is not trivia. A “janky Flutter screen” is not one disease. If UI time is fat, you are doing too much Dart work per frame — too many widgets, a physics step that should have been budgeted, a rebuild you did not need. If raster time is fat, you are asking the GPU for too much — overdraw, giant blur, a scene that is prettier than the phone. The HUD reports both. Use that. Do not stand on stage and say “Flutter is slow.” Say which clock missed.

Vsync is the other word I want in the room. The display is the conductor. You do not get extra credit for finishing in 2 milliseconds if you then stall and miss the beat. You also do not get to average your way out of a hitch. Users feel the worst frame, not the mean. When I say “2 to 5 milliseconds UI and raster,” I mean batch averages on the HUD, and I will say “average” out loud so nobody thinks I am claiming every frame is a saint.

I am going to talk about the HUD now, because it is the spine of the live demo and I do not want you to think I am grading my own homework.

The HUD on this app is native-owned. On iOS it is `CADisplayLink` for cadence and `task_info` / `phys_footprint` for memory — the same family of number Xcode’s memory gauge shows. On Android it is `Choreographer` and `Debug.getPss`. Flutter is allowed to report only its own UI and raster batch times, over a MethodChannel, as averages, not as “FPS.” If I let Flutter print “120 FPS” on top of itself, you would be right to call the meter rigged. The host grades the host. Flutter reports its homework.

When we get to the phone you will see something like this: host cadence near 120, UI batch a couple of milliseconds, raster batch a couple of milliseconds, memory in mebibytes. I will read the glass. I will not recite a lab fiction from a slide.

Why does “identical pixels” matter enough to change architecture? Because the alternative sounds responsible and is actually how features die. iOS implements the shader in Metal. Android implements “the same thing” in AGSL, or a RenderNode, or a best-effort Compose effect. You do not have one feature. You have two implementations, two bugs, two performance cliffs, and a design review that ends in the most expensive sentence in mobile: “it looks close enough.” Ship it. Customers can tell.

Game studios solved that decades ago. One canvas engine. One picture. One set of artist tools. We already accepted the runtime tax for games. We pretend it is controversial for a promo screen, a onboarding moment, a 3D product view. It is the same problem with a different jacket.

One more foundation point, because native people will ask it, and they are right to. Accessibility. Platform widgets come with a semantics tree the OS already knows. A canvas can lie. If you put a form on a canvas you have volunteered to rebuild VoiceOver and TalkBack by hand, and you will do it worse than Apple and Google. That is another reason the login and Home stay native. We use the canvas for the thing that is already a picture — a game, a glass, an island — and we let the OS keep the thing that is a document.

I am going to stop before Impeller internals. You do not need the shader compiler pipeline to make the architectural decision. You need the model — widgets, web, or owned canvas — and an honest frame budget. If someone wants the compiler after Q&A, I will stay.

---

## Act 4 — Add-to-App (20:00–28:00)

The myth I hear in hallways is: Flutter means rewriting the app. The contract is the opposite. Native keeps the window. Native keeps the tab bar. Native keeps the login. Native keeps HealthKit and Bluetooth and whatever your OS team already did well. Flutter is a view you spawn when a tab needs a canvas. On iOS that view lives in a `UIViewController`. On Android it lives in a `Fragment`. Your navigation code does not care what paints inside, any more than it cares whether a child is a `WKWebView`.

In this repo it looks like a diagram I want you to be able to redraw. I will draw it slowly. Native window at the top. Native HUD pinned to that window, not inside Flutter. Tab 1 is UIKit or Compose Home. Tab 2 is a WKWebView. Under the last three tabs, one `FlutterEngineGroup` named `hybrid-demo`. Why a group? Because the expensive parts — GPU context, isolate snapshot, font tables — can be shared. Each engine still has its own Dart heap, so the game round, the glass sliders, and the island camera do not clobber each other.

Three engines, created the first time you open the tab, never all at launch. Route `/game` for Flappy Cat. Route `/glass` for the liquid glass. Route `/scene` for the island. Lazy spawn is load-bearing. If we pre-warmed everything in `application:didFinishLaunching`, the HUD could not show you the incremental cost of a tab, and I would be standing here asserting a number I hid at launch. Hidden tabs pause rendering. If they did not, Flappy Cat would keep flapping behind Home, the score would move while you were talking, the battery would drain in a pocket, and the CPU would lie about what the user is looking at.

State is retained across tab switches. It is not a promise across process death. If the OS jetsisons you, you wake up like any other native app and spawn again. That is fine. We are embedding a view, not inventing a new process model.

There is also a channel. I will not put code on the screen. I will tell you the contract. The game reports a score. Native stores it. Home — a UIKit table, a Compose list — shows Highest Score. Tokens can go the other way. Navigation intents can go the other way. Flutter is not a tourist island with a souvenir shop. It is a citizen. If it cannot talk to `UserDefaults` and your analytics, you should not ship it.

Cost. I am going to quote a short table and sit down. Do not let this become a numbers fight. The engine in the bundle is about four to six megabytes compressed. That is real. It is also not a hundred-megabyte game engine. The first running engine is on the order of thirteen megabytes of RAM on iOS and nineteen on Android. Extra engines in the group share the heavy stuff, so they cost about 180 kilobytes on iOS and about 1.4 megabytes on Android. Cold spawn is hundreds of milliseconds, not seconds. A cached spawn after the group is warm is on the order of five to fifteen milliseconds for the synchronous call. Measure it on your device. The HUD is there so you do not have to trust a blog post.

**CUT-FIRST if you are over time — start here:** People ask, “Isn’t that just Unity in an app?” Conceptually, yes: you asked for a unified 2D and 3D canvas. The invoice is different. Unity as a library is often a three-to-six-second load and fifty to a hundred megabytes of baggage. Flutter is not free. I will not stand here and say it is free. You already heard the tax: OS chrome and codecs stay native. It is a different invoice: smaller binary, faster spawn, incremental engines that are closer to “another image” than “another runtime.” If you only remember one contrast, remember spawn time and incremental RAM, not a holy war about which engine is morally native.

Impeller, one sentence, and then I will not say Impeller again until the cat dies: shaders compile ahead of time to Metal and Vulkan, so the first time a flame dissolve runs you should not hitch from a runtime compile. That is the 2019 scar a lot of you still have. The scar was real. The compiler story changed.

Leave this cheat sheet up for the rest of the hour. Native: shell, forms, OS APIs. WebView: legal, FAQ, CMS. Flutter canvas: game, shader glass, 3D. That is the whole decision matrix. We are about to prove it on a phone instead of a slide.

---

## Act 5 — Heartbreak (28:00–33:00)

You already heard the ticket in Act 2. Here is the full story so it sticks. I am not going to put five bullet points behind me and read them. I am going to say it once, because you have lived it.

Design ships a physics-heavy interaction. A spring. A dissolve. A card that feels like it has weight. It is beautiful in the prototype. It is the reason someone would open the app instead of the competitor. The room gets quiet in the good way.

iOS spends a few days in Core Animation. Maybe a custom `CADisplayLink` driver. It ships. It is gorgeous. The designer hugs the iOS engineer. This is the part of the job we actually like.

Android looks at the same spec and says the true thing: a whole sprint, and no guarantee it holds on the devices you actually have in market, not the flagship on the poster. There is no shame in that sentence. The platforms are different. The APIs are different. The GPU story is different. “Just port the animation” is not a ticket. It is a second product. Same story for a mini-game, a live shader, a 3D view. Not for the checkout. Business logic copies. Pictures do not.

The product owner does the rational thing under a parity constraint. We cannot ship delight on one store and a static card on the other. Cut the animation. Make it a card. Ship both platforms looking equally boring. The ticket closes. The app gets a little more beige. Nobody writes a postmortem for a feature that never shipped.

That is how good apps get sanded down. Not because native is bad. Native is excellent. Because identical custom motion is the most expensive thing we ask two teams to do, and organizations optimize for the constraint they can see — parity — instead of the cost they cannot see — cancelled joy.

The move is not “rewrite Home in Flutter.” Home is already correct. The meetup login is already correct. Those screens should stay boring in the best way: accessible, predictable, native. You already have Auto Layout, Compose, VoiceOver, TalkBack, Dynamic Type. Do not set that on fire to prove a point about engines.

The move is: pick the interaction that would have been cancelled — the one that made the designer’s eyes change — and build *that* once on an owned canvas. Keep the shell. Then we stop cancelling the part users would have remembered. Feature parity stops meaning “equally beige.” It starts meaning “the same delight, because it is the same picture.”

If you take one product sentence back to your PM, take this: we are not asking for a rewrite. We are asking for permission to stop throwing away the expensive idea.

I am going to pick up the phone now. Release build. Airplane mode. The HUD you will see is the native one. I will talk to the numbers on the glass. If a number is ugly, I will say it is ugly. That is the deal. Tab 1 is the baseline we must not ruin. Tab 2 is the ceiling. Tabs 3, 4, and 5 are the missing middle. Then we come home, and a score will be sitting in a native cell.

---

## Rehearsal checklist (Acts 1–5)

- [ ] Read Acts 1–5 out loud once with a timer, standing, no skipping
- [ ] Record finish time. Target: **≤ 33:00** and **≥ 31:00**
- [ ] If over 33:00: delete the CUT-FIRST Unity paragraph, re-time
- [ ] If still over: shorten the Unity / WebView supporting votes in Act 2 (keep the cancelled-animation case); do not cut the 8.3 ms board
- [ ] If under 31:00: add one concrete “cancelled animation” from your own team at the start of Act 5, and slow the board drawing — do not improvise new architecture
- [ ] Confirm you can draw all four boards in [THEORY_BOARDS.md](THEORY_BOARDS.md) without looking
- [ ] Stage business that is already in the clock: show of hands (~20s), four boards drawn while talking (do not add a silent drawing act), one sip of water after Act 3
- [ ] If the “safe to use” names in Act 2 run long, keep Apptopia 10%→30% and **two** logos (BMW + Google Pay). Cut the rest.
- [ ] If the Flutter-cons beat runs long, keep iOS 26 Liquid Glass + “call the platform for codecs” + the C++ closer. Cut Duo first.

---

## Q&A card — “Why not AI-port iOS to Android?”

Someone will say: we have Copilot / Gemini / Claude. Point it at the Swift, get Kotlin. Why a runtime?

**Say this, then sit down. Do not debate models.**

> AI is a fine intern for a port. It is a bad renderer.
>
> Business logic? Copy it. AI is a fine intern for that. Checkout, APIs, score rules — draft them.
>
> It can turn a UIKit animation into something that *looks like* Compose. It cannot give you the same picture. You still have two implementations: two timing curves, two GPU paths, two hitch profiles. “Looks close enough in the PR screenshot” is how we got the static card.
>
> Identical pixels is not “the AI matched the mock.” Identical pixels is one canvas, one shader, one 8.3-millisecond budget, measured on both phones by a native HUD.
>
> Use AI to write the *one* canvas faster. Do not use it to fork the pixels. That is two bugs with better autocomplete.

If they push: “We measured the AI port and it was fine.”

> Great — then you did not need this talk for that screen. Keep native. This hour is for the screen where fine-on-Android is still a different movie.

---

## Q&A card — Flutter cons (say the accurate version)

Do **not** invent a missing OS target. If someone asks these, use the short form and sit down.

**“Does Flutter support iOS 26?”**

> It runs on iOS 26. The gap is Cupertino visual parity — Liquid Glass — not the OS version. Community packages approximate. They are not UIKit `glassEffect`. Wait or fake. It will not match Settings.

**“What about iPhone Duo?”**

> Layout reflow is fine. Apple’s `TabView` and `NavigationStack` move bars to the side. A Flutter `AppBar` will not. `MediaQuery.displayFeatures` is Android-shaped and empty on Duo. Detect and build chrome, or wait. Flutter runs. The chrome does not migrate for free.

**“Isn’t Flutter terrible at image compression?”**

> The Dart `image` package is terrible next to `libjpeg-turbo`. That is a codec, not a framework. Isolates stop jank. They do not make Huffman faster. MethodChannel or FFI. Then you get native SIMD. Do not say Flutter cannot compress images.

---

## Q&A card — “Can’t React Native do add-to-app too?”

Yes. Do not defend a unique embedding story that is not true.

**Say this, then sit down.**

> React Native has official “Integration with Existing Apps.” Meta shipped brownfield first. Expo now packages an AAR or XCFramework. Unity as a Library embeds a game engine. A WebView is add-to-app with a document compositor. Add-to-app is a pattern, not a Flutter trademark.
>
> The question is which guest you want. React Native’s historic job is native widgets plus a JS runtime. Unity is a 50-to-100-megabyte game engine, usually one instance, usually full-screen. Flutter is an owned canvas — Impeller paints every pixel — with a `FlutterEngineGroup` so extra engines are cheap.
>
> We picked the guest that matches the screens that would have been cancelled: one picture, two phones, native shell kept.

If they push: “Then why not React Native for the island?”

> You can. You will still need a real 3D/game stack beside it, or you will paint a canvas anyway. We already needed the canvas. Native keeps the login.

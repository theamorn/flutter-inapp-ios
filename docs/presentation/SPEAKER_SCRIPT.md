# Speaker script — Acts 1–5 (must end by 33:00)

Read this out loud in rehearsal. Target **~130 words/minute**. If you finish after 33:00, **cut the Unity-vs-Flutter comparison** in Act 4 first (the block marked CUT-FIRST). Do not steal from the frame-budget board.

Word counts are spoken text only.

| Act | Clock | Words | Read time @ 130 wpm |
|---|---|---|---|
| 1 Open | 0:00–3:00 | ~410 | ~3:10 |
| 2 Precedents | 3:00–10:00 | ~710 | ~5:30 |
| 3 Foundation | 10:00–20:00 | ~1,100 | ~8:30 |
| 4 Add-to-App | 20:00–28:00 | ~770 | ~5:55 |
| 5 Heartbreak | 28:00–33:00 | ~520 | ~4:00 |
| Spoken 1–5 | | **~3,510** | **~27:00** |
| Stage business | hands, board drawing, pauses | | **~6:00** |
| **Acts 1–5** | **0:00–33:00** | | **~33:00** |

Then switch to the phone and [DEMO_SCRIPT.md](DEMO_SCRIPT.md). Draw the boards from [THEORY_BOARDS.md](THEORY_BOARDS.md) while you talk Act 3 and Act 4.

---

## Act 1 — Open (0:00–3:00)

I am not here to tell you to rewrite your native app in Flutter.

I want that sentence in the room before anyone looks at a logo on a slide. I have given talks where half the first row folded their arms the moment they saw the word Flutter in the abstract. That reaction is earned. For a decade, “cross-platform” was sold as a replacement religion: throw away the Swift, throw away the Kotlin, start over, trust us. That is not this talk.

Native is still the right place for the shell of a real product. Your login. Your tab bar. Your Home screen. HealthKit. Bluetooth. Push. App clips. The things that have to feel like the operating system, because they *are* the operating system. Keep them. The meetup login you saw on the way in — Mobile Native Meetup, username, password, Sign In — that is a native screen on purpose. Nobody needs a game engine to draw a text field.

Today is about a narrower, more expensive problem. The screens that make two platform teams cry. Mini-games. Custom shaders. Three-dimensional product views. Physics-heavy branded motion that design fell in love with on a Tuesday and product wants on both stores by Friday. The work where “just do it in UIKit and then do it again in Compose” is not a plan. It is a six-week argument and a cancelled animation.

Quick show of hands. Who here has shipped an animation on iOS that you were proud of — Core Animation, a custom transition, a spring that finally felt expensive in a good way — and then heard, “Great. How long until Android has it?”

Keep your hands up for a second if the honest answer was “we shipped a static card instead.”

That question is the talk. Not Flutter versus native. Not rewrite versus stay. When the pixels have to match, and the physics have to match, who should own the canvas?

Here is the next half hour in one breath, so you know I am not sneaking up on a rewrite. We will look at two industry precedents — games and WebViews — then I will put three drawing models and an 8.3-millisecond budget on a board. Then I will show you how this repo embeds a canvas without giving away the native shell. Then a story you already know. Then the phone. If at any point I start listing widgets, throw something.

---

## Act 2 — Precedents (3:00–10:00)

For about ten years we treated mobile architecture like a religion. Team Native sat on one side of the aisle: one hundred percent Swift, one hundred percent Kotlin, two codebases, two design systems, two bug lists, and a story we told ourselves that this was the only way to respect the platform. Team Cross-Platform sat on the other: throw the native app away, start over, one repo will save you.

Both sides were answering the wrong exam question. The waste is not “we used a framework.” The waste is writing the same custom graphics pipeline twice. Forms are cheap to write twice. A refraction shader is not. A 3D camera rig is not. A 120-hertz particle death effect is not.

Look at games, because games already ran this experiment at industry scale. Apple gave you SceneKit, SpriteKit, Metal, RealityKit. Those are not toys. Google gave you Vulkan, Filament, OpenGL ES. Also not toys. If native graphics frameworks were enough, the top of the App Store would be a festival of SceneKit and Filament. It is not. More than seventy percent of the top thousand mobile games run on Unity.

Studios did not do that because they hate native APIs. They did it because maintaining two rendering pipelines, two shader languages, two lighting models, two sets of artist tools, is two to three times the engineering cost. They paid a runtime — yes, a real binary, yes, real memory — so one team could ship one picture.

There is a second reason Unity won that native UI people under-count: the art pipeline. One set of meshes, one set of materials, one lighting model, one person who can press Play and trust that the iPhone and the Pixel will agree. Determinism is not a graphics-nerd luxury. It is how you stop the Friday argument about whose build is the source of truth. When the product *is* the pixels, industry already picked an embedded engine. That is precedent one. I want you to steal the lesson, not the engine. Steal “one picture, one team.” Leave the 100-megabyte crate on the shelf.

Precedent two sits at the other extreme, and I need you to let me concede it. Open Facebook. Open Instagram. Open Amazon. Settings, Help, Terms of Service — a lot of that is a WebView sitting inside a native chrome. That is not a failure of craft. Legal copy changes weekly. A help center is a CMS problem. Nobody in this room needs one hundred and twenty frames per second to read a privacy policy. Building two native table hierarchies for text that legal will rewrite on Thursday is a poor allocation of senior engineers.

If you sound anti-web in a room of native developers, they will stop listening, and they should. WebViews are the right tool until they are not. The ceiling is the point.

A WebView is a document compositor. It is excellent at text, forms, and content you want to update without an App Store review. It is a bad place to put deterministic physics. It is a bad place to put a fragment shader over a live scrolling tree. It is a bad place to put a three-dimensional island you can walk around.

You will feel the ceiling in a specific way, and I want you to watch for it in the demo. Layout thrash. Blur. A JavaScript loop that looks innocent in desktop Chrome and dies on a thermal-throttled phone. A page cadence that falls off the native display link while the tab bar stays buttery. The host is fine. The document is not. On iOS you also have a second process — WebKit content, network, GPU — that your host `phys_footprint` will not fully confess. If someone tells you “the WebView is cheap because the HUD did not move,” ask them which process they measured.

So we have a missing middle. Pure native: peak OS integration, terrible duplication cost for identical canvas work. WebView: cheap and dynamic, hard performance ceiling. Where does the branded promo go? The in-app game? The liquid glass that design saw in a keynote? The 3D configurator? That is the gap. The rest of this hour is how we fill it without burning the native app down.

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

**CUT-FIRST if you are over time — start here:** People ask, “Isn’t that just Unity in an app?” Conceptually, yes: you asked for a unified 2D and 3D canvas. The invoice is different. Unity as a library is often a three-to-six-second load and fifty to a hundred megabytes of baggage. Flutter is not free. I will not stand here and say it is free. It is a different invoice: smaller binary, faster spawn, incremental engines that are closer to “another image” than “another runtime.” If you only remember one contrast, remember spawn time and incremental RAM, not a holy war about which engine is morally native.

Impeller, one sentence, and then I will not say Impeller again until the cat dies: shaders compile ahead of time to Metal and Vulkan, so the first time a flame dissolve runs you should not hitch from a runtime compile. That is the 2019 scar a lot of you still have. The scar was real. The compiler story changed.

Leave this cheat sheet up for the rest of the hour. Native: shell, forms, OS APIs. WebView: legal, FAQ, CMS. Flutter canvas: game, shader glass, 3D. That is the whole decision matrix. We are about to prove it on a phone instead of a slide.

---

## Act 5 — Heartbreak (28:00–33:00)

I have given you precedents and a board. Here is the story every dual-platform team already knows. I am not going to put five bullet points behind me and read them. I am going to say it once, because you have lived it.

Design ships a physics-heavy interaction. A spring. A dissolve. A card that feels like it has weight. It is beautiful in the prototype. It is the reason someone would open the app instead of the competitor. The room gets quiet in the good way.

iOS spends two weeks in Core Animation. Maybe a custom `CADisplayLink` driver. It ships. It is gorgeous. The designer hugs the iOS engineer. This is the part of the job we actually like.

Android looks at the same spec and says the true thing: three sprints, and it might drop frames on the devices we actually have in market, not the flagship on the poster. There is no shame in that sentence. The platforms are different. The APIs are different. The GPU story is different. “Just port the animation” is not a ticket. It is a second product.

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
- [ ] If still over: shorten Act 2 WebView examples (keep the ceiling); do not cut the 8.3 ms board
- [ ] If under 31:00: add one concrete “cancelled animation” from your own team at the start of Act 5, and slow the board drawing — do not improvise new architecture
- [ ] Confirm you can draw all four boards in [THEORY_BOARDS.md](THEORY_BOARDS.md) without looking
- [ ] Stage business that is already in the clock: show of hands (~20s), four boards drawn while talking (do not add a silent drawing act), one sip of water after Act 3

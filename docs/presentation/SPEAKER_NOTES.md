# The High-Performance Hybrid — speaker notes

The original flow is preserved: native strengths → the repeated work → examples of sharing → Flutter use cases → a native app demo.

Keep the conversation centered on what a team can ship. Use the technical details only when a question needs them. Aim for roughly 25–30 minutes of slides, 10–15 minutes of demo, and the remaining time for questions.

## 1 — The High-Performance Hybrid

“Today I want to look at a way to bring rich visual experiences into the native apps we already build. The idea is to share the work for a feature that should look and feel the same on iOS and Android.”

Keep the original talk title exactly as shown. The cover is a concept illustration; the live app comes later.

## 2 — Native sets the bar.

“Native gives us a strong foundation: platform integration, background capabilities, widgets, and the familiar feel of the operating system. That is a good place for the core app.”

Use one example from your own work. Establish common ground with the audience.

## 3 — We have tried sharing UI before.

“The wish to build once has been around for a long time. Many of us tried tools that promised it. What we cared about was whether the final experience felt right.”

If you used one of these tools, tell one short personal story. Keep this to about a minute; it sets up the audience’s understandable skepticism.

## 4 — One feature. Two platform builds.

“Now imagine a new promotion: an object you can grab, throw, and tap. The design needs to work on both platforms. Every change to the motion or interaction becomes work in two implementations.”

Both phone sketches intentionally show the same design. Talk about duplicated effort rather than differences in what the platforms can do.

## 5 — Could AI solve the double build?

“AI can help us create both versions faster. We still need to look at how the experiences feel, keep them aligned, and carry future changes into both.”

Keep this as a brief acknowledgement of an obvious audience question. Return to the feature and its maintenance.

## 6 — Who here uses something besides native UI?

Ask the question on the slide and take one or two answers. Follow with: “What made it worth using?”

Connect the answer to a concrete benefit: shared content, a faster workflow, an existing team skill, or an experience that was easier to make with a specialized tool.

## 7 — WebView works well for content.

“We already make this choice for content: help pages, legal text, or content from a CMS. We use a tool whose workflow fits that part of the app.”

Web technology can also build sophisticated graphics. Present these as familiar examples of fit, without claiming a universal graphics or performance limit.

## 8 — Where else is the tradeoff worth it?

“Mobile games give us another familiar example. Teams often choose a shared engine because of the experience and workflow it helps them create.”

This is a short transition into Unity, not a second audience discussion.

## 9 — Games choose tools for the experience.

“Unity reports that more than 70% of the top 1,000 mobile games are made with Unity. The useful lesson is that teams balance the experience they want with their tools and build effort.”

The source is Unity’s company page, citing Apptopia’s January 2025 monthly-active-user rankings, blended across the top 1,000 games in each of the Google Play and iOS App stores. The statistic describes adoption; it does not establish comparative performance.

Keep the discussion on scenes, animation, and content creation. A deep engine comparison belongs in questions.

## 10 — The missing middle.

“Back in an everyday app, we sometimes want a small part of that richness: a playful promotion, a mini-game, or a product people can turn around and explore.”

Describe the user’s action in each example. Make the feature easy to imagine before naming its implementation.

## 11 — A focused canvas: Flutter.

“This is where I have been exploring Flutter: a shared visual canvas for animation, mini-games, shaders, and interactive 3D inside a native app.”

Use it as the answer to the use cases just introduced. Avoid a tour of rendering APIs.

## 12 — One guest. One job.

“A feature needs a role. It can give people a reason to return, help them understand a product, create a memorable branded moment, or let them play with an object.”

Pick two examples that suit the audience’s apps. Explain the product purpose before the visual effect.

## 13 — No rewrite.

“The native app can stay in charge of the familiar app experience. The shared canvas lives inside it, in the place where that visual feature is useful.”

The diagram is a schematic excerpt of the badge tile. It is not a screenshot of the entire Shop page. Keep the explanation to the visible native/Flutter boundary.

## 14 — A screen, or a small part of one.

“A shared experience might have a whole tab, like our game. It might also be one tile in a native product page, like the badge.”

This is the practical adoption point: the feature determines how much of the screen is shared. Save engine counts and embedding APIs for questions.

## 15 — The experience connects to your app.

“The visual feature can participate in the product. Finish a game and see the score on Home. Tap the badge and see a promotion applied in the native Shop screen.”

Keep the app actions concrete. If asked how: Flutter sends an event, and the host owns the corresponding app update.

## 16 — A tradeoff worth making?

“We can save duplicated visual implementation and share interaction behavior. We also add a runtime, an integration, and a tool to maintain. Whether that is worthwhile depends on our actual feature and team.”

Keep the costs honest and brief. Quote device results only when they have been recorded. Avoid generic memory numbers or star ratings.

## 17 — Choose the tool for the experience.

“Native, web content, and a shared visual canvas can each have a useful place. These examples are starting points. Our feature and our team’s skills decide.”

These are examples, not strict capability boundaries. Keep the framework debate for Q&A.

## 18 — One native app. Several experiences.

“Here is the demo: native Home, web Help, a game, a Shop with Flutter inside it, and an interactive island. The same five tabs are present on iOS and Android.”

Give the audience a quick map of what they are about to see.

## 19 — Let’s see the demo.

1. Start on native Home to establish the app context.
2. Open Help. Show the familiar content use case briefly.
3. Play Game. Return Home and show the native score update.
4. Open Shop. Drag, throw, and spin the badge. Tap it and point out `HOLO20` in the native promo field and the price changing from $249.00 to $199.20.
5. Explore Island: orbit, change the time of day, and move the character.
6. Repeat the key Shop interaction on Android to show the shared experience in the second native host.

Talk about what people can do in each experience. Use the HUD to answer a specific performance question if helpful; avoid narrating every number. A Web Stress Test is deliberately injected work and should be labeled if shown.

Close the demo with: “This gives us another way to share the work for a rich visual feature while keeping it connected to our native app.”

## 20 — Questions.

Leave the castle QR and repository URL visible. The QR encodes:

https://github.com/theamorn/flutter-inapp-ios

The castle artwork was decoded successfully by Apple Vision at its original size, 520 px, and 320 px. Rehearse scanning from the actual projected slide, since camera distance and projection quality affect practical scanning.

## Rehearsal reminders

- Use physical devices and Release builds for any performance observations. Record numerical claims in [MEASUREMENTS.md](../hybrid-demo/MEASUREMENTS.md), which currently has pending device results.
- Confirm the two native updates before presenting: Game → Home score and badge → Shop promotion.
- Keep a recording of the demo available. Check the final QR on the projected screen.

## Optional technical answers

Keep these off the main talk unless asked:

- The demo uses a FlutterEngineGroup and five feature engines. Shop has three inline Flutter regions. This topology is a demo choice, not an entry requirement.
- Retained engines use memory. Visibility and lifecycle handling need an explicit integration policy.
- The host owns the demo promo validation and price update. Production products should preserve their existing authoritative validation path.
- Callback cadence is not a count of all physically presented content frames. The HUD’s UI/raster readings are averages; engine creation duration is not time to first visible frame.
- The island uses the experimental flutter_scene / Flutter GPU stack, a separate choice from standard Flutter embedding.

## Sources

- [Unity company statistics and methodology](https://unity.com/our-company)
- [Flutter add-to-app](https://docs.flutter.dev/add-to-app)
- [Multiple Flutter instances](https://docs.flutter.dev/add-to-app/multiple-flutters)
- [WebGL capabilities](https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API)
- [QR artwork prompt and generation details](../../deck-images/qr-castle-prompt.txt)

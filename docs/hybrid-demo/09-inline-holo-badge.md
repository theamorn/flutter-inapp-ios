# 09 — Tab 4: Shop, with Flutter as one tile inside a native page

## Goal

Every other Flutter tab gives Flutter the whole screen. This one shows the most common production pattern instead: **Flutter as one component inside a native screen**.

Tab 4 is a native product page for a made-up product, "Nimbus One" headphones: UIKit on iOS, Material 3 Compose on Android. Halfway down the page sits a 340pt/dp Flutter tile holding a holographic member badge on a lanyard.

- **Grab, throw, spin.** The badge swings on a verlet strap, bounces off the tile walls with sparks and a light haptic, and spins around the strap when thrown sideways.
- **Scrolling pushes it.** A hard fling of the native page makes the badge jump and swing.
- **Tap to claim.** Tapping flips the badge to show `CODE HOLO20 ✓`. Flutter then calls back with the code, and the **native** page puts it in a native promo text field below "Driver", validates it natively, and reprices ($249.00 → $199.20). Flutter draws; native owns the data.
- **Off screen, off.** With the tile scrolled away, the HUD reads `/promo no recent frames` while host cadence continues.

For the talk, this is the "branded promo" item on the "pictures that must match" list. The two shells differ; the tile is identical on both.

## Prerequisites

- `02-ios-host.md` and `07-android-host.md` complete: engine group, HUD, tab shells.
- Read the **Inline tile** section of `ARCHITECTURE.md`. It holds the `/promo` route, the `com.theamorn.hybrid/promo` channel table, touch ownership, and pausing.

## Repo facts you need

- The Flutter side lives in `flutter_module/lib/tabs/promo/`. All logic is pure Dart and unit-tested, in the style of `lib/tabs/scene/ball_physics.dart`:
  - `lanyard_physics.dart`: strap and card.
  - `badge_spin.dart`: spin around the strap.
  - `scroll_push.dart`: host scroll → pseudo-force.
  - `promo_run_gate.dart`: pause decision.
  - `promo_host_link.dart`: channel, `badgeBounds` throttle.
  
  Flame rendering is in `holo_card_game.dart`, `holo_badge.dart`, `lanyard.dart` and `sparkles.dart`, and the shader is `shaders/holo_foil.glsl`.
- The card is a **rigid body** built from five verlet particles. Every correction to a card point goes through `_pushCard`, a rigid-body position correction weighted by mass and inertia. That is what makes the strap hold the card at the hole, so a tilted card swings back upright, and what lets a wall contact spin it.
- **iOS:** `ProductDetailViewController.swift` holds the page, `ProductScrollView` (touch ownership) and the promo field. `InlineFlutterCardViewController.swift` holds the tile and its channel. `FlutterRouteHosting` tells the HUD which engine a tab shows.
- **Android:** `ShopScreen.kt` holds the page and the promo field, reusing `HomeScreen.kt`'s `SectionCard` and row helpers. `InlineFlutterTile.kt` holds `PromoTileController` (the channel) and the `FlutterView` host. `TabsActivity.kt` forwards the activity lifecycle and window focus to the `/promo` engine, because no fragment does it.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/lib/tabs/promo/*` | **new**: physics, game, rendering, host link, app |
| `flutter_module/shaders/holo_foil.glsl` | **new**, listed under `flutter: shaders:` |
| `flutter_module/lib/main.dart` | dispatch and telemetry for `/promo` |
| `flutter_module/test/tabs/promo/*` | **new**: 50 tests |
| `cool-ios/cool-ios/ProductDetailViewController.swift` | **new** |
| `cool-ios/cool-ios/InlineFlutterCardViewController.swift` | **new** |
| `cool-ios/cool-ios/{AppEngines,MainTabBarController,FlutterTabViewController,PerformanceHUDView}.swift` | `/promo` route and channel, Shop tab, `FlutterRouteHosting`, HUD order |
| `cool-ios/cool-iosUITests/cool_iosUITests.swift` | end-to-end Shop test |
| `cool-android/.../ShopScreen.kt`, `InlineFlutterTile.kt` | **new** |
| `cool-android/.../{TabsActivity,AppEngines,PerformanceHud,HomeScreen}.kt` | Shop tab, lifecycle forwarding, `/promo`, HUD order, `internal` row helpers |

## Implementation notes

- **The foil shader** draws into the card's own rect.
  - `FlutterFragCoord()` is card-local under Impeller, so the pattern stays on the card through rotation and perspective. This was confirmed on the simulator: the rounded-corner mask lines up with a thrown, rotated card.
  - Layers: rainbow thin-film bands, fine striations, soft cloud, a glare spot that follows the light, per-cell glitter, a moving highlight band, an edge glow and a gold shift once claimed.
  - The light drifts slowly on its own, so a still badge never looks dead.
- **3D from 2D physics:** the physics is planar. `BadgeSpin` adds the spin around the strap, and the renderer turns it into `rotateY` with perspective. It also adds `rotateX` from scroll position and angular velocity.
- **Scroll push:** the host sends content-offset *velocity*, and Dart differences it into an acceleration that pushes the badge (`+d(velocity)/dt` points down in the tile). Samples closer than 4ms apart are skipped, because Compose layout can report twice in a frame.
- **Promo field:** the claim callback carries only the code. Each host fills its field, briefly tints it, then runs the same validation a typed code would. Once applied, the field turns read-only in brand color with a check mark, not disabled: disabled greys out exactly what the audience should read.

## Gotchas

- **Never squash a blurred shape with a canvas scale.** The badge shadow first narrowed with `canvas.scale(|cos yaw|, 1)`. Near edge-on, that makes the blur many times wider in local space. Measured on the Android emulator, raster during a flip went from about 48 ms to 220–630 ms. Narrowing the rect instead keeps flips at the settled cost.
- **iOS safe area:** a view inside a scroll view gets changing `safeAreaInsets` as it slides under bars, and `FlutterViewController` forwards those as viewport metrics. The Shop scroll view is pinned to the safe area to avoid this. **Android's equivalent:** consume window insets on the `FlutterView`.
- **Android `FlutterView` without a fragment:**
  - no `PlatformPlugin`, so `HapticFeedback` goes unanswered;
  - no lifecycle or window-focus forwarding;
  - `LazyColumn` would dispose the tile off screen, so the page uses a plain `Column`.
- **Early pushes can be dropped.** Messages sent before Dart registers its handler may be lost, so Dart pulls its starting state with `ready`.
- **UI tests on iOS:** signing in raises the system "Save Password?" sheet, which swallows every gesture until it's dismissed. A test that doesn't dismiss it can pass for the wrong reason: "a drag on the badge did not scroll the page" is also true when *nothing* can scroll. The test therefore asserts the page did scroll.

## Acceptance criteria

- Shop tab on both hosts; the badge hangs mid-page; the engine spawns on the first Shop visit only.
- A drag starting on the badge moves the badge and not the page. A drag starting beside the badge, on the page or the tile's empty area, scrolls the page.
- Tapping the badge fills the native promo field with `HOLO20`, and the native price becomes $199.20. Typing `HOLO20` and tapping Apply does the same through the same native path.
- With the tile off screen, the HUD shows `/promo no recent frames`.

## How to verify

```sh
cd flutter_module && fvm flutter analyze && fvm flutter test          # all green

cd cool-ios && xcodebuild -workspace cool-ios.xcworkspace -scheme cool-ios \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:cool-iosUITests/cool_iosUITests/testShopBadgeOwnsItsDragsAndClaimsTheNativePrice test

cd cool-android && ./gradlew :app:assembleDebug
```

The iOS UI test covers touch ownership in both directions, the Flutter → native promo field, and the native price. On Android, drive it by hand or with `adb shell input`. Checked in development:
- A drag on the badge left the page offset unchanged, and a drag in the margin scrolled it.
- The claim filled the field and repriced.
- The HUD showed `no recent frames` off screen.

Performance numbers come from **physical devices in release mode** only (`README.md`). Simulator and emulator figures, including the emulator's software-GL raster times above, are for comparing before and after, not for the stage. Record device numbers in `MEASUREMENTS.md`.

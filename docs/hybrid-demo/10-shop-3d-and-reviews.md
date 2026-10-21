# 10 — Tab 4: Shop, with a 3D header and a Liquid Glass Review Details tab

## Goal

`09` put Flutter in one tile of a native page. This adds two more Flutter views to the same page, so one screen shows three ways to share it:

- **3D header (`/product`).** Above "Nimbus One", the flat headphone icon becomes real 3D headphones in `flutter_scene`: satin-silver band, midnight anodized cups, spun-metal cap plates, chrome sliders, leather cushions. Any drag that starts on the header turns and tilts them. Letting go keeps them turning and slowing (a fling), and after 2 s without a touch they spin slowly and level out. They stand in a park (Poly Haven's CC0 "Symmetrical Garden 02"), soft behind them like a portrait lens. The camera and the park stay put, so the trees, hedges, and sky slide across the metal as it turns.
- **Native tabs.** A native control sits right below the price: a `UISegmentedControl` on iOS and a Material 3 `PrimaryTabRow` on Android. It has two tabs:
  - **Overview** is the native page from `09`, promo tile included.
  - **Review Details (`/reviews`)** is all Flutter.
- **iOS 27 glass on Android.** Review Details draws a rating summary, eight filter chips in a sideways-scrolling row (tap "All" and the star chips fly into it and melt into one "All ★" pill; tap that and they split back out), and a "Write a review" button in Liquid Glass (`liquid_glass_renderer` 1.0, iOS 27 presets). Under them, the review cards are glass too, over soft pools of colour, with a band of light that sweeps across each card as it scrolls. The same pixels appear on both hosts, and Android has nothing native like it.

## Prerequisites

- `09-inline-holo-badge.md` (the Shop page, `ProductScrollView`, the bare-`FlutterView` embedding on Android).
- Flutter **3.47.7**. `liquid_glass_renderer` 1.0 needs Flutter 3.47 or newer, Impeller, and Flutter GPU. Both hosts already enable Flutter GPU for `flutter_scene` (`01-scene-spike.md`).

## Repo facts you need

- **Routes and channels:** `/product` on `com.theamorn.hybrid/product`, and `/reviews` on `com.theamorn.hybrid/reviews`. The contract table is in `ARCHITECTURE.md`, under "Shop header and Review Details".
- **The model is code, not a file.** `nimbus_headphones.dart` builds every part as a smooth surface: `revolve()` turns a 2D profile around an axis with authored normals and tangents (band, pad, cup shells, cap plates, cushions), and `TubeGeometry` sweeps the yokes. The first attempt, a 472-triangle CC0 `.glb`, read as blocky, and flat facets cannot carry a continuous reflection.
- **`liquid_glass_renderer` 1.0 renamed the material.** `LiquidGlassSettings` holds the optics (`refractionHeight`, `refractionAmount`, `frost`, `dispersion`, `highlight`, …). Color moved to a per-shape `LiquidGlassAppearance` (`tint`, `colorModel`). `lightAngle` and `ambientStrength` are gone. `lib/tabs/glass/package_liquid_glass.dart` was migrated: its LIGHT slider is now HIGHLIGHT, with key `pkg-highlight`.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/lib/tabs/product/product_scene.dart` | **new**: owns the `Scene`, the park and the look, and the turn, fling, and idle spin |
| `flutter_module/lib/tabs/product/nimbus_headphones.dart` | **new**: the headphones and their materials, built in code |
| `flutter_module/assets/materials/nimbus_metal.fmat` | **new**: the metal shader; reflects the baked park itself (see Gotchas) |
| `flutter_module/assets/environments/` | **new**: the park HDR (sun capped at 20,000, see Gotchas), its three baked reflection levels, credits |
| `flutter_module/tool/bake_park_reflections.py` | **new**: bakes the reflection levels from the HDR |
| `flutter_module/lib/tabs/product/product_viewer_app.dart` | **new**: route `/product` |
| `flutter_module/lib/tabs/reviews/review_details_app.dart` | **new**: route `/reviews` |
| `flutter_module/lib/tabs/reviews/reviews_data.dart` | **new**: reviews. The first six match the native Overview reviews word for word. |
| `flutter_module/lib/tabs/shared/host_visibility_link.dart` | **new**: Dart half of the `visibility` / `ready` contract |
| `flutter_module/lib/main.dart` | two routes; `LiquidGlass.precache()` before `runApp` for `/reviews` and `/glass` |
| `cool-ios/cool-ios/EmbeddedFlutterViewController.swift` | **new**: one route as a view, with the iOS half of the contract |
| `cool-ios/cool-ios/ProductDetailViewController.swift` | 3D header, segmented control, Overview stack, reviews panel, `FlutterTouchOwner` |
| `cool-android/.../InlineFlutterTile.kt` | `BadgeTouchGate` → `FlutterViewGate(ownsTouch)`; `FlutterSurfaceController`; `EmbeddedFlutterView` |
| `cool-android/.../ShopScreen.kt` | 3D header, tab row, reviews panel |
| `cool-android/.../TabsActivity.kt` | spawns all three Shop engines; forwards the lifecycle to all three |

## Implementation notes

- **One engine per view.** Add-to-app gives each engine one view, so the page now spawns three engines: `/product`, `/promo`, and `/reviews`. All three spawn on the Shop tab's first appearance, never on the segment tap, because engine creation is synchronous and would hitch the tap.
- **Pinning the tabs.** Selecting Review Details hides Overview and animates the page so the tab control sits 8 below the top of the viewport. The panel is exactly the viewport's height minus the control's, so the page can scroll no further and the list inside the panel scrolls from there. Switching back restores Overview where the page was.
- **Who owns a drag.** Any drag that starts on the header or the panel is Flutter's. iOS `ProductScrollView` keeps a list of `FlutterTouchOwner`s: the promo tile (its badge only), the header, and the panel. Android's `FlutterViewGate` calls `requestDisallowInterceptTouchEvent(true)` when `ownsTouch` says so.
- **The look.**
  - **Header:** the `showcase` look from the `flutter_scene-looks` skill (ACES, soft bloom) without its screen-space passes, which cost the phone its 60 fps. The park is the skybox, decoded at 512 wide so it reads out of focus, and the environment. A soft directional light adds the sun's direct highlight. MSAA at full resolution keeps the chrome edges clean.
  - **Glass:** `LiquidGlassSettings.ios27Regular(brightness: light)` with the matching `LiquidGlassAppearance`. The selected chip is tinted blue glass, like a prominent iOS button. "All" and the four star chips share a `LiquidGlassBlendGroup` (`_RatingChips`), like iOS 27's `GlassEffectContainer`. The blend is zero while they are apart, so they sit as separate pills, and full once they have merged, so the hidden chips fuse into "All" without a seam. The group is always as wide as its chips reach: glass outside its box would draw unrounded and cover the next chip. `LiquidStretch` and `GlassGlow` give the press-and-stretch feel.
- **HUD.** Shop reports the view that owns the screen: `/product` on Overview, `/reviews` on Review Details. The ENGINES line lists all three spawns.

## Gotchas

- **`MaterialApp` with only `onGenerateInitialRoutes` builds no Navigator** and renders nothing, with no error. Pair it with `onGenerateRoute`, as `glass_app.dart` does.
- **`liquid_glass_renderer` falls back to `FakeGlass` silently** wherever Impeller shader filters or Flutter GPU are missing. Widget tests always use the fallback (the log says so). The real refraction has to be checked on a device, and on Android that means a device on Vulkan Impeller.
- **On the Adreno test phone (OnePlus CPH2499), the engine's prefiltered radiance comes back black.** Metal reflects nothing, and a skybox with any `blurriness` draws black; iOS renders both correctly. The phone's material inputs are right (the `metallic` and `specular` debug views read 1), and flutter_scene logs that the device samples only base mips (flutter#189965). So `nimbus_metal.fmat` reads the park from three baked, single-mip RGBM textures (512×256, 128×64, 32×16) blended by roughness, in its `Composite()` hook, with Karis's analytic environment BRDF. The skybox uses `blurriness: 0`, which samples the source.
- **An HDRI's sun can overflow fp16.** The park's brightest pixel is 65,536, past half-float's 65,504: it turns to infinity, and the environment and skybox render black. The shipped HDR caps it at 20,000.
- **Hot restart under `flutter attach` loses flutter_scene's hook-built shaders** in this add-to-app setup ("The physical material shaders are missing"). Iterate with release rebuilds.
- **Fixed heights inside glass overflow under other fonts.** The histogram rows share the summary card's height through `Expanded`, so any text scale fits.
- Toggling Overview off and back on Android disposes and recreates the promo tile's `FlutterView` (Compose removes the subtree). The engine and its state survive; only the view reattaches.

## Acceptance criteria

- [ ] On both hosts, the header shows the 3D headphones in the blurred park, with the park reflected in the silver band, chrome, and cup plates. A drag on the header turns them and does not scroll the page. After 2 s idle they turn slowly. The phone holds 60 fps.
- [ ] "Review Details" pins the native tab control to the top. A drag in the panel scrolls the review cards under the glass, not the page.
- [ ] The filter chips sit as separate pills, scroll sideways, and filter (or, for "Most helpful", sort) the list. "All" merges the star chips into one pill with a liquid melt, and tapping that pill splits them again. "Write a review" responds.
- [ ] "Overview" brings back the native page, and the badge claim still reprices ($249.00 → $199.20).
- [ ] With the header scrolled off screen or another tab selected, `/product` logs `render loop stopped`, and the HUD reads `no recent frames`.
- [ ] On a real Android device, the glass refracts the cards beneath it rather than only blurring them.

## How to verify

- `fvm flutter analyze` and `fvm flutter test` in `flutter_module`. The tests cover `test/tabs/shared/host_visibility_link_test.dart`, `test/tabs/reviews/review_details_app_test.dart`, and the migrated `test/liquid_glass_test.dart`.
- iOS: `testShopHeaderOrbitsAndReviewDetailsPinsTheTabs` in `cool-iosUITests` signs in, orbits the header, pins the tabs, scrolls the panel, and attaches screenshots of each step. Export them with `xcrun xcresulttool export attachments`. `testShopBadgeOwnsItsDragsAndClaimsTheNativePrice` must still pass.
- Android: `./gradlew :app:installRelease`, then the same steps by hand or with `adb shell input swipe`, and `adb exec-out screencap -p` for screenshots.

# 02 — iOS host: login → 5-tab shell, engine group, HUD

## Goal

Restructure `cool-ios` from "login screen with a button that presents Flutter" into "login screen → native 5-tab app, with three Flutter tabs hosted as child view controllers under a native tab bar, and a performance HUD visible on every tab."

This is the backbone. Tabs 1–5 content lands in `03`–`06`; this task builds the shell, the engine plumbing, and the HUD.

## Prerequisites

- `00-toolchain.md` complete.
- `01-scene-spike.md` complete (it sets `FLTEnableFlutterGPU` in the same Info.plist you edit here).
- Read `ARCHITECTURE.md` — engine topology, route names, channel names, telemetry contract.

## Repo facts you need

- `cool-ios/cool-ios/ViewController.swift` is the current login screen: fully programmatic UIKit (no XIB), scroll view + gradient layer + logo + username/password fields + Sign In button + a purple "Launch Flutter Demo" button + a status label.
- Its `submitRequest()` method creates a `FlutterEngine`, builds a `FlutterMethodChannel` on `com.theamorn.flutter`, wires `invokeMethod` / `setMethodCallHandler`, and presents a `FlutterViewController` modally. **This is the reference pattern for channel setup** — read it before writing the telemetry channel.
- `cool-ios/cool-ios/Base.lproj/Main.storyboard` has `initialViewController="BYZ-38-t0r"` with `customClass="ViewController"`, `customModule="cool_ios"`. If you rename the class, update the storyboard or the app crashes at launch.
- `AppDelegate.swift` is stock and creates no engine today. `SceneDelegate.swift` is stock; `window` is initialized by the storyboard.
- The app currently holds `lazy var flutterEngine = FlutterEngine(name: "my engine")` on the view controller. That ownership moves to `AppEngines`.

## Files to create/modify

| File | Change |
|---|---|
| `ViewController.swift` → `LoginViewController.swift` | rename class + file; strip Flutter presentation |
| `Base.lproj/Main.storyboard` | point `customClass` at the renamed class |
| `AppEngines.swift` | **new** — owns the `FlutterEngineGroup`, vends engines, measures spawn cost |
| `MainTabBarController.swift` | **new** — 5 tabs |
| `FlutterTabViewController.swift` | **new** — reusable Flutter-as-child container |
| `PerformanceHUDView.swift` | **new** — FPS + memory overlay |
| `Info.plist` | `CADisableMinimumFrameDurationOnPhone`, `FLTEnableFlutterGPU` |
| `flutter_module/lib/main.dart` | route dispatch per `ARCHITECTURE.md` |
| `flutter_module/lib/telemetry/` | **new** — `addTimingsCallback` → method channel |

## Implementation notes

### `LoginViewController`

Keep the existing UI wholesale — the gradient, the field styling, the button press animations. It reads as a real app, which is the point of tab 1's argument.

Changes: delete `submitRequest()` and the purple "Launch Flutter Demo" button (the tab bar replaces it), and delete the `flutterEngine` property. `loginButtonTapped` keeps its validation and its scale animation, but on success swaps the window root instead of showing an alert:

```swift
let tabs = MainTabBarController()
guard let window = view.window else { return }
window.rootViewController = tabs
UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve,
                  animations: {}, completion: nil)
```

No real auth. Any non-empty username and password proceeds.

### `AppEngines`

Owns the one `FlutterEngineGroup` (name from `ARCHITECTURE.md`) and vends engines by route, creating each on first request:

```swift
final class AppEngines {
    static let shared = AppEngines()
    private let group = FlutterEngineGroup(name: "hybrid-demo", project: nil)
    private var engines: [String: FlutterEngine] = [:]

    func engine(forRoute route: String) -> FlutterEngine {
        if let existing = engines[route] { return existing }
        let before = MemoryProbe.footprintBytes()
        let options = FlutterEngineGroupOptions()
        options.initialRoute = route
        let engine = group.makeEngine(with: options)
        let after = MemoryProbe.footprintBytes()
        PerformanceHUDView.shared.recordEngineSpawn(route: route, deltaBytes: after - before)
        engines[route] = engine
        return engine
    }
}
```

Also attach the telemetry `FlutterMethodChannel` (`com.theamorn.hybrid/telemetry`) to each engine's `binaryMessenger` as it is created, forwarding samples into the HUD.

**Do not pre-warm engines at launch.** Lazy creation is load-bearing — see `ARCHITECTURE.md`.

### `FlutterTabViewController`

A reusable container that embeds a `FlutterViewController` as a **child view controller**, so the native tab bar stays visible above it. This is the whole "we didn't rewrite the app" point made visually.

```swift
let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
addChild(flutterVC)
flutterVC.view.translatesAutoresizingMaskIntoConstraints = false
flutterVC.view.backgroundColor = .clear
view.addSubview(flutterVC.view)
// pin to view bounds
flutterVC.didMove(toParent: self)
```

`backgroundColor = .clear` avoids a white flash on first appearance. Do **not** present the Flutter VC modally or push it — modal presentation covers the tab bar and destroys the argument.

### `PerformanceHUDView`

Add it to the **window**, not to any tab's view, so it survives tab switches and sits above the tab bar. Content per `ARCHITECTURE.md`: host FPS (`CADisplayLink`), process memory (`task_vm_info.phys_footprint`), the Flutter-reported UI/raster numbers from the telemetry channel, and the engine-spawn deltas recorded by `AppEngines`.

Keep it small, high-contrast, and legible from the back of a room — this gets projected.

### Dart side

Implement the route dispatch in `main.dart` exactly as specified in `ARCHITECTURE.md`, keeping `/` on the existing demo home. Add a telemetry reporter that registers `SchedulerBinding.instance.addTimingsCallback` and pushes averaged samples over the channel. Batch them — do not send one message per frame, or the channel traffic becomes its own performance problem at 120fps.

Until `03`–`06` land, back each tab with a placeholder so the shell is runnable and the HUD is testable.

## Gotchas

- **Rename the storyboard's `customClass` when you rename the class.** Otherwise the app crashes at launch with an unhelpful "Unknown class" message.
- Adding a `FlutterViewController` as a child requires the full dance: `addChild` → `addSubview` → constraints → `didMove(toParent:)`. Skipping `didMove` breaks appearance callbacks and the Flutter view may never render.
- The HUD must not be parented inside a tab, or it will disappear on tab switch and re-create itself, losing its rolling averages.
- Sending telemetry per-frame at 120fps will itself cause jank. Batch and average.

## Acceptance criteria

- [ ] Login → tab bar transition works; back-navigation to login is not possible (root is swapped, not pushed).
- [ ] Five tabs exist and are switchable, with placeholders where content is pending.
- [ ] The native tab bar remains visible while a Flutter tab is on screen.
- [ ] Engines are created on first tab appearance, not at launch, and the HUD shows a memory delta at that moment.
- [ ] Switching away from and back to a Flutter tab preserves its state and shows no white flash or reload.
- [ ] The HUD is visible on all five tabs and shows both host and Flutter numbers.
- [ ] `Info.plist` contains both `CADisableMinimumFrameDurationOnPhone` and `FLTEnableFlutterGPU`.
- [ ] `flutter run` on `flutter_module` alone still opens the old demo home via route `/`.

## How to verify

Physical device, release mode.

1. Log in. Tab through all five tabs. Watch the HUD memory readout jump as each of the three Flutter engines spawns; note the three deltas — these are the numbers quoted on stage.
2. Tab 3 → tab 1 → tab 3. State must be exactly as left. No flash, no reload.
3. Background the app, foreground it, tab around again. No crash, no black Flutter views.
4. Confirm the HUD reads ~120 on a ProMotion device. If it reads 60, `CADisableMinimumFrameDurationOnPhone` is missing or misspelled.
5. `cd flutter_module && fvm flutter run` — the standalone dev home still appears.

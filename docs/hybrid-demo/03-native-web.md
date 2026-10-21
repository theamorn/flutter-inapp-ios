# 03 — Tab 1 (native UIKit) and Tab 2 (WKWebView)

## Goal

Build the two non-Flutter tabs. Together they establish the demo's baseline and its foil: tab 1 is what native does well, tab 2 is what the industry already reaches for and where its ceiling is.

## Prerequisites

- `02-ios-host.md` complete (tab shell + HUD exist).

## Repo facts you need

- `cool-ios` is programmatic UIKit throughout. `ViewController.swift` (now `LoginViewController.swift`) is the style reference: `translatesAutoresizingMaskIntoConstraints = false`, explicit `NSLayoutConstraint.activate([...])`, SF Symbols via `UIImage(systemName:)`, system colours (`.label`, `.secondaryLabel`, `.systemBackground`, `.secondarySystemBackground`). Match it.
- The HUD from `02` is already on the window and needs no per-tab wiring.

## Files to create/modify

| File | Change |
|---|---|
| `cool-ios/cool-ios/HomeViewController.swift` | **new** — tab 1 |
| `cool-ios/cool-ios/SettingsWebViewController.swift` | **new** — tab 2 |
| `cool-ios/cool-ios/Resources/settings.html` | **new** — bundled page |
| `cool-ios/cool-ios.xcodeproj` | add `settings.html` to Copy Bundle Resources |
| `MainTabBarController.swift` | swap placeholders for the real two |

## Implementation notes

### Tab 1 — `HomeViewController`

A profile/dashboard screen. `UITableView` with grouped sections, plus `UISwitch`, `UISegmentedControl`, `UIButton`, an avatar, some rows.

**Make it deliberately ordinary.** Its job is to be indistinguishable from any shipping native app and to sit pinned at 120fps on the HUD. Resist making it clever — a flashy tab 1 undercuts the argument, which is that this screen is *already fine* and nobody should rewrite it.

Give it enough rows to scroll meaningfully, so the HUD has something to report during scroll and the comparison with tab 2 is like-for-like.

Note for `07-android-host.md`: the Android Home tab mirrors this **layout** using Material components. Same information architecture, visibly different controls. Keep the structure simple enough to mirror.

### Tab 2 — `SettingsWebViewController`

A `WKWebView` filling the tab, loading a **local bundled `settings.html`**:

```swift
guard let url = Bundle.main.url(forResource: "settings", withExtension: "html") else { return }
webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
```

**Local, not hosted.** Conference wifi will fail you, and a demo that needs the network is a demo that dies on stage. See `08-polish.md` — the whole app must pass an airplane-mode run.

`settings.html` content: an advanced settings and telemetry dashboard with sections, search filters, interactive sliders, switches, live SVG sparklines, and a segmented toggle between **Normal Web** and **Stress Test**.

- **Normal Web**: Regular page styling and passive scrolling. Its frame cadence is measured; 60/120fps is not promised.
- **Stress Test**: Explicitly synthetic workload: forced layout, a 16ms JavaScript busy loop per callback, extra scroll work, and heavy blur. Both modes use the same uncapped `requestAnimationFrame` interval measurement, refreshed at most four times per second.

Include real compositing work — `backdrop-filter: blur()`, box shadows, a sticky header, rounded overflow clipping. This is representative of what real in-app web content looks like, and it gives the HUD something honest to react to under scroll.

## The talk track — say this out loud on stage

**Present the WebView as correct.** The strongest version of the argument concedes the point: a settings page whose copy and rows change weekly, that needs to ship without an app release, genuinely belongs in a WebView. That is the right engineering call and you would ship it.

Show Normal first, then explain that **Stress Test deliberately injects work** before enabling it. Compare the page's measured rAF cadence with the native host cadence. This demonstrates the effect of the chosen workload, not an intrinsic ceiling of every WebView. Layout and JavaScript run in WebKit's separate content process, so the native HUD can remain smooth while the page stalls; see `ARCHITECTURE.md`.

Conceding tab 2 is what buys credibility for tabs 3–5. An audience that watches you strawman a WebView will discount everything you claim about Flutter afterwards. An audience that watches you defend one and *then* show its ceiling will believe the rest.

## Gotchas

- `settings.html` must be in **Copy Bundle Resources** in the Xcode target, or `Bundle.main.url(forResource:)` returns nil and the tab is blank. Adding the file to the project navigator alone does not do this — check the target's Build Phases.
- Use `loadFileURL(_:allowingReadAccessTo:)`, not `load(URLRequest(url:))`, for file URLs. The latter is blocked by WKWebView's file access rules.
- Don't disable `WKWebView` scrolling or bounce. The demo depends on scrolling it hard.
- The native HUD and page meter sample different execution paths. Do not manipulate load or displayed values to force an expected host-number drop.
- Navigation is restricted to the bundled file and its anchors. The Content Security Policy blocks remote resources; a link containing a `#fragment` must not bypass the native navigation guard.
- The page's `Layout probes` counts requested stress operations, not actual WebKit layout passes. `Intervals >32ms` is a fixed callback-interval threshold, not a count of missed refresh deadlines.
- The native tab lifecycle pauses the page loop, and WebKit content-process termination reloads the local page.

## Acceptance criteria

- [ ] Tab 1 renders a plausible native dashboard and scrolls at the device's full refresh rate on the HUD.
- [ ] Tab 2 loads `settings.html` from the bundle with no network access.
- [x] Tab 2 features an interactive toggle between Normal Web and a clearly labeled synthetic Stress Test.
- [ ] Normal Web scrolling and measured cadence verified on a physical device.
- [ ] Stress Test produces a recorded page-cadence change under the specified workload; host cadence is recorded separately without assuming it must fall.
- [ ] Both tabs work in airplane mode.

## How to verify

Physical device, release mode, **airplane mode on**.

1. Tab 1: scroll hard. HUD should sit at the device's max refresh rate.
2. Tab 2: repeat the same scroll in Normal and Stress Test modes. Record both the native and page meter; their values need not match.
3. Exercise search, filters, toggles, sliders, and diagnostics. They should update local state without network access. Settings/profile/storage content is illustrative demo data.
4. Hide Web while stress is active and return to Home; verify the page workload pauses. Return to Web and confirm cadence starts a fresh measurement window.
5. Record device conditions and observed ranges in `MEASUREMENTS.md` before quoting numbers on stage.

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

`settings.html` content: an advanced settings and telemetry dashboard with sections, search filters, interactive sliders, switches, live SVG sparklines, and a segmented toggle between **Normal Web** and **Laggy Web**.

- **Normal Web Mode**: Hardware-accelerated, optimized styles, passive scroll, pinned 60/120 FPS.
- **Laggy Web Mode**: Injects forced synchronous layout thrashing (repeated geometry reads and style writes on scroll), main-thread micro-stalls, and heavy multi-layer `backdrop-filter: blur(55px)` to visibly demonstrate mobile web rendering bottlenecks and ceiling on the HUD.

Include real compositing work — `backdrop-filter: blur()`, box shadows, a sticky header, rounded overflow clipping. This is representative of what real in-app web content looks like, and it gives the HUD something honest to react to under scroll.

## The talk track — say this out loud on stage

**Present the WebView as correct.** The strongest version of the argument concedes the point: a settings page whose copy and rows change weekly, that needs to ship without an app release, genuinely belongs in a WebView. That is the right engineering call and you would ship it.

Then toggle on **Laggy Web** or scroll heavily, and let the HUD make the argument for you: show how mobile web engines hit their rendering ceiling when composite layers and reflow complexity stack up.

Conceding tab 2 is what buys credibility for tabs 3–5. An audience that watches you strawman a WebView will discount everything you claim about Flutter afterwards. An audience that watches you defend one and *then* show its ceiling will believe the rest.

## Gotchas

- `settings.html` must be in **Copy Bundle Resources** in the Xcode target, or `Bundle.main.url(forResource:)` returns nil and the tab is blank. Adding the file to the project navigator alone does not do this — check the target's Build Phases.
- Use `loadFileURL(_:allowingReadAccessTo:)`, not `load(URLRequest(url:))`, for file URLs. The latter is blocked by WKWebView's file access rules.
- Don't disable `WKWebView` scrolling or bounce. The demo depends on scrolling it hard.
- If the HUD shows no measurable difference between tabs 1 and 2, verify that Laggy mode is toggled on to demonstrate the ceiling under stress.

## Acceptance criteria

- [ ] Tab 1 renders a plausible native dashboard and scrolls at the device's full refresh rate on the HUD.
- [ ] Tab 2 loads `settings.html` from the bundle with no network access.
- [ ] Tab 2 features an interactive mode toggle between **Normal Web** and **Laggy Web**.
- [ ] Normal Web mode scrolls smoothly at 60/120 FPS with active telemetry.
- [ ] Laggy Web mode produces visible stutter, layout thrashing, and a **visible, reproducible** drop in the HUD's host-thread numbers relative to tab 1.
- [ ] Both tabs work in airplane mode.

## How to verify

Physical device, release mode, **airplane mode on**.

1. Tab 1: scroll hard. HUD should sit at the device's max refresh rate.
2. Tab 2: scroll hard. HUD host-thread numbers should visibly degrade. Do this several times — the effect must be reproducible, not a one-off.
3. Tap every control in tab 2 and confirm nothing happens.
4. Compare the two side by side and write down the numbers. These are quoted on stage.

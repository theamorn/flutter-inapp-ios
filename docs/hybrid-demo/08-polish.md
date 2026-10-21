# 08 — Stage-readiness

## Goal

Turn a working demo into one that survives a conference stage: no network, no surprises, numbers recorded in advance, and a HUD you have actually verified is telling the truth.

## Prerequisites

- Tasks `00` through `07` complete.

## Repo facts you need

- The ProMotion and Flutter GPU keys live in **both** `cool-ios/cool-ios/Info-Debug.plist` and `Info-Release.plist`. There is no host `Info.plist`.
- The bundled WebView page is `cool-ios/cool-ios/Resources/settings.html`, loaded via `loadFileURL` — it is the most likely place a hidden network dependency survives.
- The repo root `README.md` now describes the current architecture and build commands, with the previous talk's integration walkthrough retained in a collapsible section.
- `flutter_module/lib/couple.md` holds the previous talk's script. Leave it — it is a record, not stale docs.
- The HUD's metric definitions are in `ARCHITECTURE.md`; cross-check against those, not against memory.

## Files to create/modify

| File | Change |
|---|---|
| `README.md` (repo root) | rewrite for the new architecture |
| `docs/hybrid-demo/01-scene-spike.md` | confirm Findings are filled in |
| `docs/hybrid-demo/MEASUREMENTS.md` | device/session details and recorded numbers; leave unmeasured values pending |

## Implementation notes

### 1. Airplane-mode dry run

Full five-tab run on iOS and two-tab run on Android, **airplane mode on, both devices**. Nothing may touch the network. The WebView tab is the likely offender — confirm `settings.html` loads from the bundle and pulls no remote fonts, no CDN CSS, no remote images.

Conference wifi fails. Design for that now, not on stage.

The page has a restrictive Content Security Policy and only its bundled file (including anchors) is allowed to navigate. Its animation/stress loop pauses when the host hides the tab. Android Release declares no INTERNET permission; Debug/Profile retain it for the VM service. These source checks help, but do not replace the device run.

Before building the iOS host, restore the shared entrypoint after any standalone `-t` experiment:

```bash
cd flutter_module
fvm flutter build ios --config-only --release --target lib/main.dart
```

Confirm `FLUTTER_TARGET=lib/main.dart` in `.ios/Flutter/Generated.xcconfig` and `flutter_export_environment.sh`. Both native hosts must enter the route switch in `lib/main.dart`.

### 2. Verify the HUD is honest

This is the most important item in this document. The HUD is the demo's entire evidentiary basis; if it is wrong, the talk asserts things that are false.

- Cross-check the native FPS reading against **Xcode Instruments (Core Animation)** at least once.
- Cross-check Flutter UI/raster costs against **DevTools' frame chart in profile mode** at least once. Release builds do not expose the VM service. Compare matching batch windows; the HUD shows averages, so a single slow frame can disappear in the average. See [Flutter profiling guidance](https://docs.flutter.dev/perf/ui-performance).
- Cross-check the page's `rAF fps` with Safari's Web Inspector while repeating the same scroll/stress action. The host enables inspection in Debug on iOS 16.4+; use that build for inspection, then record the final numbers in Release. The meter reports callback cadence, not hardware refresh or presented frames.
- WKWebView page work runs in a separate process. The page can slow down while the native HUD stays smooth; this is expected. Modern mobile Flutter also merges UI/platform threads, so do not use the old “separate Flutter UI thread” explanation. See `ARCHITECTURE.md`.
- Native tabs must say no active Flutter engine; an active tab with no fresh reports says `no recent frames`. Switch away and back and check that old samples are not presented as live.
- Stress Test explicitly injects layout work, blur, and a 16ms busy loop. Show Normal first and explain what is enabled before quoting its result. No FPS values may be capped, randomized, or pre-seeded to fit the talk.
- Investigate differences you cannot explain before presenting them. Use a fresh Release launch for the final numbers after instrumented checks.

### 3. Confirm 120 means 120

On a ProMotion device, exercise tab 1 and record the observed cadence. Both plists already contain `CADisableMinimumFrameDurationOnPhone`, and the HUD requests the display's maximum. If the reading is 60, check the **built app's** plist, device model, Low Power Mode, Limit Frame Rate setting, and temperature. The flag is necessary for high-refresh scheduling on supported iPhones; it does not force 120. Apple's [ProMotion guidance](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays) explains the system's scheduling constraints.

### 4. Record the numbers

Write down, from a real release build on the real demo device:

- Baseline memory after login, before any engine spawns.
- Process-memory delta for each iOS engine spawn, and the Android game spawn. Label iOS footprint / Android PSS in MiB. Visit one new tab at a time and wait for it to settle.
- Host cadence on each tab, plus Flutter UI/raster averages and Flutter cadence during a defined action.
- **Both host cadence and page rAF cadence** on tab 2 in Normal and synthetic Stress Test modes, at rest and while scrolling.
- Triangle count and **mesh count** on tab 5. Meshes are not GPU draw calls; extra render passes are not counted.

Record these in [MEASUREMENTS.md](MEASUREMENTS.md) with device/OS, build commit, power/thermal conditions, action, and sample duration. Repeat cold launches to show the range. The HUD's `ms create` measures the synchronous engine-creation call, not time-to-first-frame. Its memory delta ends at the first **telemetry batch**, can include unrelated allocations, and may precede scene asset loading. Do not quote it as isolated engine memory or a stable loaded-scene footprint.

### 5. Rehearse the failure modes

- What if a Flutter tab shows black on first tap? (Usually the engine spawned but the view has not attached. Know whether tabbing away and back fixes it.)
- What if tab 5 fails to render? There is **no fallback** — that was a deliberate decision. Know what you will say.
- What if the device thermally throttles after twenty minutes of 3D? Test it. A demo that is fast in rehearsal and slow in the last five minutes of a talk is worse than one that is consistently mediocre.
- Enter every Flutter tab, return to Home, then revisit all three. Game state, glass controls, and the island camera should persist without duplicate screens or rendering behind Home.
- On Android, background and recreate the activity after opening Game. The selected tab and fragment container must restore; after process death, a missing in-memory engine cache must not crash fragment restoration. A recreated process starts a new game.
- Hide Web while Stress Test is active. Return to Home and confirm the page's artificial workload no longer contaminates the baseline.

### 6. Update the root `README.md`

Done: the root README describes five iOS tabs, the two-tab Android scope, lazy engine groups, both build paths, standalone routes, and the stale-entrypoint trap. The previous integration walkthrough and `couple.md` remain available.

## Gotchas

- Do the airplane-mode run on a device that has **never** loaded the WebView content online. A previously-cached remote asset will hide the bug until you are on stage.
- Test after a cold boot, not just after a hot rebuild from Xcode. First-launch behaviour differs, and that is the launch the audience sees.
- Battery matters: 3D plus three engines drains fast. Rehearse on battery, not plugged in, and know how the device behaves at 20%.

## Acceptance criteria

- [ ] Full run on both devices, airplane mode, cold boot, no failures.
- [ ] HUD cross-checked against Instruments and DevTools; discrepancies resolved.
- [ ] ProMotion device's observed cadence and power/thermal conditions recorded; any 60fps result investigated.
- [ ] All numbers from step 4 recorded.
- [x] Root `README.md` describes the current architecture and retains the old integration guide as a section.
- [x] `01-scene-spike.md` Findings section is filled in, not left as `(pending)`; its remaining physical-device verification is explicitly distinguished.
- [x] `flutter analyze` clean; all 27 existing `flutter_module/test/` checks pass.
- [x] Route `/` still dispatches to the standalone home; existing counter smoke check passes. Full device rehearsal remains open above.

## How to verify

Run the whole talk, start to finish, on the actual devices, in airplane mode, from a cold boot, on battery, without stopping. Twice.

If anything surprises you, it will surprise you on stage too.

## Polish findings — 2026-09-05

- Removed the page meter's random, mode-dependent FPS cap, its fabricated startup 120, and its biased mean of reciprocal intervals. Measurements now use elapsed time and the page declares its synthetic workload.
- Fixed the offline navigation guard: remote URLs containing `#fragments` are rejected. Local load failures are visible, and a reclaimed WebKit content process reloads the bundled page.
- Feature initial routes now mount one screen; native HUD samples expire, and telemetry resets across hidden/resumed states.
- Android uses a stable fragment container ID, restores its selected tab/cache as needed, and pauses Flutter behind Home.
- Corrected shared docs for the fully-qualified Android GPU key, the two iOS plists, WebKit processes, merged Flutter threads, memory accounting, and mesh counts.
- Cleaned all 47 existing Dart analyzer issues through API migrations and unused-code cleanup. All 27 existing checks pass. No new automated tests are part of this polish pass.
- iOS unsigned **Release/iphoneos build** and Android **assembleRelease** succeeded. Existing Flutter/CocoaPods and Gradle integration deprecation/build-phase warnings remain; no toolchain migration was needed.

Build success is not device verification. Airplane-mode runs, Instruments/DevTools correlation, thermal rehearsal, and all measured stage numbers remain open.

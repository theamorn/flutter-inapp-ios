# 08 — Stage-readiness

## Goal

Turn a working demo into one that survives a conference stage: no network, no surprises, numbers recorded in advance, and a HUD you have actually verified is telling the truth.

## Prerequisites

- Tasks `00` through `07` complete.

## Repo facts you need

- The ProMotion key lives in `cool-ios/cool-ios/Info.plist`, alongside `FLTEnableFlutterGPU`.
- The bundled WebView page is `cool-ios/cool-ios/Resources/settings.html`, loaded via `loadFileURL` — it is the most likely place a hidden network dependency survives.
- The repo root `README.md` currently documents the *previous* talk's add-to-app integration walkthrough (Podfile setup, `FlutterEngine` in `AppDelegate`, method channels). That content is worth keeping.
- `flutter_module/lib/couple.md` holds the previous talk's script. Leave it — it is a record, not stale docs.
- The HUD's metric definitions are in `ARCHITECTURE.md`; cross-check against those, not against memory.

## Files to create/modify

| File | Change |
|---|---|
| `README.md` (repo root) | rewrite for the new architecture |
| `docs/hybrid-demo/01-scene-spike.md` | confirm Findings are filled in |
| — | recorded numbers, kept wherever the presenter wants them |

## Implementation notes

### 1. Airplane-mode dry run

Full five-tab run on iOS and two-tab run on Android, **airplane mode on, both devices**. Nothing may touch the network. The WebView tab is the likely offender — confirm `settings.html` loads from the bundle and pulls no remote fonts, no CDN CSS, no remote images.

Conference wifi fails. Design for that now, not on stage.

### 2. Verify the HUD is honest

This is the most important item in this document. The HUD is the demo's entire evidentiary basis; if it is wrong, the talk asserts things that are false.

- Cross-check the native FPS reading against **Xcode Instruments (Core Animation)** at least once.
- Cross-check the Flutter-reported numbers against **DevTools' frame chart** at least once.
- If they disagree in a way you cannot explain, **the HUD is wrong. Fix it before an audience sees it.**

### 3. Confirm 120 means 120

On a ProMotion device, confirm the HUD actually reads ~120 on tab 1. If it reads 60, `CADisableMinimumFrameDurationOnPhone` is missing or misspelled in `cool-ios/cool-ios/Info.plist`. Every performance claim in the talk depends on this one key.

### 4. Record the numbers

Write down, from a real release build on the real demo device:

- Baseline memory after login, before any engine spawns.
- Memory delta for each of the three engine spawns.
- FPS on each tab, steady state.
- FPS on tab 2 while scrolling — the WebView contrast number.
- Triangle count and draw calls on tab 5.

Record them so they can be quoted even if a live spawn misbehaves under stage conditions. A presenter who can say "on this device it's 38 megabytes for the second engine" without squinting at a projector is a presenter in control of the room.

### 5. Rehearse the failure modes

- What if a Flutter tab shows black on first tap? (Usually the engine spawned but the view has not attached. Know whether tabbing away and back fixes it.)
- What if tab 5 fails to render? There is **no fallback** — that was a deliberate decision. Know what you will say.
- What if the device thermally throttles after twenty minutes of 3D? Test it. A demo that is fast in rehearsal and slow in the last five minutes of a talk is worse than one that is consistently mediocre.

### 6. Update the root `README.md`

It currently documents the old add-to-app integration from the previous talk. Rewrite it for the five-tab architecture, the engine-group topology, and how to build both hosts. Link to `docs/hybrid-demo/`.

Keep the old integration walkthrough — it is genuinely useful reference material and it is the substance of the earlier talk. Move it into a section rather than deleting it.

## Gotchas

- Do the airplane-mode run on a device that has **never** loaded the WebView content online. A previously-cached remote asset will hide the bug until you are on stage.
- Test after a cold boot, not just after a hot rebuild from Xcode. First-launch behaviour differs, and that is the launch the audience sees.
- Battery matters: 3D plus three engines drains fast. Rehearse on battery, not plugged in, and know how the device behaves at 20%.

## Acceptance criteria

- [ ] Full run on both devices, airplane mode, cold boot, no failures.
- [ ] HUD cross-checked against Instruments and DevTools; discrepancies resolved.
- [ ] ProMotion device reads ~120 on tab 1.
- [ ] All numbers from step 4 recorded.
- [ ] Root `README.md` describes the current architecture and retains the old integration guide as a section.
- [ ] `01-scene-spike.md` Findings section is filled in, not left as `(pending)`.
- [ ] `flutter analyze` clean; `flutter_module/test/` green.
- [ ] Route `/` standalone dev home still works.

## How to verify

Run the whole talk, start to finish, on the actual devices, in airplane mode, from a cold boot, on battery, without stopping. Twice.

If anything surprises you, it will surprise you on stage too.

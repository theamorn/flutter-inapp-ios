# Demo script — Act 6 (33:00–45:00)

Airplane mode. **Release** build. Native HUD visible for the whole act. Talk to the numbers on the glass, not to source code.

Optional second phone: Android Home + Flappy Cat only. Do not dual-wield the 3D island.

If Act 3 ran long, steal two minutes from Tab 3 (one pipe, one death, skip a second run).

---

## Pre-flight (before you walk on)

- [ ] `CADisableMinimumFrameDurationOnPhone` and `FLTEnableFlutterGPU` are on
- [ ] Sign in on the meetup login (native). Do not linger — it is the “keep native” example, not the demo
- [ ] Confirm HUD is on the window, not inside a Flutter view
- [ ] Warm nothing. Lazy engines are the point: first tap on tabs 3/4/5 should move memory
- [ ] Note a baseline Home memory number so you can say “watch this jump” on first Flutter tab

---

## 33:00–35:00 — Tab 1 Native Home

**Do:** Scroll the grouped table hard. Flip a switch. Do not open Flutter yet.

**Say, while pointing at the HUD:**

> Host cadence is pinned at 120. Memory is the cheap native baseline — mid-thirties to mid-forties of mebibytes on this build. This is what native is for. We are not rewriting this screen.

If the HUD is not at 120, say so. Do not invent 120.

---

## 35:00–37:00 — Tab 2 WebView

**Do:** Show normal settings first (smooth). Then toggle Stress Test. Point at page meter versus host cadence.

**Say:**

> This HTML is bundled. Airplane mode. For Help and legal, this is the right tool — it is scrolling fine. Now the stress test: heavy layout, blur, a busy JS loop. Watch the page cadence fall off the host display link. The native chrome stays smooth. The document does not. That is the ceiling, not a straw man.

---

## 37:00–40:00 — Tab 3 Flappy Cat

**Do:** First visit — glance at memory so the room sees the engine spawn. Play. Die on purpose for the flame dissolve. Remember the score.

**Say:**

> This engine was not alive until I opened the tab. Look at the incremental memory — that is `FlutterEngineGroup`, not a second full runtime. Host still at 120. Flutter UI batch and raster batch should be in the two-to-five millisecond range against an 8.3 millisecond budget. If they are not, I will say the number you see.

Die:

> That dissolve is a GLSL fragment shader. Impeller compiled it ahead of time to Metal. First death, no hitch. Could SpriteKit do this? Yes. Now write it again in Android Canvas.

Leave the score in your head. You will cash it on Home.

---

## 40:00–42:00 — Tab 4 Liquid Glass

**Do:** Scroll the list under the lens. Drag a ripple. Nudge a slider.

**Say:**

> Same GLSL on both operating systems. `AnimatedSampler` feeds the live, scrolling widget tree into the shader every frame — refraction, chromatic aberration, touch ripples. UIKit does not give you this without private API or an offscreen pass that wrecks the budget. Android has no equivalent. Host should still read 120.

---

## 42:00–44:00 — Tab 5 Island

**Do:** Orbit. Day/night slider. Tap-to-walk. If you show Ultra: extra trees plus the wandering NPC. Stay on Normal if the room is tight on time. Do not turn water bump on — it is removed so the phone stays live.

**Say:**

> This is an owned 3D scene graph inside a native tab. Tap is a ray against the ground plane. The character walks there. Ultra adds more props and a second walker; we took the water bump off Ultra so a Pro Max does not hitch on a stage demo. Still not Unity. Still not a second SceneKit plus Vulkan codebase.

---

## 44:00–45:00 — Back to Home, MethodChannel

**Do:** Tab 1. Point at Highest Score.

**Say:**

> That number is the score from Flappy Cat. Flutter invoked a MethodChannel. Native Swift stored it and UIKit drew the row. Flutter is a view, not a silo.

Hand off to the decision-matrix slide.

---

## If something breaks

| Failure | Line |
|---|---|
| HUD missing | “The host owns the meter. I will not quote a Flutter-only FPS.” |
| Tab 3 janks | “That is the point of the HUD. We are over budget; I will not pretend otherwise.” |
| Score did not sync | “The channel is the contract. I will show the Home row after the next run.” |
| Island hitch on Ultra | Switch to Normal. “Ultra is the expensive path. Normal is the stage path.” |
| Android second phone frozen | Ignore it. iOS is the spine of the demo. |

---

## Rehearsal checklist (device)

- [ ] Walk this script once on the **release** phone you will present
- [ ] Write the actual HUD numbers from that walk in the margin (do not memorize lab fiction)
- [ ] Confirm first-visit memory delta on tab 3
- [ ] Confirm flame dissolve on first death
- [ ] Confirm Highest Score updates after a scored run
- [ ] Time the six beats. Target **12 minutes**. If over 13, drop the second Flappy run

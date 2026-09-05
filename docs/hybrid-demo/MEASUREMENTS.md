# Stage measurements

**Status: pending physical-device rehearsal.** Build and simulator checks are not performance measurements. Fill in one copy of these tables per device/session; keep the measurement definitions in [ARCHITECTURE.md](ARCHITECTURE.md).

## Session

| Field | Value |
|---|---|
| Date / presenter | Pending |
| Device / OS / display refresh settings | Pending |
| Commit / build configuration | Pending — Release for stage numbers |
| Battery / Low Power Mode / charging | Pending |
| Thermal condition / minutes since launch | Pending |
| Airplane mode / explicit Wi-Fi and cellular state | Pending |
| Cold-launch repetition / sample duration | Pending |
| Instruments / DevTools profile cross-check evidence | Pending |

## Memory and engine creation

Wait for each new tab to settle before moving to the next. Record iOS physical footprint or Android PSS in **MiB**; these accounting methods differ. The native host memory number excludes separate WebKit processes.

| Checkpoint | Host process MiB after settling | HUD delta MiB at first telemetry batch | HUD synchronous create ms |
|---|---|---|---|
| Home after login, no engine created | Pending | — | — |
| Game `/game` | Pending | Pending | Pending |
| Glass `/glass` (iOS) | Pending | Pending | Pending |
| Island `/scene` (iOS) | Pending | Pending | Pending |

The delta includes process-wide concurrent allocation/reclamation and initial assets. `create ms` excludes subsequent startup/rendering. Neither field is an isolated engine benchmark or a time-to-first-visible-frame measurement.

## Cadence and frame costs

Record a range over a defined action and sample interval; keep startup samples separate. Use profile mode only for the DevTools cross-check, then repeat in Release.

| Tab / action | Host callback fps | Page rAF fps | Flutter fps | UI / raster batch averages (ms) |
|---|---|---|---|---|
| Home — idle, then scroll | Pending | — | — | — |
| Web Normal — idle, then scroll (iOS) | Pending | Pending | — | — |
| Web Stress Test — same action (iOS, synthetic workload) | Pending | Pending | — | — |
| Game — active round | Pending | — | Pending | Pending |
| Glass — drag controls / touch ripple (iOS) | Pending | — | Pending | Pending |
| Island — orbit / day-night / tap-to-move (iOS) | Pending | — | Pending | Pending |
| Home again, after visiting all supported tabs | Pending | — | — | — |

Island scene graph triangle count: **Pending**. Mesh count: **Pending**. GPU draw calls: **not exposed by this readout**.

## Rehearsal notes

- Cold launch / offline assets: pending.
- Tab return and preserved state: pending.
- Android activity recreation / process restart: pending.
- Two complete talk runs on battery: pending.
- Twenty-minute thermal run and low-battery behavior: pending.
- Unexpected failures and the presenter's recovery plan: pending.

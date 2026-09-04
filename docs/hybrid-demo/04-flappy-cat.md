# 04 — Tab 3: Flappy Cat (Flame)

## Goal

A playable Flappy Bird clone in Flame, running in the tab-3 Flutter engine, holding the device's full refresh rate. This is the first tab where the audience sees something a WebView could not credibly do.

## Prerequisites

- `02-ios-host.md` complete (engine for route `/game` exists).
- Read `ARCHITECTURE.md` for the route contract.

## Repo facts you need

- `flutter_module/pubspec.yaml` already depends on `flame: ^1.30.1` and `flutter_shaders: ^0.1.3`.
- **`flutter_module/lib/game_screen.dart` is not a game.** It is a rain/particle effect built on `FlameGame` (`RainEffect`) with a `RainDropletPainter` driving `shaders/rain_droplets.glsl`. Read it for how Flame and fragment shaders are wired together here, then leave it alone — it backs the `/` standalone dev home.
- Reusable helpers already in `flutter_module/lib/`: `rain_particle.dart`, `rain_drop.dart`, `rain_splash.dart`, `drop_splash.dart`, `sprite_sheet.dart`, `action_button.dart`.
- Existing assets in `flutter_module/assets/images/`: `cat_sprite.png`, `cat_sprite_long.png`, `street.jpg`, `splash_ground.png`, `buttons.png`, `rain_effect.png`.
- Existing shaders in `flutter_module/shaders/`: `sky.glsl`, `water.glsl`, `star.glsl`, `flame.glsl`, `rain_droplets.glsl`.

## Files to create/modify

| File | Change |
|---|---|
| `flutter_module/lib/tabs/game/flappy_cat_game.dart` | **new** — `FlameGame` subclass |
| `flutter_module/lib/tabs/game/cat_player.dart` | **new** |
| `flutter_module/lib/tabs/game/pipe_pair.dart` | **new** |
| `flutter_module/lib/tabs/game/ground.dart` | **new** |
| `flutter_module/lib/tabs/game/game_app.dart` | **new** — widget for route `/game` |
| `flutter_module/lib/main.dart` | wire `/game` |

## Implementation notes

**It is Flappy Cat, not Flappy Bird.** Reuse the existing `cat_sprite.png` / `cat_sprite_long.png` rather than sourcing new bird art — the assets are already there, and a cat is more memorable on stage.

- **`CatPlayer`** — constant downward gravity, upward impulse on tap, rotation that follows velocity (nose up while rising, tilting down as it falls). Animate the sprite sheet using the existing `sprite_sheet.dart` helper.
- **`PipePair`** — spawner on a timer, constant leftward velocity, randomized gap position within safe bounds, despawn off-screen. Recycle rather than allocating per pair.
- **`Ground`** — scrolling parallax using `street.jpg`.
- **Background** — `sky.glsl` as an animated layer behind everything. Follow the `CustomPainter` + `ui.FragmentShader` pattern in `game_screen.dart` / `shader_screen.dart`.
- **Collision** — Flame's `CollisionCallbacks` with hitboxes on cat, pipes, and ground.
- **Score** — increments on pipe pass; display it in-game.
- **Death** — a brief shader dissolve before the restart prompt, reusing existing shader plumbing. Keep it short; it is a flourish, not a set piece.
- **Restart** — tap to play again.

Optional if it comes cheap: run the existing rain particle system as a weather layer. It already exists and it makes the scene feel alive under load, which suits the performance story. Cut it the moment it costs framerate.

## Gotchas

- Every tap must be handled by Flame's gesture system, not by a Flutter `GestureDetector` layered over the game — mixing the two produces missed and doubled inputs.
- Do not extend `RainEffect` in `game_screen.dart`. Build a fresh `FlameGame` and copy the wiring you need. That file serves the `/` dev home and must keep working.
- Watch allocation in `update()`. Allocating `Vector2`s per frame at 120fps produces GC sawtooth that the HUD will faithfully display to the audience.
- The game keeps running while the tab is backgrounded, because the engine stays alive by design. Pause it in `onPause` / when the route loses visibility, or the presenter returns to a dead cat and a confusing score.

## Acceptance criteria

- [ ] Game is playable: flap, pass pipes, score, die, restart.
- [ ] Holds the device's full refresh rate on the HUD throughout, including during pipe spawning and the death animation.
- [ ] Tab away mid-game and back: state is preserved (or cleanly paused and resumed — decide and be consistent).
- [ ] `flutter analyze` clean.
- [ ] Route `/` standalone dev home still works and `game_screen.dart` is unmodified.

## How to verify

Physical device, release mode.

1. Play several full rounds. Watch the HUD through pipe spawning, collision, death, and restart. Look specifically for a dip at spawn time and at death — those are the two moments that would betray allocation churn.
2. Tab 3 → tab 1 → tab 3 mid-game. Confirm the pause/resume behaviour you chose.
3. Leave it running for a few minutes and watch HUD memory for an upward drift, which would indicate pipes not being despawned.

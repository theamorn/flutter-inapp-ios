# 00 — Toolchain bump to Flutter 3.47.2

## Goal

Get the repo onto Flutter 3.47.2 and make `flutter_gpu` available, so `01-scene-spike.md` can run. Nothing else in this plan can start until this is done.

## Prerequisites

None. This is the first task.

## Repo facts you need

- fvm is installed at `/opt/homebrew/bin/fvm`; its cache is `~/fvm/versions`.
- `.fvmrc` pins `3.38.3`. **That version is not installed** — `.fvm/flutter_sdk` is a symlink to `/Users/pikmin/fvm/versions/3.38.3`, which does not exist. Anything resolving Flutter through that symlink is currently broken.
- Installed versions: `3.41.1`, `3.47.0`, `3.47.2`.
- `flutter_module/pubspec.yaml` pins `environment.sdk: ^3.5.2` and `flutter_lints: ^4.0.0`.
- `flutter_native/pubspec.yaml` pins `environment.sdk: ^3.7.2`.
- The working tree is **already dirty**, including `cool-ios/cool-ios.xcodeproj/project.pbxproj`, `flutter_native/ios/Podfile.lock`, and `flutter_native/ios/Flutter/AppFrameworkInfo.plist`.

## Files to create/modify

| File | Change |
|---|---|
| `.fvmrc` | `3.38.3` → `3.47.2` (written by `fvm use`) |
| `.fvm/flutter_sdk` | symlink repointed (written by `fvm use`) |
| `flutter_module/pubspec.yaml` | `environment.sdk` → `^3.13.0`; bump `flutter_lints` |
| `flutter_module/pubspec.lock` | regenerated |
| `cool-ios/Podfile.lock` | regenerated |

## Implementation notes

**Commit the dirty tree first.** The files listed above as already-modified are exactly the ones this bump will churn again. Committing first keeps the SDK-bump diff readable instead of tangling it with in-progress edits.

Then:

```bash
cd /Users/pikmin/Documents/flutter-inapp-ios
fvm use 3.47.2          # rewrites .fvmrc, repoints .fvm/flutter_sdk
fvm flutter precache    # downloads flutter_gpu — see below
```

Update `flutter_module/pubspec.yaml`:

```yaml
environment:
  sdk: ^3.13.0     # was ^3.5.2 — flutter_gpu requires ^3.11.0-0
```

Bump `flutter_lints` off `^4.0.0` to whatever is current. Then regenerate everything:

```bash
cd flutter_module && fvm flutter clean && fvm flutter pub get
cd ../cool-ios && pod install
```

`flutter clean` + `pub get` regenerates `flutter_module/.ios/` and `flutter_module/.android/`, which are the generated host-embedding scaffolds the Podfile and (later) Gradle depend on. Both are gitignored; regenerating them is expected and safe.

### Why `flutter precache` matters here

`flutter_gpu` is **not** under `<flutter_root>/packages/`. It is a cached package downloaded into `<flutter_root>/bin/cache/pkg/flutter_gpu`, listed in `getPackageDirs()` at `packages/flutter_tools/lib/src/flutter_cache.dart:264`. As of writing, `~/fvm/versions/3.47.2/bin/cache/pkg/` does not exist — the artifact has not been fetched. `flutter precache` is what creates it.

Once fetched, depend on it the normal way (done in `01-scene-spike.md`, not here):

```yaml
dependencies:
  flutter_gpu:
    sdk: flutter
```

## Gotchas

- **`flutter_gpu` requires Dart `^3.11.0-0`.** 3.47.2 ships Dart 3.13.2, so this resolves. Under the old 3.38.3 pin it would not have resolved at all — the version bump is a hard prerequisite for tab 5, not a nicety.
- **`.fvmrc` is repo-wide.** `flutter_native/` pins `sdk: ^3.7.2` and is not part of this plan. If it stops building after the bump, either bump its constraint or leave it deliberately broken and note it — it is not in the demo path and must not block this work.
- Do not hand-edit `.fvmrc` or the `.fvm/flutter_sdk` symlink. Use `fvm use`, or the two will drift out of sync again — which is how the current dangling symlink happened.

## Acceptance criteria

- [ ] `fvm flutter --version` reports **3.47.2**, Dart **3.13.2**.
- [ ] `~/fvm/versions/3.47.2/bin/cache/pkg/flutter_gpu/` exists.
- [ ] `.fvm/flutter_sdk` resolves to a directory that exists.
- [ ] `cd flutter_module && fvm flutter pub get` succeeds.
- [ ] `cd flutter_module && fvm flutter analyze` is clean.
- [ ] `cd cool-ios && pod install` succeeds.
- [ ] `cool-ios.xcworkspace` builds and the existing login → Flutter-modal flow still works.
- [ ] The SDK bump is its own commit, separate from the pre-existing dirty-tree changes.

## How to verify

```bash
fvm flutter --version
ls ~/fvm/versions/3.47.2/bin/cache/pkg/
cd flutter_module && fvm flutter pub get && fvm flutter analyze && fvm flutter test
cd ../cool-ios && pod install
```

Then open `cool-ios/cool-ios.xcworkspace`, build to a physical device, and confirm the existing app still launches and its Flutter button still presents the Flutter screen. This is a regression check: the bump must not break what already worked.

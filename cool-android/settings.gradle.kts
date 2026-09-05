// Host Gradle build for the Android side of the hybrid demo.
//
// The Flutter module is pulled in as the `:flutter` Gradle project by the
// generated `include_flutter.groovy`. That file lives under
// `flutter_module/.android/`, which is created by `flutter pub get` and is
// gitignored — if the include below fails with a missing-path error, run
//
//     cd flutter_module && fvm flutter pub get
//
// and re-sync. Nothing here should ever be committed from `.android/`.

pluginManagement {
    // `include_flutter.groovy` also calls `pluginManagement { includeBuild(...) }`
    // for flutter_tools' Gradle plugin build. Gradle requires the pluginManagement
    // block to be the first block in a settings script, so the repositories the
    // host itself needs are declared here up front.
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// NB: no `dependencyResolutionManagement { repositories { ... } }` here.
// flutter_tools' Gradle plugin adds https://storage.googleapis.com/download.flutter.io
// as a *project* repository on every project. Declaring settings-level
// repositories makes Gradle prefer them and silently ignore the project ones,
// after which the whole androidx graph resolves only against download.flutter.io
// and fails. Dependency repositories are declared in `build.gradle.kts` instead,
// where they merge with the one Flutter adds.

rootProject.name = "cool-android"
include(":app")

// Versions here must track `flutter_module/.android/settings.gradle`, which the
// Flutter tool regenerates. A mismatch fails the manifest/variant merge.
plugins {
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
}

val flutterModuleRoot = File(settingsDir.parentFile, "flutter_module")
val includeFlutter = File(flutterModuleRoot, ".android/include_flutter.groovy")
require(includeFlutter.exists()) {
    "$includeFlutter is missing. Run `fvm flutter pub get` in $flutterModuleRoot first."
}
apply(from = includeFlutter)

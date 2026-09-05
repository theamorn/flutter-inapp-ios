plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("org.jetbrains.kotlin.plugin.compose") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/*
 * The generated `flutter_module/.android/Flutter/build.gradle` pins
 * `ndkVersion = flutter.ndkVersion`, so AGP resolves that exact NDK at
 * configuration time even though nothing in this build compiles native code.
 * If the pinned version is not installed the build dies with
 *
 *     [CXX1101] NDK at .../ndk/<version> did not have a source.properties file
 *
 * which names neither Flutter nor the real cause. `flutter_module/` is not ours
 * to edit, so the version is overridden here, on the included `:flutter`
 * project, to whichever NDK this machine actually has.
 *
 * Set ANDROID_NDK_VERSION to pick a specific one; otherwise the newest
 * installed NDK wins.
 */
val resolvedNdkVersion: String? by lazy {
    providers.environmentVariable("ANDROID_NDK_VERSION").orNull
        ?: run {
            val sdkDir = System.getenv("ANDROID_HOME")
                ?: System.getenv("ANDROID_SDK_ROOT")
                ?: java.util.Properties().apply {
                    val f = File(rootDir, "local.properties")
                    if (f.exists()) f.inputStream().use { load(it) }
                }.getProperty("sdk.dir")
            sdkDir?.let { dir ->
                File(dir, "ndk").listFiles()
                    ?.filter { File(it, "source.properties").exists() }
                    ?.maxByOrNull { it.name }
                    ?.name
            }
        }
}

subprojects {
    plugins.withId("com.android.library") {
        resolvedNdkVersion?.let { version ->
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                ndkVersion = version
            }
        }
    }
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.theamorn.hybriddemo"

    // These four must match `flutter_module/.android/app/build.gradle` and
    // `.android/build.gradle`, which the Flutter tool regenerates. If they
    // drift, the AAR merge fails with a version conflict rather than anything
    // that names the real cause.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.theamorn.hybriddemo"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    buildFeatures {
        compose = true
    }

    buildTypes {
        // `flutter_module/.android` defines a `profile` build type; the included
        // :flutter project publishes variants for it, so the host must declare a
        // matching one or the variant resolution fails.
        create("profile") {
            initWith(getByName("debug"))
        }
        release {
            isMinifyEnabled = false
            // Debug keys so a release build installs on a dev device without a
            // keystore. The demo is never shipped; what matters is that it is an
            // AOT release build, because debug-mode numbers are meaningless here.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // The Flutter module, included by settings.gradle.kts via
    // flutter_module/.android/include_flutter.groovy.
    implementation(project(":flutter"))

    // Capped deliberately. compileSdk is pinned to 36 by the Flutter module's
    // generated Gradle (and 36 is also AGP 9.1.0's maximum), while Compose
    // 1.11+ / BOM 2026.05.01+ require compileSdk 37. This is the newest BOM
    // that still builds against 36.
    implementation(platform("androidx.compose:compose-bom:2026.03.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    // Pinned, not BOM-managed: androidx froze the icon artifacts at 1.7.8 and
    // dropped them from the Compose BOM, so an unversioned coordinate no longer
    // resolves. They are pure ImageVector data and work fine against a newer
    // Compose runtime.
    implementation("androidx.compose.material:material-icons-extended:1.7.8")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
}

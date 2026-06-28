import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties (git-ignored; owner-supplied).
// Absent → builds fall back to the debug key so `flutter run --release` and CI
// still work; present → real release signing for store uploads. See
// android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) keystorePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.almarfa.al_quran"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // Required by Patrol's bundled uiautomator (part of the canonical setup).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // Published app id (what Play + users see). The `namespace` above
        // intentionally stays `com.almarfa.al_quran` — it's the internal Kotlin
        // package for MainActivity, the widget providers, and the reminders
        // MethodChannel, all keyed to that name. applicationId != namespace is
        // valid and supported; do NOT "align" the namespace without moving the
        // Kotlin sources + updating the Dart FQNs/channel that reference it.
        applicationId = "com.almarfa.alquran"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Patrol end-to-end tests (integration_test/). See docs/E2E.md. This
        // file lives in the git-ignored android/, so re-apply after a regen.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Real keystore when android/key.properties exists; else debug so
            // local/CI release builds still run (NOT valid for a store upload).
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeystore) "release" else "debug",
            )
        }
    }

    // Patrol: run instrumentation tests through the AndroidX test orchestrator.
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

flutter {
    source = "../.."
}

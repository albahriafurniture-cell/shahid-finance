import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads key.properties from android/key.properties.
// rootProject here is the android/ directory (Flutter project layout),
// NOT the repo root — CI must write android/key.properties (see
// .github/workflows). v1.1.0 shipped debug-signed because CI wrote the
// file to the repo root, where Gradle never looked for it.
// There is deliberately NO debug fallback for release builds anymore:
// a release build without the release keystore must FAIL, never
// silently produce a debug-signed APK (that breaks Google sign-in
// with error 10). Debug builds are unaffected (they use debug signing).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.shahid.finance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.shahid.finance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // No debug fallback: if key.properties is missing, the
            // taskGraph guard below fails the release build loudly.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Fail loudly (with a clear reason) instead of signing a "release" APK
// with the debug key when the release keystore is not configured.
gradle.taskGraph.whenReady {
    if (gradle.taskGraph.allTasks.any { it.name == "assembleRelease" } &&
        !keystorePropertiesFile.exists()
    ) {
        throw GradleException(
            "Release signing not configured: android/key.properties is " +
                "missing. Refusing to build a debug-signed release APK."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

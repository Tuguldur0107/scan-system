plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.scansystem.scan_system_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.scansystem.scan_system_app"
        // Chainway DeviceAPI requires minSdk >= 26.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The Chainway AAR only ships arm ABIs (no x86_64) so we restrict
        // to those to avoid APK bloat and emulator crashes on missing .so's.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    packaging {
        // Chainway .so files ship uncompressed in the AAR; keep them that way
        // so Android's UncompressedNativeLibs requirement is satisfied.
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Chainway UHF DeviceAPI AAR — keep the file under `android/app/libs/`.
    //
    // Do NOT use `implementation(group = "", name = "...", ext = "aar")` with an
    // empty `group`: Android Lint 8.x GradleDetector can crash while parsing it
    // (`Illegal char <"> at index 8: group = ""\\\\DeviceAPI_...`), which fails
    // `:app:lintVitalAnalyzeRelease` on release builds.
    implementation(files("libs/DeviceAPI_ver20250209_release.aar"))
}

flutter {
    source = "../.."
}

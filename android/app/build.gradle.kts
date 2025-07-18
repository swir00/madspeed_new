// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.madspeed_new"
    compileSdk = flutter.compileSdkVersion // Powinno być np. 34
    ndkVersion = "27.0.12077973" // OK

    compileOptions {
        // Ustawiamy kompatybilność Javy na wersję 17
        sourceCompatibility = JavaVersion.VERSION_17 // ZMIEŃ NA VERSION_17
        targetCompatibility = JavaVersion.VERSION_17 // ZMIEŃ NA VERSION_17
    }

    kotlinOptions {
        // Ustawiamy cel JVM Kotlina na "17" (również w podwójnych cudzysłowach)
        jvmTarget = "17" // ZMIEŃ NA "17"
    }

    defaultConfig {
        applicationId = "com.example.madspeed_new"
        minSdk = flutter.minSdkVersion // Upewnij się, że to jest co najmniej 21 (lub 23)
        targetSdk = flutter.targetSdkVersion // Powinno być np. 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

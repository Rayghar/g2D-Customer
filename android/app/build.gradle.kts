// File: android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "1.8.20"
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.primejet_mobile" // Your actual app package name
    compileSdk = 34 // Keep your existing compileSdk

    defaultConfig {
        applicationId = "com.example.primejet_mobile" // Your actual app ID
        minSdk = 24 // Keep your existing minSdk (OPay requires >= 21)
        targetSdk = 34 // Keep your existing targetSdk
        versionCode = 1
        versionName = "1.0"

        multiDexEnabled = true // Essential for apps with many dependencies
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // Required for Java 8 features in plugins
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            signingConfig = signingConfigs.getByName("debug") // Adjust for your release signing
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core-ktx:1.9.0") // Or 1.10.0, 1.11.0
        force("androidx.core:core:1.9.0")    // Or 1.10.0, 1.11.0
    }
}

dependencies {
    // Firebase BOM and specific Firebase dependencies (keep your existing versions)
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")

    // AndroidX core dependencies (keep your existing versions)
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")

    // Core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // REMOVED: Jetpack Compose dependencies added for Paystack compatibility.
    // OPay SDK will manage its own Compose dependencies.
    // If build errors related to Compose reappear, we'd re-evaluate adding specific Compose BOM/libraries.
}
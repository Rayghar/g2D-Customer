// File: android/app/build.gradle.kts

import java.io.FileInputStream // Import FileInputStream for reading key.properties
import java.util.Properties // Import Properties for reading key.properties
import org.gradle.api.JavaVersion // Import JavaVersion for compatibility settings

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "2.0.20"
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.primejet_mobile"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.primejet_mobile"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // --- START: ADDED SIGNING CONFIGURATION ---
    // Load properties from key.properties file
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } else {
        println("WARNING: key.properties not found. Build will likely fail without signing credentials.")
        // You might want to throw an error here in CI/CD to prevent unsigned builds
    }

    signingConfigs {
        // Define the 'release' signing configuration using details from key.properties
        create("release") {
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
        // You can keep a 'debug' signing config explicitly if needed, but it's often default
        // debug {
        //     storeFile = file("debug.keystore")
        //     storePassword = "android"
        //     keyAlias = "androiddebugkey"
        //     keyPassword = "android"
        // }
    }
    // --- END: ADDED SIGNING CONFIGURATION ---

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            signingConfig = signingConfigs.getByName("release") // This now correctly references the 'release' config
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
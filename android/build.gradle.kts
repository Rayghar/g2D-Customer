// File: android/build.gradle.kts

plugins {
    id("com.android.application") version "7.4.2" apply false
    id("org.jetbrains.kotlin.android") version "1.8.20" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
        classpath("com.android.tools.build:gradle:7.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // REMOVED: maven { url = uri("https://www.jitpack.io") } - No longer needed for Paystack
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

// Ensure this block is NOT present if it caused circular dependency issues before
// subprojects {
//     project.evaluationDependsOn(":app")
// }

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
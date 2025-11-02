/// File: android/build.gradle.kts

plugins {
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    // CORRECTED: Use the version the build already has on the classpath.
    id("com.google.gms.google-services") version "4.3.15" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // CORRECTED: Align the classpath version to match the plugin version.
        classpath("com.google.gms:google-services:4.3.15")
        classpath("com.android.tools.build:gradle:8.7.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
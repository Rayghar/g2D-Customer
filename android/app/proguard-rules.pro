# This is a ProGuard/R8 rules file for Flutter Android release builds.
# It tells R8/ProGuard which code to keep (not minify or obfuscate)
# to prevent crashes caused by aggressive optimization.

# Flutter framework-specific rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Prevent obfuscation of your main application class
# IMPORTANT: Replace 'com.primejet.gas2door' with your ACTUAL Android package name.
# You can find this in your android/app/build.gradle file under defaultConfig { applicationId "your.package.name" }
-keep class com.primejet.gas2door.MainActivity { *; } 

# Retain essential Kotlin metadata (often used by Flutter plugins)
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep Firebase and general Google Play Services classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Prevent stripping of Parcelable classes (common for Android components)
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# --- START: Rules for Google Play Services Credentials (SmartAuth, Google Sign-In) and Play Core Libraries ---
# These rules are crucial for apps using Google Sign-In, Smart Lock, or App Bundles/Deferred Install features.
# They explicitly tell R8/ProGuard to keep these classes, which are often referenced dynamically.

# Rules for Google Play Services Credentials API (com.google.android.gms.auth.api.credentials)
# Broad rule for the package:
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep interface com.google.android.gms.auth.api.credentials.** { *; }

# Explicitly keep specific classes that were reported as missing:
-keep class com.google.android.gms.auth.api.credentials.Credential$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.Credential { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialPickerConfig$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialPickerConfig { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequest$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequest { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialRequestResponse { *; }
-keep class com.google.android.gms.auth.api.credentials.Credentials { *; }
-keep class com.google.android.gms.auth.api.credentials.CredentialsClient { *; }
-keep class com.google.android.gms.auth.api.credentials.HintRequest$Builder { *; }
-keep class com.google.android.gms.auth.api.credentials.HintRequest { *; }

# Rules for Google Play Core Library (com.google.android.play.core)
# Broad rule for the package:
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Explicitly keep specific classes that were reported as missing:
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallException { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManager { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManagerFactory { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest$Builder { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallSessionState { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.Task { *; }

# --- END: Rules added ---

# Stripe specific dontwarn rules (from your original file - generally safe to keep)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
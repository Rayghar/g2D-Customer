# Flutter
-keep class io.flutter.** { *; } [cite: 1, 2]
-keep class io.flutter.embedding.** { *; }

# Prevent obfuscation of main application class
# IMPORTANT: Replace 'your.package.name' with your actual Android package name (e.g., com.primejet.gas2door)
-keep class com.example.primejet_mobile.MainActivity { *; } [cite: 3]

# Retain essential Kotlin metadata
-keep class kotlin.** { *; } [cite: 4]
-keep class kotlinx.** { *; }

# Keep Firebase and general Google Play Services classes
-keep class com.google.firebase.** { *; } [cite: 5]
-keep class com.google.android.gms.** { *; } [cite: 5]

# Prevent stripping of Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *; [cite: 6]
}

# --- START: Rules added for smart_auth, Google Play Services Credentials, and Play Core ---

# Rules for Google Play Services Credentials API (com.google.android.gms.auth.api.credentials)
# Needed by plugins like smart_auth, Google Sign-In for credential management.
-keep class com.google.android.gms.auth.api.credentials.** { *; } [cite: 7]
-keep interface com.google.android.gms.auth.api.credentials.** { *; } [cite: 8]

# --- Explicitly keep specific classes mentioned in missing_rules.txt ---
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
# Often used for App Bundles, deferred installs, in-app updates, etc.
-keep class com.google.android.play.core.** { *; } 
-keep interface com.google.android.play.core.** { *; }

# --- Explicitly keep specific classes mentioned in missing_rules.txt ---
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

# Stripe specific dontwarn rules (from your original file)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
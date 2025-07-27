# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Prevent obfuscation of main application class
# IMPORTANT: Replace 'your.package.name' with your actual Android package name (e.g., com.primejet.gas2door)
-keep class your.package.name.MainActivity { *; } 

# Retain essential Kotlin metadata
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep Firebase and general Google Play Services classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Prevent stripping of Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# --- START: Rules added for smart_auth, Google Play Services Credentials, and Play Core ---

# Rules for Google Play Services Credentials API (com.google.android.gms.auth.api.credentials)
# Needed by plugins like smart_auth, Google Sign-In for credential management.
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-keep interface com.google.android.gms.auth.api.credentials.** { *; }

# Rules for Google Play Core Library (com.google.android.play.core)
# Often used for App Bundles, deferred installs, in-app updates, etc.
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# --- END: Rules added ---

# Stripe specific dontwarn rules (from your original file)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
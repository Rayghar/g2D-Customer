# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Prevent obfuscation of main application class
-keep class your.package.name.MainActivity { *; }

# Retain essential Kotlin metadata
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Keep Firebase and Analytics classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Prevent stripping of Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
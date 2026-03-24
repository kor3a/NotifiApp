# Add project specific ProGuard rules here.
# By default, the flags in this file are applied to all build types.

# React Native
-keep class com.facebook.react.** { *; }
-keep class com.facebook.hermes.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Kotlin metadata
-keepattributes *Annotation*, Signature, Exception

# Keep source file names and line numbers for better crash reports
-keepattributes SourceFile,LineNumberTable

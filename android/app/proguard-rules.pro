-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Mediation SDKs
-dontwarn com.unity3d.ads.**
-dontwarn com.ironsource.**
-dontwarn com.inmobi.**
-dontwarn com.applovin.**

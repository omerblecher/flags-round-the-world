-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# WorkManager (required by AdMob SDK — Room DB init fails without these)
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Mediation SDKs
-dontwarn com.unity3d.ads.**
-dontwarn com.ironsource.**
-dontwarn com.inmobi.**
-dontwarn com.applovin.**

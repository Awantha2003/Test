# PayHere SDK (from payhere_mobilesdk_flutter README)
-keepattributes Signature
-keepattributes *Annotation*
-keep interface retrofit2.** { *; }
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class lk.payhere.** { *; }
-keep interface lk.payhere.androidsdk.PayhereSDK { *; }
-keep class lk.payhere.androidsdk.models.** { *; }
-keep class lk.payhere.androidsdk.** { *; }
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-dontwarn okio.**

# Background service entry point
-keep class id.flutter.flutter_background_service.** { *; }

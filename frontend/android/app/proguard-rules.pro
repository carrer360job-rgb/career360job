# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep public class com.google.ads.** {
    public *;
}
-keep class io.flutter.plugins.googlemobileads.** { *; }

# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !class/loading/modifier/flags
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

# Firebase
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# Pdfrx and Native JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

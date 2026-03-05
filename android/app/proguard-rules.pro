# ── RouteFlux VPN — ProGuard / R8 Rules ──────────────────────────────

# Keep JNI native methods (critical — R8 will strip them otherwise)
-keepclassmembers class com.routeflux.vpn.MyVpnService {
    native <methods>;
}

# Keep VPN service and activity (referenced by manifest)
-keep class com.routeflux.vpn.MyVpnService { *; }
-keep class com.routeflux.vpn.MainActivity { *; }

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep AndroidX / Notification classes
-keep class androidx.core.app.NotificationCompat** { *; }

# Ignore warnings for missing Play Core classes (common Flutter R8 issue)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

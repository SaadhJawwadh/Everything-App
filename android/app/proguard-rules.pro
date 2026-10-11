# General Flutter Embedding Infrastructure
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.embedding.**

# Keep all implementations of Flutter interfaces to ensure they are found via reflection
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler
-keep class * implements io.flutter.plugin.common.EventChannel$StreamHandler

# Pigeon-generated classes (used by shared_preferences, workmanager, etc.)
-keep class **.Messages { *; }
-keep class **.Messages$* { *; }
-keep class dev.flutter.pigeon.** { *; }

# sqflite & SQLCipher
-keep class com.tekartik.sqflite.** { *; }
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class net.sqlcipher.database.SQLiteDatabase { *; }
-dontwarn net.sqlcipher.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo_platform_interface.** { *; }

# Receive Sharing Intent
-keep class com.kasem.receive_sharing_intent.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class miguelruivo.flutter.plugins.filepicker.** { *; }

# WorkManager
-keep class be.tramckrijte.workmanager.** { *; }
-keep class androidx.work.** { *; }

# Telephony
-keep class com.shounakmulay.telephony.** { *; }
-dontwarn com.shounakmulay.telephony.**

# Other Plugins
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class gal.** { *; }
-keep class com.rayfel.flutter_displaymode.** { *; }
-dontwarn com.rayfel.flutter_displaymode.**

# Google ML Kit & Text Recognition
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }
-dontwarn com.csdcorp.speech_to_text.**

# Gemini Nano / AICore
-keep class com.example.gemini_nano_android.** { *; }
-dontwarn com.example.gemini_nano_android.**

# In-App Update & In-App Review
-keep class de.schilken.in_app_update.** { *; }
-dontwarn de.schilken.in_app_update.**
-keep class dev.fluttercommunity.plus.in_app_review.** { *; }
-dontwarn dev.fluttercommunity.plus.in_app_review.**

# General JNI keep
-keepclassmembers class * { native <methods>; }

# Java Desugaring Guardrails
-dontwarn java.lang.invoke.**
-dontwarn j$.**

# Preserve Enum Values for JSON/Reflection Deserialization
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Preserve Serializable Data Objects
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

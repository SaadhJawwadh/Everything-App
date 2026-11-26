package com.saadhjawwadh.notebook

import android.content.Context
import android.content.SharedPreferences
import io.flutter.app.FlutterApplication

class EverythingApplication : FlutterApplication() {

    private var flutterPrefListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun onCreate() {
        super.onCreate()

        // Drain any background isolate staging payloads & purge legacy plaintext widget keys
        WidgetCacheStore.drainBackgroundStaging(this)

        // Sync enabled/disabled component states for deprecated & optional module widgets
        WidgetVisibilityManager.syncComponentStates(this)

        // Listen for background Workmanager/Telephony isolate staging writes
        val flutterPrefs = getSharedPreferences(
            WidgetCacheStore.LEGACY_FLUTTER_PREFS,
            Context.MODE_PRIVATE
        )
        flutterPrefListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == WidgetCacheStore.STAGING_FINANCE_KEY ||
                key == WidgetCacheStore.STAGING_TODO_KEY
            ) {
                WidgetCacheStore.drainBackgroundStaging(this)
                FinanceWidgetProvider.updateAllWidgets(this)
                TodoWidgetProvider.updateAllWidgets(this)
                UnifiedWidgetProvider.updateAllWidgets(this)
            }
        }
        flutterPrefs.registerOnSharedPreferenceChangeListener(flutterPrefListener)
    }
}

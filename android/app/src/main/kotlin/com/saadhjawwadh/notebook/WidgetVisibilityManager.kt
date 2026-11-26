package com.saadhjawwadh.notebook

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

object WidgetVisibilityManager {

    fun syncComponentStates(context: Context) {
        val appContext = context.applicationContext ?: context
        try {
            // Deprecated widgets: disable in widget picker once no instances remain pinned
            disableComponentIfUnused(appContext, NotesWidgetProvider::class.java)
            disableComponentIfUnused(appContext, UnifiedWidgetProvider::class.java)

            // Tasks & Notes widget is always enabled
            setComponentState(
                appContext,
                TodoWidgetProvider::class.java,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            )

            // Finance widget: enabled when Financial Manager is active; if disabled and unused, hide from picker;
            // if disabled but still pinned (> 0), keep enabled so the provider renders the disabled notice.
            val financeEnabled = WidgetCacheStore.isFinancialManagerEnabled(appContext)
            if (financeEnabled) {
                setComponentState(
                    appContext,
                    FinanceWidgetProvider::class.java,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                )
            } else {
                val appWidgetManager = AppWidgetManager.getInstance(appContext)
                val financeComponent = ComponentName(appContext, FinanceWidgetProvider::class.java)
                val pinnedIds = appWidgetManager.getAppWidgetIds(financeComponent)
                if (pinnedIds.isEmpty()) {
                    setComponentState(
                        appContext,
                        FinanceWidgetProvider::class.java,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                    )
                } else {
                    setComponentState(
                        appContext,
                        FinanceWidgetProvider::class.java,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                    )
                }
            }
        } catch (_: Exception) {
            // Ignore on environments without AppWidgetManager
        }
    }

    fun disableComponentIfUnused(context: Context, providerClass: Class<*>) {
        val appContext = context.applicationContext ?: context
        try {
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val component = ComponentName(appContext, providerClass)
            if (appWidgetManager.getAppWidgetIds(component).isEmpty()) {
                setComponentState(
                    appContext,
                    providerClass,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                )
            }
        } catch (_: Exception) {}
    }

    private fun setComponentState(context: Context, providerClass: Class<*>, desiredState: Int) {
        val pm = context.packageManager
        val component = ComponentName(context, providerClass)
        val currentState = pm.getComponentEnabledSetting(component)
        if (currentState != desiredState) {
            pm.setComponentEnabledSetting(
                component,
                desiredState,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}

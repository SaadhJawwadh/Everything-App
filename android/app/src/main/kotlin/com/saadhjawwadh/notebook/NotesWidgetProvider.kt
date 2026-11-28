package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class NotesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onDisabled(context: Context) {
        WidgetVisibilityManager.disableComponentIfUnused(context, NotesWidgetProvider::class.java)
        super.onDisabled(context)
    }

    companion object {
        private const val REQUEST_CODE_BASE = 300_000

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.notes_widget_layout)

            views.setOnClickPendingIntent(
                R.id.notes_widget_new_note,
                actionPendingIntent(context, "com.saadhjawwadh.notebook.NEW_NOTE", 1)
            )
            views.setOnClickPendingIntent(
                R.id.notes_widget_new_checklist,
                quickAddPendingIntent(context, 2)
            )
            views.setOnClickPendingIntent(
                R.id.notes_widget_search,
                actionPendingIntent(context, "com.saadhjawwadh.notebook.SEARCH", 3)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun quickAddPendingIntent(context: Context, slot: Int): PendingIntent {
            val intent = Intent(context, TodoQuickAddActivity::class.java).apply {
                putExtra("active_note_id", "ALL_NOTES")
                data = Uri.parse("widget://notes_quick_add/slot/$slot")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                REQUEST_CODE_BASE + slot,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun actionPendingIntent(context: Context, action: String, slot: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = action
                data = Uri.parse("widget://notes/slot/$slot")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                REQUEST_CODE_BASE + slot,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext ?: context
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val thisWidget = ComponentName(appContext, NotesWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                updateAppWidget(appContext, appWidgetManager, id)
            }
        }
    }
}

package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
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
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.notes_widget_layout)

            views.setOnClickPendingIntent(
                R.id.notes_widget_new_note,
                actionPendingIntent(context, "com.saadhjawwadh.notebook.NEW_NOTE", 10)
            )
            views.setOnClickPendingIntent(
                R.id.notes_widget_new_checklist,
                actionPendingIntent(context, "com.saadhjawwadh.notebook.QUICK_ADD_TODO", 12)
            )
            views.setOnClickPendingIntent(
                R.id.notes_widget_search,
                actionPendingIntent(context, "com.saadhjawwadh.notebook.SEARCH", 11)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun actionPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = action
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext ?: context
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val thisWidget = android.content.ComponentName(appContext, NotesWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allWidgetIds) {
                updateAppWidget(appContext, appWidgetManager, id)
            }
        }
    }
}

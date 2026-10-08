package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class TodoWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CYCLE_NOTE = "com.saadhjawwadh.notebook.ACTION_CYCLE_NOTE"
        const val ACTION_ITEM_CLICK = "com.saadhjawwadh.notebook.ACTION_ITEM_CLICK"
        const val ACTION_OPEN_NOTE = "com.saadhjawwadh.notebook.ACTION_OPEN_NOTE"
        const val ACTION_QUICK_ADD = "com.saadhjawwadh.notebook.QUICK_ADD_TODO"
        const val PREFS_NAME = "FlutterSharedPreferences"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, TodoWidgetProvider::class.java)
            )
            Log.d("TodoWidget", "updateAllWidgets called, found ids: ${ids.joinToString()}")
            if (ids.isNotEmpty()) {
                for (id in ids) {
                    updateAppWidget(context, appWidgetManager, id)
                }
                appWidgetManager.notifyAppWidgetViewDataChanged(ids, R.id.todo_widget_list)
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.todo_widget_layout)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
            
            // Check for per-widget active note first, fallback to global active note
            val activeNoteId = if (prefs.contains("flutter.widget_active_note_id_$appWidgetId")) {
                prefs.getString("flutter.widget_active_note_id_$appWidgetId", "ALL_NOTES") ?: "ALL_NOTES"
            } else {
                prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"
            }

            var title = "All Action Items"
            var checkedCount = 0
            var totalCount = 0

            try {
                val notesArr = JSONArray(notesJsonStr)
                if (activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()) {
                    title = "All Action Items"
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        val items = noteObj.optJSONArray("items") ?: continue
                        for (j in 0 until items.length()) {
                            totalCount++
                            if (items.getJSONObject(j).optBoolean("isDone", false)) {
                                checkedCount++
                            }
                        }
                    }
                } else {
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        if (noteObj.optString("id") == activeNoteId) {
                            title = noteObj.optString("title", "Checklist")
                            if (title.isBlank()) title = "Untitled Note"
                            val items = noteObj.optJSONArray("items") ?: continue
                            for (j in 0 until items.length()) {
                                totalCount++
                                if (items.getJSONObject(j).optBoolean("isDone", false)) {
                                    checkedCount++
                                }
                            }
                            break
                        }
                    }
                }
            } catch (_: Exception) {}

            Log.d("TodoWidget", "updateAppWidget id=$appWidgetId title=$title counter=$checkedCount/$totalCount")
            views.setTextViewText(R.id.todo_widget_title, title)
            views.setTextViewText(R.id.todo_widget_counter, "$checkedCount/$totalCount done")

            // Bind ListView to RemoteViewsService with unique content URI
            val serviceIntent = Intent(context, TodoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("content://com.saadhjawwadh/todo_widget/$appWidgetId")
            }
            views.setRemoteAdapter(R.id.todo_widget_list, serviceIntent)
            views.setEmptyView(R.id.todo_widget_list, R.id.todo_widget_empty)

            // Switcher click: Cycle to next note for this widget
            val cycleIntent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                action = ACTION_CYCLE_NOTE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val cyclePendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 1,
                cycleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.todo_widget_switcher, cyclePendingIntent)
            views.setOnClickPendingIntent(R.id.todo_widget_title, cyclePendingIntent)

            // Add button click: Open quick add dialog in MainActivity
            val addIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ADD
                putExtra("active_note_id", activeNoteId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val addPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 2,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.todo_widget_add, addPendingIntent)
            // Empty view click: Open quick add dialog as well for effortless capture
            views.setOnClickPendingIntent(R.id.todo_widget_empty, addPendingIntent)

            // Template intent for list item clicks
            val itemClickIntent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                action = ACTION_ITEM_CLICK
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val itemClickPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 3,
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.todo_widget_list, itemClickPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }
}

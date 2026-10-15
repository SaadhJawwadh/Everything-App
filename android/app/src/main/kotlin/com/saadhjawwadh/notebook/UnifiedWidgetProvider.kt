package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import org.json.JSONArray

class UnifiedWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.unified_widget_layout)
        val prefs = context.getSharedPreferences(TodoWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)

        // 1. Populate Finance Domain Data
        val spentToday = prefs.getString("flutter.widget_spent_today", "Rs. 0") ?: "Rs. 0"
        val spentMonth = prefs.getString("flutter.widget_spent_month", "Rs. 0") ?: "Rs. 0"
        val netMonth = prefs.getString("flutter.widget_net_month", "+Rs. 0") ?: "+Rs. 0"
        val netPositive = prefs.getBoolean("flutter.widget_net_positive", true)

        views.setTextViewText(R.id.unified_net_balance, netMonth)
        val incomeColor = ContextCompat.getColor(context, R.color.widget_income)
        val expenseColor = ContextCompat.getColor(context, R.color.widget_expense)
        views.setTextColor(R.id.unified_net_balance, if (netPositive) incomeColor else expenseColor)

        views.setTextViewText(R.id.unified_today_spent, "Today: $spentToday")
        views.setTextViewText(R.id.unified_month_spent, "Month: $spentMonth")

        // 2. Populate Notes & Checklist Domain Data
        val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
        val activeNoteId = if (prefs.contains("flutter.widget_active_note_id_$appWidgetId")) {
            prefs.getString("flutter.widget_active_note_id_$appWidgetId", "ALL_NOTES") ?: "ALL_NOTES"
        } else {
            prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"
        }
        var activeNoteTitle = if (activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()) "All Action Items" else "Checklist"
        var targetNoteId = ""
        val pendingTasks = mutableListOf<String>()

        try {
            val notesArr = JSONArray(notesJsonStr)
            if (notesArr.length() > 0) {
                if (activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()) {
                    activeNoteTitle = "All Action Items"
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        val items = noteObj.optJSONArray("items") ?: continue
                        for (j in 0 until items.length()) {
                            val item = items.getJSONObject(j)
                            if (!item.optBoolean("isDone", false)) {
                                val text = item.optString("text", "").trim()
                                if (text.isNotEmpty()) {
                                    pendingTasks.add(text)
                                    if (targetNoteId.isEmpty()) {
                                        targetNoteId = noteObj.optString("id", "")
                                    }
                                    if (pendingTasks.size >= 2) break
                                }
                            }
                        }
                        if (pendingTasks.size >= 2) break
                    }
                } else {
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        if (noteObj.optString("id") == activeNoteId) {
                            targetNoteId = activeNoteId
                            activeNoteTitle = noteObj.optString("title", "Checklist")
                            if (activeNoteTitle.isBlank()) activeNoteTitle = "Untitled Note"
                            val items = noteObj.optJSONArray("items")
                            if (items != null) {
                                for (j in 0 until items.length()) {
                                    val item = items.getJSONObject(j)
                                    if (!item.optBoolean("isDone", false)) {
                                        val text = item.optString("text", "").trim()
                                        if (text.isNotEmpty()) {
                                            pendingTasks.add(text)
                                            if (pendingTasks.size >= 2) break
                                        }
                                    }
                                }
                            }
                            break
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        views.setTextViewText(R.id.unified_note_title, activeNoteTitle)

        if (pendingTasks.isNotEmpty()) {
            views.setViewVisibility(R.id.unified_notes_empty, View.GONE)
            views.setViewVisibility(R.id.unified_task_1_container, View.VISIBLE)
            views.setTextViewText(R.id.unified_task_1_text, pendingTasks[0])

            if (pendingTasks.size > 1) {
                views.setViewVisibility(R.id.unified_task_2_container, View.VISIBLE)
                views.setTextViewText(R.id.unified_task_2_text, pendingTasks[1])
            } else {
                views.setViewVisibility(R.id.unified_task_2_container, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.unified_task_1_container, View.GONE)
            views.setViewVisibility(R.id.unified_task_2_container, View.GONE)
            views.setViewVisibility(R.id.unified_notes_empty, View.VISIBLE)
        }

        // 3. Setup Touch Action PendingIntents
        // Finance Section click -> Open Ledger
        val ledgerIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.saadhjawwadh.notebook.VIEW_LEDGER"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val ledgerPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + 1,
            ledgerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.unified_finance_section, ledgerPendingIntent)

        // Add Transaction Button click -> Open Add Transaction modal
        val addTxIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.saadhjawwadh.notebook.ADD_TRANSACTION"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val addTxPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + 2,
            addTxIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.unified_btn_add_tx, addTxPendingIntent)

        // Notes Section click -> Open active note
        val openNoteIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.saadhjawwadh.notebook.ACTION_OPEN_NOTE"
            putExtra("open_note_id", targetNoteId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openNotePendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + 3,
            openNoteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.unified_notes_section, openNotePendingIntent)

        // New Note Button click -> Open Note Editor
        val newNoteIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.saadhjawwadh.notebook.NEW_NOTE"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val newNotePendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + 4,
            newNoteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.unified_btn_new_note, newNotePendingIntent)

        // Note Title / Selector click -> Open List Selector Picker
        val pickerIntent = Intent(context, TodoListPickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("widget://unified_picker/$appWidgetId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pickerPendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId * 10 + 5,
            pickerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.unified_list_selector, pickerPendingIntent)
        views.setOnClickPendingIntent(R.id.unified_note_title, pickerPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, UnifiedWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            val intent = Intent(context, UnifiedWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, allWidgetIds)
            }
            context.sendBroadcast(intent)
        }
    }
}

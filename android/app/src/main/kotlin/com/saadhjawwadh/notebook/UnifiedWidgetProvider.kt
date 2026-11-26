package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

class UnifiedWidgetProvider : AppWidgetProvider() {

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
        updateAppWidget(context, appWidgetManager, appWidgetId, newOptions)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onRestored(
        context: Context,
        oldWidgetIds: IntArray,
        newWidgetIds: IntArray
    ) {
        val count = minOf(oldWidgetIds.size, newWidgetIds.size)
        for (i in 0 until count) {
            WidgetCacheStore.migrateWidgetId(context, oldWidgetIds[i], newWidgetIds[i])
        }
        onUpdate(context, AppWidgetManager.getInstance(context), newWidgetIds)
        super.onRestored(context, oldWidgetIds, newWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetCacheStore.removeWidgetActiveNotes(context, appWidgetIds)
        super.onDeleted(context, appWidgetIds)
    }

    override fun onDisabled(context: Context) {
        WidgetVisibilityManager.disableComponentIfUnused(context, UnifiedWidgetProvider::class.java)
        super.onDisabled(context)
    }

    companion object {
        private const val REQUEST_CODE_BASE = 400_000

        private data class UnifiedTask(
            val noteId: String,
            val lineIndex: Int,
            val text: String
        )

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext ?: context
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val thisWidget = ComponentName(appContext, UnifiedWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (allWidgetIds.isNotEmpty()) {
                for (id in allWidgetIds) {
                    updateAppWidget(appContext, appWidgetManager, id)
                }
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            options: Bundle? = null
        ) {
            val views = RemoteViews(context.packageName, R.layout.unified_widget_layout)

            val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val isCompact = (minWidth in 1..220) || (minHeight in 1..90)

            // 1. Finance Domain (respecting module toggle & privacy mask)
            val isFinanceEnabled = WidgetCacheStore.isFinancialManagerEnabled(context)
            val isFinanceLocked = WidgetCacheStore.isFinanceLocked(context)
            val incomeColor = ContextCompat.getColor(context, R.color.widget_income)
            val expenseColor = ContextCompat.getColor(context, R.color.widget_expense)
            val mutedColor = ContextCompat.getColor(context, R.color.widget_text_secondary)

            if (!isFinanceEnabled) {
                views.setTextViewText(
                    R.id.unified_net_balance,
                    context.getString(R.string.widget_finances_disabled)
                )
                views.setTextColor(R.id.unified_net_balance, mutedColor)
                views.setTextViewText(R.id.unified_today_spent, "--")
                views.setViewVisibility(R.id.unified_month_spent, View.GONE)
            } else if (isFinanceLocked) {
                views.setTextViewText(R.id.unified_net_balance, "••••")
                views.setTextColor(R.id.unified_net_balance, mutedColor)
                views.setTextViewText(
                    R.id.unified_today_spent,
                    context.getString(R.string.widget_locked_title)
                )
                views.setViewVisibility(
                    R.id.unified_month_spent,
                    if (isCompact) View.GONE else View.VISIBLE
                )
                if (!isCompact) {
                    views.setTextViewText(R.id.unified_month_spent, "••••")
                }
            } else {
                var spentToday = "--"
                var spentMonth = "--"
                var netMonth = "--"
                var netPositive = true
                try {
                    val finJson = JSONObject(WidgetCacheStore.getFinanceSnapshotJson(context))
                    spentToday = finJson.optString("spentToday", "--").ifBlank { "--" }
                    spentMonth = finJson.optString("spentMonth", "--").ifBlank { "--" }
                    netMonth = finJson.optString("netMonth", "--").ifBlank { "--" }
                    netPositive = finJson.optBoolean("netPositive", true)
                } catch (_: Exception) {}

                views.setTextViewText(R.id.unified_net_balance, netMonth)
                views.setTextColor(
                    R.id.unified_net_balance,
                    if (netPositive) incomeColor else expenseColor
                )
                views.setTextViewText(
                    R.id.unified_today_spent,
                    "${context.getString(R.string.widget_today_label)}: $spentToday"
                )
                if (isCompact) {
                    views.setViewVisibility(R.id.unified_month_spent, View.GONE)
                } else {
                    views.setViewVisibility(R.id.unified_month_spent, View.VISIBLE)
                    views.setTextViewText(
                        R.id.unified_month_spent,
                        "${context.getString(R.string.widget_spent_month_label)}: $spentMonth"
                    )
                }
            }

            // 2. Notes & Checklist Domain (respecting privacy mask)
            val isTodoLocked = WidgetCacheStore.isTodoLocked(context)
            val activeNoteId = WidgetCacheStore.getActiveNoteId(context, appWidgetId)
            val fallbackTitle = WidgetCacheStore.getActiveNoteTitle(context, appWidgetId)
            val isAllNotesMode = activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()

            var activeNoteTitle = when {
                isAllNotesMode -> context.getString(R.string.widget_all_action_items)
                fallbackTitle.isNotBlank() -> fallbackTitle
                else -> context.getString(R.string.widget_checklist_fallback)
            }
            var targetNoteId = ""
            val pendingTasks = mutableListOf<UnifiedTask>()
            var totalTaskCount = 0
            var checkedTaskCount = 0

            if (!isTodoLocked) {
                val notesJsonStr = WidgetCacheStore.getTodoNotesJson(context)
                try {
                    val notesArr = JSONArray(notesJsonStr)
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        val noteId = noteObj.optString("id", "")
                        if (!isAllNotesMode && noteId != activeNoteId) continue

                        if (!isAllNotesMode) {
                            targetNoteId = activeNoteId
                            val parsedTitle = noteObj.optString("title", "")
                            if (parsedTitle.isNotBlank()) activeNoteTitle = parsedTitle
                        }

                        val items = noteObj.optJSONArray("items")
                        var arrayTotal = 0
                        var arrayChecked = 0
                        if (items != null) {
                            for (j in 0 until items.length()) {
                                val item = items.getJSONObject(j)
                                arrayTotal++
                                if (item.optBoolean("isDone", false)) {
                                    arrayChecked++
                                } else if (pendingTasks.size < 2) {
                                    val text = item.optString("text", "").trim()
                                    if (text.isNotEmpty()) {
                                        pendingTasks.add(
                                            UnifiedTask(
                                                noteId = noteId,
                                                lineIndex = item.optInt("lineIndex", j),
                                                text = text
                                            )
                                        )
                                        if (targetNoteId.isEmpty()) targetNoteId = noteId
                                    }
                                }
                            }
                        }

                        val noteTotal = if (noteObj.has("totalCount")) {
                            noteObj.optInt("totalCount", arrayTotal)
                        } else {
                            arrayTotal
                        }
                        val noteChecked = if (noteObj.has("checkedCount")) {
                            noteObj.optInt("checkedCount", arrayChecked)
                        } else {
                            arrayChecked
                        }
                        totalTaskCount += noteTotal
                        checkedTaskCount += noteChecked

                        if (!isAllNotesMode) break
                    }
                } catch (_: Exception) {}
            }

            views.setTextViewText(R.id.unified_note_title, activeNoteTitle)

            if (isTodoLocked) {
                views.setViewVisibility(R.id.unified_task_1_container, View.GONE)
                views.setViewVisibility(R.id.unified_task_2_container, View.GONE)
                views.setViewVisibility(R.id.unified_notes_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.unified_notes_empty,
                    context.getString(R.string.widget_locked_title)
                )
            } else if (pendingTasks.isNotEmpty()) {
                views.setViewVisibility(R.id.unified_notes_empty, View.GONE)
                views.setViewVisibility(R.id.unified_task_1_container, View.VISIBLE)
                views.setTextViewText(R.id.unified_task_1_text, pendingTasks[0].text)

                val toggle1Intent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                    action = TodoWidgetProvider.ACTION_ITEM_CLICK
                    data = Uri.parse("widget://unified_toggle/$appWidgetId/0")
                    putExtra("click_action", "toggle")
                    putExtra("note_id", pendingTasks[0].noteId)
                    putExtra("line_index", pendingTasks[0].lineIndex)
                    putExtra("text", pendingTasks[0].text)
                    putExtra("is_done", false)
                }
                val toggle1PendingIntent = PendingIntent.getBroadcast(
                    context,
                    REQUEST_CODE_BASE + appWidgetId * 10 + 6,
                    toggle1Intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.unified_task_1_check, toggle1PendingIntent)

                if (pendingTasks.size > 1 && !isCompact) {
                    views.setViewVisibility(R.id.unified_task_2_container, View.VISIBLE)
                    views.setTextViewText(R.id.unified_task_2_text, pendingTasks[1].text)

                    val toggle2Intent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                        action = TodoWidgetProvider.ACTION_ITEM_CLICK
                        data = Uri.parse("widget://unified_toggle/$appWidgetId/1")
                        putExtra("click_action", "toggle")
                        putExtra("note_id", pendingTasks[1].noteId)
                        putExtra("line_index", pendingTasks[1].lineIndex)
                        putExtra("text", pendingTasks[1].text)
                        putExtra("is_done", false)
                    }
                    val toggle2PendingIntent = PendingIntent.getBroadcast(
                        context,
                        REQUEST_CODE_BASE + appWidgetId * 10 + 7,
                        toggle2Intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.unified_task_2_check, toggle2PendingIntent)
                } else {
                    views.setViewVisibility(R.id.unified_task_2_container, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.unified_task_1_container, View.GONE)
                views.setViewVisibility(R.id.unified_task_2_container, View.GONE)
                views.setViewVisibility(R.id.unified_notes_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.unified_notes_empty,
                    if (totalTaskCount > 0 && checkedTaskCount >= totalTaskCount) {
                        context.getString(R.string.widget_all_tasks_completed)
                    } else {
                        context.getString(R.string.widget_no_pending_tasks)
                    }
                )
            }

            // 3. Touch Action PendingIntents
            val ledgerIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.saadhjawwadh.notebook.VIEW_LEDGER"
                data = Uri.parse("widget://unified/$appWidgetId/ledger")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.unified_finance_section,
                PendingIntent.getActivity(
                    context,
                    REQUEST_CODE_BASE + appWidgetId * 10 + 1,
                    ledgerIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            val addTxIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.saadhjawwadh.notebook.ADD_TRANSACTION"
                data = Uri.parse("widget://unified/$appWidgetId/add_tx")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.unified_btn_add_tx,
                PendingIntent.getActivity(
                    context,
                    REQUEST_CODE_BASE + appWidgetId * 10 + 2,
                    addTxIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            val openNoteIntent = Intent(context, MainActivity::class.java).apply {
                action = if (targetNoteId.isNotEmpty() && !isTodoLocked) {
                    TodoWidgetProvider.ACTION_OPEN_NOTE
                } else {
                    TodoWidgetProvider.ACTION_VIEW_NOTES
                }
                data = Uri.parse("widget://unified/$appWidgetId/open_note")
                if (targetNoteId.isNotEmpty() && !isTodoLocked) {
                    putExtra("open_note_id", targetNoteId)
                }
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.unified_notes_section,
                PendingIntent.getActivity(
                    context,
                    REQUEST_CODE_BASE + appWidgetId * 10 + 3,
                    openNoteIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            val newNoteIntent = Intent(context, MainActivity::class.java).apply {
                action = TodoWidgetProvider.ACTION_NEW_NOTE
                data = Uri.parse("widget://unified/$appWidgetId/new_note")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.unified_btn_new_note,
                PendingIntent.getActivity(
                    context,
                    REQUEST_CODE_BASE + appWidgetId * 10 + 4,
                    newNoteIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )

            val pickerIntent = Intent(context, TodoListPickerActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("widget://unified_picker/$appWidgetId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pickerPendingIntent = PendingIntent.getActivity(
                context,
                REQUEST_CODE_BASE + appWidgetId * 10 + 5,
                pickerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.unified_list_selector, pickerPendingIntent)
            views.setOnClickPendingIntent(R.id.unified_note_title, pickerPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import org.json.JSONArray

class TodoWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_ITEM_CLICK = "com.saadhjawwadh.notebook.ACTION_ITEM_CLICK"
        const val ACTION_OPEN_NOTE = "com.saadhjawwadh.notebook.ACTION_OPEN_NOTE"
        const val ACTION_QUICK_ADD = "com.saadhjawwadh.notebook.QUICK_ADD_TODO"
        const val ACTION_NEW_NOTE = "com.saadhjawwadh.notebook.NEW_NOTE"
        const val ACTION_SEARCH = "com.saadhjawwadh.notebook.SEARCH"
        const val ACTION_VIEW_NOTES = "com.saadhjawwadh.notebook.VIEW_NOTES"

        private const val REQUEST_CODE_BASE = 100_000
        private const val MAX_INLINE_ITEMS = 25

        data class PendingTaskItem(
            val noteId: String,
            val noteTitle: String,
            val lineIndex: Int,
            val text: String
        )

        private data class TodoWidgetState(
            val isLocked: Boolean,
            val activeNoteId: String,
            val title: String,
            val isAllNotesMode: Boolean,
            val totalCount: Int,
            val checkedCount: Int,
            val pendingCount: Int,
            val pendingItems: List<PendingTaskItem>
        )

        fun stableItemId(noteId: String, lineIndex: Int, text: String): Long {
            val input = "$noteId:$lineIndex:$text"
            var hash = -0x340d631b7bdddcdbL
            for (i in input.indices) {
                hash = hash xor input[i].code.toLong()
                hash *= 0x100000001b3L
            }
            return hash
        }

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext ?: context
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(appContext, TodoWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                for (id in ids) {
                    updateAppWidget(appContext, appWidgetManager, id)
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(ids, R.id.todo_widget_list)
                }
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            options: Bundle? = null
        ) {
            val state = loadState(context, appWidgetId)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val stripViews = buildStripViews(context, appWidgetId, state)
                val compactViews = buildListViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    layoutRes = R.layout.todo_widget_compact,
                    isCompact = true,
                    isExpanded = false,
                    state = state
                )
                val standardViews = buildListViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    layoutRes = R.layout.todo_widget_layout,
                    isCompact = false,
                    isExpanded = false,
                    state = state
                )
                val expandedViews = buildListViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    layoutRes = R.layout.todo_widget_expanded,
                    isCompact = false,
                    isExpanded = true,
                    state = state
                )

                val sizeMap = mapOf(
                    SizeF(110f, 56f) to stripViews,
                    SizeF(180f, 56f) to stripViews,
                    SizeF(140f, 110f) to compactViews,
                    SizeF(250f, 110f) to standardViews,
                    SizeF(360f, 280f) to expandedViews
                )
                appWidgetManager.updateAppWidget(appWidgetId, RemoteViews(sizeMap))
            } else {
                val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
                val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)

                val views = when {
                    minHeight in 1..90 -> buildStripViews(context, appWidgetId, state)
                    (minWidth in 1..200) || (minHeight in 1..150) -> buildListViews(
                        context = context,
                        appWidgetId = appWidgetId,
                        layoutRes = R.layout.todo_widget_compact,
                        isCompact = true,
                        isExpanded = false,
                        state = state
                    )
                    minWidth >= 340 && minHeight >= 260 -> buildListViews(
                        context = context,
                        appWidgetId = appWidgetId,
                        layoutRes = R.layout.todo_widget_expanded,
                        isCompact = false,
                        isExpanded = true,
                        state = state
                    )
                    else -> buildListViews(
                        context = context,
                        appWidgetId = appWidgetId,
                        layoutRes = R.layout.todo_widget_layout,
                        isCompact = false,
                        isExpanded = false,
                        state = state
                    )
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }

        private fun loadState(context: Context, appWidgetId: Int): TodoWidgetState {
            val isLocked = WidgetCacheStore.isTodoLocked(context)
            val activeNoteId = WidgetCacheStore.getActiveNoteId(context, appWidgetId)
            val fallbackTitle = WidgetCacheStore.getActiveNoteTitle(context, appWidgetId)
            val isAllNotesMode = activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()

            var title = when {
                isAllNotesMode -> context.getString(R.string.widget_all_action_items)
                fallbackTitle.isNotBlank() -> fallbackTitle
                else -> context.getString(R.string.widget_checklist_fallback)
            }

            if (isLocked) {
                return TodoWidgetState(
                    isLocked = true,
                    activeNoteId = activeNoteId,
                    title = title,
                    isAllNotesMode = isAllNotesMode,
                    totalCount = 0,
                    checkedCount = 0,
                    pendingCount = 0,
                    pendingItems = emptyList()
                )
            }

            val notesJsonStr = WidgetCacheStore.getTodoNotesJson(context)
            var checkedCount = 0
            var totalCount = 0
            var pendingCount = 0
            val pendingItems = mutableListOf<PendingTaskItem>()

            try {
                val notesArr = JSONArray(notesJsonStr)
                for (i in 0 until notesArr.length()) {
                    val noteObj = notesArr.getJSONObject(i)
                    val noteId = noteObj.optString("id", "")
                    if (!isAllNotesMode && noteId != activeNoteId) continue

                    val rawTitle = noteObj.optString("title", "")
                    val noteTitle = if (rawTitle.isBlank()) {
                        context.getString(R.string.widget_checklist_fallback)
                    } else {
                        rawTitle
                    }
                    if (!isAllNotesMode && rawTitle.isNotBlank()) {
                        title = rawTitle
                    }

                    val items = noteObj.optJSONArray("items")
                    var notePendingInArray = 0
                    var noteCheckedInArray = 0
                    val noteTotalInArray = items?.length() ?: 0

                    if (items != null) {
                        for (j in 0 until items.length()) {
                            val itemObj = items.getJSONObject(j)
                            val isDone = itemObj.optBoolean("isDone", false)
                            if (isDone) {
                                noteCheckedInArray++
                            } else {
                                notePendingInArray++
                                val text = itemObj.optString("text", "")
                                if (text.isNotBlank()) {
                                    pendingItems.add(
                                        PendingTaskItem(
                                            noteId = noteId,
                                            noteTitle = noteTitle,
                                            lineIndex = itemObj.optInt("lineIndex", j),
                                            text = text
                                        )
                                    )
                                }
                            }
                        }
                    }

                    val noteTotal = if (noteObj.has("totalCount")) {
                        noteObj.optInt("totalCount", noteTotalInArray)
                    } else {
                        noteTotalInArray
                    }
                    val noteChecked = if (noteObj.has("checkedCount")) {
                        noteObj.optInt("checkedCount", noteCheckedInArray)
                    } else {
                        noteCheckedInArray
                    }
                    val notePending = if (noteObj.has("pendingCount")) {
                        noteObj.optInt("pendingCount", (noteTotal - noteChecked).coerceAtLeast(0))
                    } else {
                        notePendingInArray
                    }

                    totalCount += noteTotal
                    checkedCount += noteChecked
                    pendingCount += notePending

                    if (!isAllNotesMode) break
                }
            } catch (_: Exception) {}

            return TodoWidgetState(
                isLocked = false,
                activeNoteId = activeNoteId,
                title = title,
                isAllNotesMode = isAllNotesMode,
                totalCount = totalCount,
                checkedCount = checkedCount,
                pendingCount = pendingCount.coerceAtLeast(pendingItems.size),
                pendingItems = pendingItems
            )
        }

        private fun buildStripViews(
            context: Context,
            appWidgetId: Int,
            state: TodoWidgetState
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.todo_widget_strip)

            views.setOnClickPendingIntent(
                R.id.todo_strip_new_note,
                activityIntent(context, appWidgetId, 4, ACTION_NEW_NOTE)
            )
            views.setOnClickPendingIntent(
                R.id.todo_strip_new_task,
                activityIntent(context, appWidgetId, 2, ACTION_QUICK_ADD) {
                    putExtra("active_note_id", state.activeNoteId)
                }
            )
            views.setOnClickPendingIntent(
                R.id.todo_strip_search,
                activityIntent(context, appWidgetId, 5, ACTION_SEARCH)
            )
            views.setOnClickPendingIntent(
                android.R.id.background,
                activityIntent(context, appWidgetId, 6, ACTION_VIEW_NOTES)
            )

            if (state.isLocked || state.pendingCount <= 0) {
                views.setViewVisibility(R.id.todo_strip_badge, View.GONE)
            } else {
                views.setViewVisibility(R.id.todo_strip_badge, View.VISIBLE)
                views.setTextViewText(R.id.todo_strip_badge, state.pendingCount.toString())
            }

            return views
        }

        private fun buildListViews(
            context: Context,
            appWidgetId: Int,
            layoutRes: Int,
            isCompact: Boolean,
            isExpanded: Boolean,
            state: TodoWidgetState
        ): RemoteViews {
            val views = RemoteViews(context.packageName, layoutRes)

            val unlockPendingIntent = activityIntent(context, appWidgetId, 6, ACTION_VIEW_NOTES)
            views.setOnClickPendingIntent(android.R.id.background, unlockPendingIntent)

            if (state.isLocked) {
                views.setViewVisibility(R.id.todo_locked_container, View.VISIBLE)
                views.setViewVisibility(R.id.todo_content_container, View.GONE)
                views.setOnClickPendingIntent(R.id.todo_locked_container, unlockPendingIntent)
                return views
            }

            views.setViewVisibility(R.id.todo_locked_container, View.GONE)
            views.setViewVisibility(R.id.todo_content_container, View.VISIBLE)

            views.setTextViewText(R.id.todo_widget_title, state.title)

            if (!isCompact) {
                val counterText = if (state.totalCount > 0 && state.pendingCount == 0) {
                    context.getString(R.string.widget_done_count, state.checkedCount, state.totalCount)
                } else {
                    context.getString(R.string.widget_left_count, state.pendingCount)
                }
                views.setTextViewText(R.id.todo_widget_counter, counterText)
            }

            // Empty state feedback
            if (state.totalCount > 0 && state.checkedCount >= state.totalCount) {
                views.setImageViewResource(R.id.todo_widget_empty_icon, R.drawable.ic_task_alt_rounded)
                views.setTextViewText(
                    R.id.todo_widget_empty_title,
                    context.getString(R.string.widget_all_tasks_completed)
                )
                views.setTextViewText(
                    R.id.todo_widget_empty_subtitle,
                    context.getString(R.string.widget_tap_plus_to_add)
                )
            } else {
                views.setImageViewResource(R.id.todo_widget_empty_icon, R.drawable.ic_checklist)
                views.setTextViewText(
                    R.id.todo_widget_empty_title,
                    context.getString(R.string.widget_no_pending_tasks)
                )
                views.setTextViewText(
                    R.id.todo_widget_empty_subtitle,
                    context.getString(R.string.widget_tap_plus_to_add)
                )
            }

            // List switcher picker
            val pickerIntent = Intent(context, TodoListPickerActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("widget://todo_picker/$appWidgetId")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pickerPendingIntent = PendingIntent.getActivity(
                context,
                requestCode(appWidgetId, 1),
                pickerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.todo_widget_switcher, pickerPendingIntent)
            views.setOnClickPendingIntent(R.id.todo_widget_title, pickerPendingIntent)

            // Quick add task button & empty state tap
            val addPendingIntent = activityIntent(context, appWidgetId, 2, ACTION_QUICK_ADD) {
                putExtra("active_note_id", state.activeNoteId)
            }
            views.setOnClickPendingIntent(R.id.todo_widget_add, addPendingIntent)
            views.setOnClickPendingIntent(R.id.todo_widget_empty_container, addPendingIntent)

            if (isExpanded) {
                views.setOnClickPendingIntent(
                    R.id.todo_widget_new_note,
                    activityIntent(context, appWidgetId, 4, ACTION_NEW_NOTE)
                )
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                bindInlineCollection(context, views, appWidgetId, state)
            } else {
                bindLegacyServiceCollection(context, views, appWidgetId)
            }

            views.setEmptyView(R.id.todo_widget_list, R.id.todo_widget_empty_container)
            return views
        }

        @RequiresApi(Build.VERSION_CODES.S)
        private fun bindInlineCollection(
            context: Context,
            views: RemoteViews,
            appWidgetId: Int,
            state: TodoWidgetState
        ) {
            val builder = RemoteViews.RemoteCollectionItems.Builder()
            val visibleItems = state.pendingItems.take(MAX_INLINE_ITEMS)

            for ((index, item) in visibleItems.withIndex()) {
                val itemViews = RemoteViews(context.packageName, R.layout.todo_widget_item)
                itemViews.setImageViewResource(R.id.todo_item_checkbox, R.drawable.ic_checkbox_unchecked)
                itemViews.setTextViewText(R.id.todo_item_text, item.text)

                if (state.isAllNotesMode) {
                    itemViews.setViewVisibility(R.id.todo_item_source_note, View.VISIBLE)
                    itemViews.setTextViewText(R.id.todo_item_source_note, item.noteTitle)
                } else {
                    itemViews.setViewVisibility(R.id.todo_item_source_note, View.GONE)
                }

                val itemReqBase = 1_000_000 + (appWidgetId and 0x7FFF) * 64 + index * 2

                // Direct Activity PendingIntent on text container (avoids Android 14-16 BAL block)
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_NOTE
                    data = Uri.parse("widget://todo_item/$appWidgetId/$index/open")
                    putExtra("open_note_id", item.noteId)
                    putExtra("line_index", item.lineIndex)
                    putExtra("text", item.text)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val openPendingIntent = PendingIntent.getActivity(
                    context,
                    itemReqBase,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                itemViews.setOnClickPendingIntent(R.id.todo_item_text_container, openPendingIntent)

                // Direct Broadcast PendingIntent on 48x48dp checkbox wrapper
                val toggleIntent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                    action = ACTION_ITEM_CLICK
                    data = Uri.parse("widget://todo_item/$appWidgetId/$index/toggle")
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    putExtra("click_action", "toggle")
                    putExtra("note_id", item.noteId)
                    putExtra("line_index", item.lineIndex)
                    putExtra("text", item.text)
                    putExtra("is_done", false)
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context,
                    itemReqBase + 1,
                    toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                itemViews.setOnClickPendingIntent(R.id.todo_item_checkbox_wrapper, togglePendingIntent)

                builder.addItem(stableItemId(item.noteId, item.lineIndex, item.text), itemViews)
            }

            val hasMore = state.pendingItems.size > MAX_INLINE_ITEMS || state.pendingCount > visibleItems.size
            if (hasMore && visibleItems.isNotEmpty()) {
                val footerViews = RemoteViews(context.packageName, R.layout.todo_widget_footer_item)
                footerViews.setTextViewText(
                    R.id.todo_footer_text,
                    context.getString(R.string.widget_view_all_tasks, state.pendingCount)
                )
                val footerPendingIntent = if (!state.isAllNotesMode && state.activeNoteId.isNotBlank()) {
                    activityIntent(context, appWidgetId, 7, ACTION_OPEN_NOTE) {
                        putExtra("open_note_id", state.activeNoteId)
                    }
                } else {
                    activityIntent(context, appWidgetId, 7, ACTION_VIEW_NOTES)
                }
                footerViews.setOnClickPendingIntent(R.id.todo_footer_row, footerPendingIntent)
                builder.addItem(-999_999L, footerViews)
                builder.setViewTypeCount(2)
            } else {
                builder.setViewTypeCount(1)
            }

            builder.setHasStableIds(true)
            views.setRemoteAdapter(R.id.todo_widget_list, builder.build())
        }

        private fun bindLegacyServiceCollection(
            context: Context,
            views: RemoteViews,
            appWidgetId: Int
        ) {
            val serviceIntent = Intent(context, TodoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("content://com.saadhjawwadh/todo_widget/$appWidgetId")
            }
            views.setRemoteAdapter(R.id.todo_widget_list, serviceIntent)

            val itemClickIntent = Intent(context, TodoWidgetActionReceiver::class.java).apply {
                action = ACTION_ITEM_CLICK
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val itemClickPendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode(appWidgetId, 3),
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setPendingIntentTemplate(R.id.todo_widget_list, itemClickPendingIntent)
        }

        private fun requestCode(appWidgetId: Int, slot: Int): Int {
            val safeId = if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) 0 else appWidgetId
            return REQUEST_CODE_BASE + safeId * 10 + slot
        }

        private inline fun activityIntent(
            context: Context,
            appWidgetId: Int,
            slot: Int,
            intentAction: String,
            crossinline extras: Intent.() -> Unit = {}
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = intentAction
                data = Uri.parse("widget://todo/$appWidgetId/slot/$slot")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                extras()
            }
            return PendingIntent.getActivity(
                context,
                requestCode(appWidgetId, slot),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && appWidgetIds.isNotEmpty()) {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.todo_widget_list)
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
}

package com.saadhjawwadh.notebook

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodoRemoteViewsFactory(applicationContext, intent)
    }
}

class TodoRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    data class TaskItem(
        val noteId: String,
        val noteTitle: String,
        val lineIndex: Int,
        val text: String
    )

    private val items = mutableListOf<TaskItem>()
    private var isAllNotesMode = true

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        items.clear()

        val extraId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        val appWidgetId = if (extraId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            extraId
        } else {
            intent.data?.lastPathSegment?.toIntOrNull() ?: AppWidgetManager.INVALID_APPWIDGET_ID
        }

        val activeNoteId = WidgetCacheStore.getActiveNoteId(context, appWidgetId)
        isAllNotesMode = activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()

        val notesJsonStr = WidgetCacheStore.getTodoNotesJson(context)
        val fallbackTitle = context.getString(R.string.widget_checklist_fallback)

        try {
            val notesArr = JSONArray(notesJsonStr)
            for (i in 0 until notesArr.length()) {
                val noteObj = notesArr.getJSONObject(i)
                val noteId = noteObj.optString("id")
                if (!isAllNotesMode && noteId != activeNoteId) {
                    continue
                }

                val rawTitle = noteObj.optString("title", "")
                val noteTitle = if (rawTitle.isBlank()) fallbackTitle else rawTitle
                val itemsArr = noteObj.optJSONArray("items") ?: continue

                for (j in 0 until itemsArr.length()) {
                    val itemObj = itemsArr.getJSONObject(j)
                    if (itemObj.optBoolean("isDone", false)) continue

                    val text = itemObj.optString("text", "")
                    if (text.isBlank()) continue

                    items.add(
                        TaskItem(
                            noteId = noteId,
                            noteTitle = noteTitle,
                            lineIndex = itemObj.optInt("lineIndex", j),
                            text = text
                        )
                    )
                }
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.todo_widget_item)
        if (position !in 0 until items.size) return views

        val item = items[position]

        views.setImageViewResource(R.id.todo_item_checkbox, R.drawable.ic_checkbox_unchecked)
        views.setTextViewText(R.id.todo_item_text, item.text)

        if (isAllNotesMode) {
            views.setViewVisibility(R.id.todo_item_source_note, View.VISIBLE)
            views.setTextViewText(R.id.todo_item_source_note, item.noteTitle)
        } else {
            views.setViewVisibility(R.id.todo_item_source_note, View.GONE)
        }

        val checkFillInIntent = Intent().apply {
            putExtra("click_action", "toggle")
            putExtra("note_id", item.noteId)
            putExtra("line_index", item.lineIndex)
            putExtra("text", item.text)
            putExtra("is_done", false)
        }
        views.setOnClickFillInIntent(R.id.todo_item_checkbox_wrapper, checkFillInIntent)

        val openFillInIntent = Intent().apply {
            putExtra("click_action", "open_note")
            putExtra("note_id", item.noteId)
            putExtra("line_index", item.lineIndex)
            putExtra("text", item.text)
        }
        views.setOnClickFillInIntent(R.id.todo_item_text_container, openFillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        if (position in 0 until items.size) {
            val item = items[position]
            return TodoWidgetProvider.stableItemId(item.noteId, item.lineIndex, item.text)
        }
        return position.toLong()
    }

    override fun hasStableIds(): Boolean = true
}

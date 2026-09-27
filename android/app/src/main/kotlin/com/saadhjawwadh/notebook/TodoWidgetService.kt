package com.saadhjawwadh.notebook

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

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
        val text: String,
        val isDone: Boolean
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
        val prefs = context.getSharedPreferences(TodoWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
        val activeNoteId = prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"

        isAllNotesMode = activeNoteId == "ALL_NOTES" || activeNoteId.isEmpty()
        val pendingList = mutableListOf<TaskItem>()
        val doneList = mutableListOf<TaskItem>()

        try {
            val notesArr = JSONArray(notesJsonStr)
            for (i in 0 until notesArr.length()) {
                val noteObj = notesArr.getJSONObject(i)
                val noteId = noteObj.optString("id")
                val noteTitle = noteObj.optString("title", "Untitled")

                if (!isAllNotesMode && noteId != activeNoteId) {
                    continue
                }

                val itemsArr = noteObj.optJSONArray("items") ?: continue
                for (j in 0 until itemsArr.length()) {
                    val itemObj = itemsArr.getJSONObject(j)
                    val lineIndex = itemObj.optInt("lineIndex", j)
                    val text = itemObj.optString("text", "")
                    val isDone = itemObj.optBoolean("isDone", false)

                    val item = TaskItem(
                        noteId = noteId,
                        noteTitle = if (noteTitle.isBlank()) "Untitled" else noteTitle,
                        lineIndex = lineIndex,
                        text = text,
                        isDone = isDone
                    )

                    if (isDone) {
                        doneList.add(item)
                    } else {
                        pendingList.add(item)
                    }
                }
            }
        } catch (_: Exception) {}

        // Pending tasks first, then completed items with strikethrough at bottom
        items.addAll(pendingList)
        items.addAll(doneList)
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.todo_widget_item)
        if (position !in 0 until items.size) return views

        val item = items[position]

        // Checkbox icon
        views.setImageViewResource(
            R.id.todo_item_checkbox,
            if (item.isDone) R.drawable.ic_checkbox_checked else R.drawable.ic_checkbox_unchecked
        )

        // Text & Strikethrough
        if (item.isDone) {
            val spannable = SpannableString(item.text).apply {
                setSpan(StrikethroughSpan(), 0, length, 0)
            }
            views.setTextViewText(R.id.todo_item_text, spannable)
            views.setTextColor(R.id.todo_item_text, context.getColor(R.color.widget_text_secondary))
        } else {
            views.setTextViewText(R.id.todo_item_text, item.text)
            views.setTextColor(R.id.todo_item_text, context.getColor(R.color.widget_text_primary))
        }

        // Source Note Badge (visible when aggregating all notes)
        if (isAllNotesMode) {
            views.setViewVisibility(R.id.todo_item_badge, View.VISIBLE)
            views.setTextViewText(R.id.todo_item_badge, item.noteTitle)
        } else {
            views.setViewVisibility(R.id.todo_item_badge, View.GONE)
        }

        // Fill-in Intent for clicking the item
        val fillInIntent = Intent().apply {
            putExtra("note_id", item.noteId)
            putExtra("line_index", item.lineIndex)
            putExtra("is_done", item.isDone)
        }
        views.setOnClickFillInIntent(R.id.todo_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}

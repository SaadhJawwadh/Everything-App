package com.saadhjawwadh.notebook

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

class TodoWidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences(TodoWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)

        when (intent.action) {
            TodoWidgetProvider.ACTION_CYCLE_NOTE -> {
                val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
                val currentActive = prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"

                val noteIds = mutableListOf("ALL_NOTES")
                try {
                    val notesArr = JSONArray(notesJsonStr)
                    for (i in 0 until notesArr.length()) {
                        val id = notesArr.getJSONObject(i).optString("id")
                        if (id.isNotEmpty()) noteIds.add(id)
                    }
                } catch (_: Exception) {}

                var nextIndex = 0
                val currentIndex = noteIds.indexOf(currentActive)
                if (currentIndex >= 0 && noteIds.isNotEmpty()) {
                    nextIndex = (currentIndex + 1) % noteIds.size
                }
                val newActiveNoteId = noteIds[nextIndex]

                android.util.Log.d("TodoWidget", "ACTION_CYCLE_NOTE: activeNoteId=$newActiveNoteId")
                prefs.edit().putString("flutter.widget_active_note_id", newActiveNoteId).commit()
                TodoWidgetProvider.updateAllWidgets(context)
            }

            TodoWidgetProvider.ACTION_ITEM_CLICK -> {
                val noteId = intent.getStringExtra("note_id") ?: return
                val lineIndex = intent.getIntExtra("line_index", -1)
                val currentIsDone = intent.getBooleanExtra("is_done", false)
                val newIsDone = !currentIsDone

                if (lineIndex < 0) return

                // 1. Update visual JSON in SharedPreferences for 0ms feedback
                val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
                try {
                    val notesArr = JSONArray(notesJsonStr)
                    for (i in 0 until notesArr.length()) {
                        val noteObj = notesArr.getJSONObject(i)
                        if (noteObj.optString("id") == noteId) {
                            val itemsArr = noteObj.optJSONArray("items") ?: continue
                            for (j in 0 until itemsArr.length()) {
                                val itemObj = itemsArr.getJSONObject(j)
                                if (itemObj.optInt("lineIndex") == lineIndex) {
                                    itemObj.put("isDone", newIsDone)
                                    break
                                }
                            }
                            break
                        }
                    }
                    prefs.edit().putString("flutter.widget_todo_notes_json", notesArr.toString()).commit()
                } catch (_: Exception) {}

                // 2. Queue toggle for Flutter persistence
                val pendingJsonStr = prefs.getString("flutter.widget_pending_toggles", "[]") ?: "[]"
                try {
                    val pendingArr = JSONArray(pendingJsonStr)
                    val toggleObj = JSONObject().apply {
                        put("noteId", noteId)
                        put("lineIndex", lineIndex)
                        put("isDone", newIsDone)
                        put("timestamp", System.currentTimeMillis())
                    }
                    pendingArr.put(toggleObj)
                    prefs.edit().putString("flutter.widget_pending_toggles", pendingArr.toString()).commit()
                } catch (_: Exception) {}

                android.util.Log.d("TodoWidget", "ACTION_ITEM_CLICK: noteId=$noteId lineIndex=$lineIndex isDone=$newIsDone")
                // 3. Immediately refresh widget UI
                TodoWidgetProvider.updateAllWidgets(context)

                // 4. Notify Flutter engine if running
                MainActivity.notifyWidgetToggle()
            }
        }
    }
}

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
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"
                
                val currentActive = if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID && prefs.contains("flutter.widget_active_note_id_$appWidgetId")) {
                    prefs.getString("flutter.widget_active_note_id_$appWidgetId", "ALL_NOTES") ?: "ALL_NOTES"
                } else {
                    prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"
                }

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

                android.util.Log.d("TodoWidget", "ACTION_CYCLE_NOTE: appWidgetId=$appWidgetId activeNoteId=$newActiveNoteId")
                val editor = prefs.edit()
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    editor.putString("flutter.widget_active_note_id_$appWidgetId", newActiveNoteId)
                }
                editor.putString("flutter.widget_active_note_id", newActiveNoteId)
                editor.apply()

                TodoWidgetProvider.updateAllWidgets(context)
            }

            TodoWidgetProvider.ACTION_ITEM_CLICK -> {
                val clickAction = intent.getStringExtra("click_action") ?: "toggle"
                val noteId = intent.getStringExtra("note_id") ?: return
                val lineIndex = intent.getIntExtra("line_index", -1)
                val text = intent.getStringExtra("text") ?: ""

                if (clickAction == "open_note") {
                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        action = TodoWidgetProvider.ACTION_OPEN_NOTE
                        putExtra("open_note_id", noteId)
                        putExtra("line_index", lineIndex)
                        putExtra("text", text)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    context.startActivity(openIntent)
                    return
                }

                val currentIsDone = intent.getBooleanExtra("is_done", false)
                val newIsDone = !currentIsDone

                if (lineIndex < 0 && text.isEmpty()) return

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
                                val itemLineIdx = itemObj.optInt("lineIndex", -1)
                                val itemText = itemObj.optString("text", "")
                                
                                val matches = (text.isNotEmpty() && itemText == text) || (lineIndex >= 0 && itemLineIdx == lineIndex)
                                if (matches) {
                                    itemObj.put("isDone", newIsDone)
                                    break
                                }
                            }
                            break
                        }
                    }
                    prefs.edit().putString("flutter.widget_todo_notes_json", notesArr.toString()).apply()
                } catch (_: Exception) {}

                // 2. Queue toggle for Flutter persistence with squashing of rapid toggles
                val pendingJsonStr = prefs.getString("flutter.widget_pending_toggles", "[]") ?: "[]"
                try {
                    val pendingArr = JSONArray(pendingJsonStr)
                    var foundExisting = false
                    for (i in 0 until pendingArr.length()) {
                        val existingObj = pendingArr.getJSONObject(i)
                        val existingNoteId = existingObj.optString("noteId")
                        val existingLineIdx = existingObj.optInt("lineIndex", -1)
                        val existingText = existingObj.optString("text", "")

                        val isSameItem = existingNoteId == noteId && (
                            (text.isNotEmpty() && existingText == text) ||
                            (lineIndex >= 0 && existingLineIdx == lineIndex)
                        )

                        if (isSameItem) {
                            existingObj.put("isDone", newIsDone)
                            existingObj.put("timestamp", System.currentTimeMillis())
                            if (text.isNotEmpty()) existingObj.put("text", text)
                            foundExisting = true
                            break
                        }
                    }

                    if (!foundExisting) {
                        val toggleObj = JSONObject().apply {
                            put("noteId", noteId)
                            put("lineIndex", lineIndex)
                            put("text", text)
                            put("isDone", newIsDone)
                            put("timestamp", System.currentTimeMillis())
                        }
                        pendingArr.put(toggleObj)
                    }
                    prefs.edit().putString("flutter.widget_pending_toggles", pendingArr.toString()).apply()
                } catch (_: Exception) {}

                android.util.Log.d("TodoWidget", "ACTION_ITEM_CLICK: noteId=$noteId text=$text lineIndex=$lineIndex isDone=$newIsDone")
                
                // 3. Immediately refresh widget UI
                TodoWidgetProvider.updateAllWidgets(context)

                // 4. Notify Flutter engine if running
                MainActivity.notifyWidgetToggle()
            }
        }
    }
}

package com.saadhjawwadh.notebook

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import org.json.JSONArray

class TodoListPickerActivity : Activity() {

    data class TodoListItem(
        val id: String,
        val title: String,
        val subtitle: String,
        val isSelected: Boolean
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_todo_list_picker)

        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )

        findViewById<View>(R.id.picker_scrim).setOnClickListener {
            finish()
        }

        findViewById<View>(R.id.picker_btn_cancel).setOnClickListener {
            finish()
        }

        findViewById<View>(R.id.picker_btn_new_list).setOnClickListener {
            val addIntent = Intent(this, MainActivity::class.java).apply {
                action = TodoWidgetProvider.ACTION_QUICK_ADD
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(addIntent)
            finish()
        }

        val prefs = getSharedPreferences(TodoWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val notesJsonStr = prefs.getString("flutter.widget_todo_notes_json", "[]") ?: "[]"

        val currentActive = if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
            prefs.contains("flutter.widget_active_note_id_$appWidgetId")) {
            prefs.getString("flutter.widget_active_note_id_$appWidgetId", "ALL_NOTES") ?: "ALL_NOTES"
        } else {
            prefs.getString("flutter.widget_active_note_id", "ALL_NOTES") ?: "ALL_NOTES"
        }

        val itemsList = mutableListOf<TodoListItem>()

        try {
            val notesArr = JSONArray(notesJsonStr)
            var totalAll = 0
            var doneAll = 0

            val individualNotes = mutableListOf<TodoListItem>()

            for (i in 0 until notesArr.length()) {
                val noteObj = notesArr.getJSONObject(i)
                val id = noteObj.optString("id")
                var title = noteObj.optString("title", "Checklist")
                if (title.isBlank()) title = "Untitled Note"

                val items = noteObj.optJSONArray("items")
                var noteTotal = 0
                var noteDone = 0

                if (items != null) {
                    for (j in 0 until items.length()) {
                        noteTotal++
                        if (items.getJSONObject(j).optBoolean("isDone", false)) {
                            noteDone++
                        }
                    }
                }

                totalAll += noteTotal
                doneAll += noteDone

                individualNotes.add(
                    TodoListItem(
                        id = id,
                        title = title,
                        subtitle = if (noteTotal == 0) "No tasks yet" else "$noteTotal tasks • $noteDone done",
                        isSelected = (id == currentActive)
                    )
                )
            }

            // Primary Option: All Action Items aggregated
            itemsList.add(
                TodoListItem(
                    id = "ALL_NOTES",
                    title = "All Action Items",
                    subtitle = if (totalAll == 0) "No tasks across notes" else "$totalAll tasks • $doneAll done",
                    isSelected = (currentActive == "ALL_NOTES" || currentActive.isEmpty())
                )
            )

            // Add all user notes
            itemsList.addAll(individualNotes)

        } catch (e: Exception) {
            android.util.Log.e("TodoListPickerActivity", "Error parsing notes JSON", e)
            itemsList.add(
                TodoListItem(
                    id = "ALL_NOTES",
                    title = "All Action Items",
                    subtitle = "All pending checklists",
                    isSelected = true
                )
            )
        }

        val listView = findViewById<ListView>(R.id.picker_list_view)
        val adapter = object : BaseAdapter() {
            override fun getCount(): Int = itemsList.size
            override fun getItem(position: Int): Any = itemsList[position]
            override fun getItemId(position: Int): Long = position.toLong()

            override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
                val view = convertView ?: LayoutInflater.from(this@TodoListPickerActivity)
                    .inflate(R.layout.item_todo_list_picker, parent, false)

                val item = itemsList[position]
                val titleView = view.findViewById<TextView>(R.id.picker_item_title)
                val subtitleView = view.findViewById<TextView>(R.id.picker_item_subtitle)
                val checkView = view.findViewById<ImageView>(R.id.picker_item_check)

                titleView.text = item.title
                subtitleView.text = item.subtitle
                checkView.visibility = if (item.isSelected) View.VISIBLE else View.GONE

                return view
            }
        }

        listView.adapter = adapter
        listView.setOnItemClickListener { _, _, position, _ ->
            val selected = itemsList[position]
            android.util.Log.d("TodoListPickerActivity", "Selected list: ${selected.id} for appWidgetId=$appWidgetId")

            val editor = prefs.edit()
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                editor.putString("flutter.widget_active_note_id_$appWidgetId", selected.id)
            }
            editor.putString("flutter.widget_active_note_id", selected.id)
            editor.apply()

            TodoWidgetProvider.updateAllWidgets(this@TodoListPickerActivity)
            UnifiedWidgetProvider.updateAllWidgets(this@TodoListPickerActivity)

            finish()
            overridePendingTransition(0, 0)
        }
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }
}

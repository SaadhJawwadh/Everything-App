package com.saadhjawwadh.notebook

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.BaseAdapter
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import org.json.JSONArray

class TodoListPickerActivity : Activity() {

    data class TodoListItem(
        val id: String,
        val title: String,
        val subtitle: String,
        val isSelected: Boolean
    )

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            bindForIntent(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (WidgetCacheStore.isAppLockEnabled(this)) {
            val unlockIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(unlockIntent)
            finish()
            return
        }

        if (WidgetCacheStore.isScreenshotShieldEnabled(this)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        setContentView(R.layout.activity_todo_list_picker)

        findViewById<View>(R.id.picker_root)?.let { rootView ->
            ViewCompat.setOnApplyWindowInsetsListener(rootView) { view, windowInsets ->
                val insets = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
                )
                view.setPadding(insets.left, insets.top, insets.right, insets.bottom)
                WindowInsetsCompat.CONSUMED
            }
        }

        bindForIntent(intent)
    }

    private fun bindForIntent(activeIntent: Intent) {
        val extraId = activeIntent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        val appWidgetId = if (extraId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            extraId
        } else {
            activeIntent.data?.lastPathSegment?.toIntOrNull() ?: AppWidgetManager.INVALID_APPWIDGET_ID
        }

        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            val cancelResult = Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            setResult(RESULT_CANCELED, cancelResult)
        }

        findViewById<View>(R.id.picker_scrim).setOnClickListener {
            finish()
        }

        findViewById<View>(R.id.picker_btn_cancel).setOnClickListener {
            finish()
        }

        findViewById<View>(R.id.picker_btn_new_list).setOnClickListener {
            val newChecklistIntent = Intent(this, MainActivity::class.java).apply {
                action = "com.saadhjawwadh.notebook.NEW_CHECKLIST_NOTE"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(newChecklistIntent)
            finish()
        }

        val notesJsonStr = WidgetCacheStore.getTodoNotesJson(this)
        val currentActive = WidgetCacheStore.getActiveNoteId(this, appWidgetId)
        val allActionTitle = getString(R.string.widget_all_action_items)
        val checklistFallback = getString(R.string.widget_checklist_fallback)

        val itemsList = mutableListOf<TodoListItem>()
        try {
            val notesArr = JSONArray(notesJsonStr)
            var totalAll = 0
            var doneAll = 0
            val individualNotes = mutableListOf<TodoListItem>()

            for (i in 0 until notesArr.length()) {
                val noteObj = notesArr.getJSONObject(i)
                val id = noteObj.optString("id")
                val rawTitle = noteObj.optString("title", checklistFallback)
                val title = if (rawTitle.isBlank()) checklistFallback else rawTitle

                val items = noteObj.optJSONArray("items")
                var arrayTotal = 0
                var arrayDone = 0
                if (items != null) {
                    for (j in 0 until items.length()) {
                        arrayTotal++
                        if (items.getJSONObject(j).optBoolean("isDone", false)) {
                            arrayDone++
                        }
                    }
                }

                val noteTotal = if (noteObj.has("totalCount")) {
                    noteObj.optInt("totalCount", arrayTotal)
                } else {
                    arrayTotal
                }
                val noteDone = if (noteObj.has("checkedCount")) {
                    noteObj.optInt("checkedCount", arrayDone)
                } else {
                    arrayDone
                }
                val notePending = if (noteObj.has("pendingCount")) {
                    noteObj.optInt("pendingCount", (noteTotal - noteDone).coerceAtLeast(0))
                } else {
                    (noteTotal - noteDone).coerceAtLeast(0)
                }

                totalAll += noteTotal
                doneAll += noteDone

                val noteSubtitle = when {
                    noteTotal == 0 -> getString(R.string.widget_no_tasks_yet)
                    notePending == 0 -> getString(R.string.widget_all_done_fmt, noteTotal)
                    else -> getString(R.string.widget_pending_done_fmt, notePending, noteDone)
                }

                individualNotes.add(
                    TodoListItem(
                        id = id,
                        title = title,
                        subtitle = noteSubtitle,
                        isSelected = (id == currentActive)
                    )
                )
            }

            val allPending = (totalAll - doneAll).coerceAtLeast(0)
            val allSubtitle = when {
                totalAll == 0 -> getString(R.string.widget_no_tasks_yet)
                allPending == 0 -> getString(R.string.widget_all_done_fmt, totalAll)
                else -> getString(R.string.widget_pending_done_fmt, allPending, doneAll)
            }

            itemsList.add(
                TodoListItem(
                    id = "ALL_NOTES",
                    title = allActionTitle,
                    subtitle = allSubtitle,
                    isSelected = (currentActive == "ALL_NOTES" || currentActive.isEmpty())
                )
            )
            itemsList.addAll(individualNotes)
        } catch (_: Exception) {
            itemsList.add(
                TodoListItem(
                    id = "ALL_NOTES",
                    title = allActionTitle,
                    subtitle = getString(R.string.widget_no_tasks_yet),
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
        listView.setOnItemClickListener { clickedView, _, position, _ ->
            clickedView?.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
            val selected = itemsList[position]

            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                WidgetCacheStore.setActiveNoteForWidget(
                    applicationContext,
                    appWidgetId,
                    selected.id,
                    selected.title
                )
                val resultIntent = Intent().apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                setResult(RESULT_OK, resultIntent)
            } else {
                WidgetCacheStore.setGlobalActiveNote(applicationContext, selected.id, selected.title)
                val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                val todoIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, TodoWidgetProvider::class.java)
                )
                for (id in todoIds) {
                    WidgetCacheStore.setActiveNoteForWidget(
                        applicationContext,
                        id,
                        selected.id,
                        selected.title
                    )
                }
                val unifiedIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, UnifiedWidgetProvider::class.java)
                )
                for (id in unifiedIds) {
                    WidgetCacheStore.setActiveNoteForWidget(
                        applicationContext,
                        id,
                        selected.id,
                        selected.title
                    )
                }
            }

            TodoWidgetProvider.updateAllWidgets(applicationContext)
            UnifiedWidgetProvider.updateAllWidgets(applicationContext)
            finish()
        }
    }
}

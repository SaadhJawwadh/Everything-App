package com.saadhjawwadh.notebook

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TodoWidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TodoWidgetProvider.ACTION_ITEM_CLICK) return

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

        // Block background checklist mutations when Todo widget privacy lock is active
        if (WidgetCacheStore.isTodoLocked(context)) {
            return
        }

        if (lineIndex < 0 && text.isEmpty()) return

        val fallbackIsDone = intent.getBooleanExtra("is_done", false)
        WidgetCacheStore.toggleTodoItemOptimistically(
            context = context,
            noteId = noteId,
            lineIndex = lineIndex,
            text = text,
            fallbackIsDone = fallbackIsDone
        )

        TodoWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)
        MainActivity.notifyWidgetToggle()
    }
}

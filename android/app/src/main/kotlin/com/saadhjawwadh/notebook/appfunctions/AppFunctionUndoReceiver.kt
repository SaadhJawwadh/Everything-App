package com.saadhjawwadh.notebook.appfunctions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AppFunctionUndoReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_UNDO_APPFUNCTION = "com.saadhjawwadh.notebook.ACTION_UNDO_APPFUNCTION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_UNDO_APPFUNCTION) {
            val actionId = intent.getStringExtra("action_id") ?: return
            AppFunctionBridge.undoAction(context, actionId)
        }
    }
}

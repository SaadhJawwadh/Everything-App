package com.saadhjawwadh.notebook.appfunctions

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.saadhjawwadh.notebook.FinanceWidgetProvider
import com.saadhjawwadh.notebook.MainActivity
import com.saadhjawwadh.notebook.NotesWidgetProvider
import com.saadhjawwadh.notebook.R
import com.saadhjawwadh.notebook.TodoWidgetProvider
import com.saadhjawwadh.notebook.UnifiedWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object AppFunctionBridge {
    const val PREFS_NAME = "FlutterSharedPreferences"
    const val PENDING_QUEUE_KEY = "flutter.pending_appfunctions_queue"
    private const val NOTIFICATION_CHANNEL_ID = "appfunctions_receipt_channel"
    private const val NOTIFICATION_CHANNEL_NAME = "AI Assistant Receipts"

    fun logExpense(context: Context, params: LogExpenseParams): ExpenseResult {
        val id = UUID.randomUUID().toString()
        val account = if (!params.accountType.isNullOrBlank()) params.accountType else "daily"
        val category = if (!params.category.isNullOrBlank()) params.category else autoDetectCategory(params.description)

        val payload = JSONObject().apply {
            put("action", "log_expense")
            put("id", id)
            put("amount", params.amount)
            put("description", params.description)
            put("category", category)
            put("accountType", account)
            put("isExpense", params.isExpense)
            put("timestamp", System.currentTimeMillis())
        }
        enqueueAction(context, payload)

        // 1. Immediately refresh native Android finance widgets
        FinanceWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)

        // 2. Notify active Flutter engine if foregrounded
        MainActivity.notifyWidgetToggle()

        // 3. Post low-priority ambient notification receipt with Undo action
        val currencySymbol = getStoredCurrencySymbol(context)
        val title = if (params.isExpense) "Expense Logged" else "Income Logged"
        val message = "$currencySymbol${params.amount} for ${params.description} ($category)"
        postAmbientReceiptNotification(context, id, title, message)

        return ExpenseResult(
            success = true,
            transactionId = id,
            formattedSummary = "Logged $currencySymbol${params.amount} under $category in ${if (account == "savings") "Savings Vault" else "Daily Account"}."
        )
    }

    fun addTask(context: Context, params: AddTaskParams): TaskResult {
        val id = UUID.randomUUID().toString()
        val target = if (!params.targetNoteTitle.isNullOrBlank()) params.targetNoteTitle else "Today's Tasks"

        val payload = JSONObject().apply {
            put("action", "add_task")
            put("id", id)
            put("title", params.title)
            put("targetNoteTitle", target)
            put("timestamp", System.currentTimeMillis())
        }
        enqueueAction(context, payload)

        // 1. Immediately refresh native checklist widgets
        TodoWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)

        // 2. Notify active Flutter engine
        MainActivity.notifyWidgetToggle()

        // 3. Post notification receipt with Undo
        postAmbientReceiptNotification(context, id, "Task Added", "${params.title} ➔ $target")

        return TaskResult(
            success = true,
            taskTitle = params.title,
            targetNote = target
        )
    }

    fun createNote(context: Context, params: CreateNoteParams): NoteResult {
        val id = UUID.randomUUID().toString()
        val folder = params.folder ?: "Notes"

        val payload = JSONObject().apply {
            put("action", "create_note")
            put("id", id)
            put("title", params.title)
            put("content", params.content)
            put("folder", folder)
            put("timestamp", System.currentTimeMillis())
        }
        enqueueAction(context, payload)

        NotesWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)
        MainActivity.notifyWidgetToggle()

        postAmbientReceiptNotification(context, id, "Note Created", params.title)

        return NoteResult(
            success = true,
            noteId = id,
            title = params.title
        )
    }

    fun getCashFlowSummary(context: Context, params: GetCashFlowSummaryParams): CashFlowSummaryResult {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currencySymbol = getStoredCurrencySymbol(context)
        
        // Instant reading from widget cached financial calculations
        val financeJsonStr = prefs.getString("flutter.widget_finance_json", "{}") ?: "{}"
        var netBalance = 0.0
        var totalIncome = 0.0
        var totalExpense = 0.0

        try {
            val json = JSONObject(financeJsonStr)
            netBalance = json.optDouble("netBalance", 0.0)
            totalIncome = json.optDouble("totalIncome", 0.0)
            totalExpense = json.optDouble("totalExpense", 0.0)
        } catch (_: Exception) {}

        val summary = "Your active balance is $currencySymbol$netBalance (Income: $currencySymbol$totalIncome, Spending: $currencySymbol$totalExpense)."

        return CashFlowSummaryResult(
            success = true,
            summaryText = summary,
            netBalance = netBalance,
            currencySymbol = currencySymbol
        )
    }

    fun undoAction(context: Context, actionId: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentQueue = prefs.getString(PENDING_QUEUE_KEY, "[]") ?: "[]"
        try {
            val array = JSONArray(currentQueue)
            val updated = JSONArray()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                if (obj.optString("id") != actionId) {
                    updated.put(obj)
                }
            }
            prefs.edit().putString(PENDING_QUEUE_KEY, updated.toString()).apply()
        } catch (_: Exception) {}

        // Dismiss notification
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(actionId.hashCode())

        // Refresh widgets
        FinanceWidgetProvider.updateAllWidgets(context)
        TodoWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)
        MainActivity.notifyWidgetToggle()
    }

    private fun enqueueAction(context: Context, obj: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentQueue = prefs.getString(PENDING_QUEUE_KEY, "[]") ?: "[]"
        val array = try { JSONArray(currentQueue) } catch (_: Exception) { JSONArray() }
        array.put(obj)
        prefs.edit().putString(PENDING_QUEUE_KEY, array.toString()).apply()
    }

    private fun getStoredCurrencySymbol(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("flutter.currency_symbol", "Rs.") ?: "Rs."
    }

    private fun autoDetectCategory(description: String): String {
        val lower = description.lowercase()
        return when {
            lower.contains("coffee") || lower.contains("tea") || lower.contains("food") ||
            lower.contains("dinner") || lower.contains("lunch") || lower.contains("breakfast") ||
            lower.contains("restaurant") || lower.contains("pizza") || lower.contains("burger") ||
            lower.contains("uber eats") || lower.contains("pickme food") -> "Food & Dining"

            lower.contains("uber") || lower.contains("taxi") || lower.contains("fuel") ||
            lower.contains("petrol") || lower.contains("diesel") || lower.contains("bus") ||
            lower.contains("train") || lower.contains("flight") -> "Transportation"

            lower.contains("grocery") || lower.contains("supermarket") || lower.contains("keells") ||
            lower.contains("cargills") || lower.contains("milk") || lower.contains("bread") -> "Groceries"

            lower.contains("electricity") || lower.contains("water") || lower.contains("internet") ||
            lower.contains("dialog") || lower.contains("mobitel") || lower.contains("bill") -> "Utilities"

            lower.contains("netflix") || lower.contains("spotify") || lower.contains("movie") ||
            lower.contains("cinema") || lower.contains("game") -> "Entertainment"

            lower.contains("doctor") || lower.contains("pharmacy") || lower.contains("medicine") ||
            lower.contains("hospital") -> "Healthcare"

            lower.contains("salary") || lower.contains("bonus") || lower.contains("interest") ||
            lower.contains("dividend") -> "Income"

            else -> "Shopping"
        }
    }

    private fun postAmbientReceiptNotification(
        context: Context,
        actionId: String,
        title: String,
        content: String
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        // Create low-priority ambient notification channel if needed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Receipt confirmations for Gemini and Assistant background actions"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        // Tap notification to open Everything App
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            actionId.hashCode(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Undo action pending intent
        val undoIntent = Intent(context, AppFunctionUndoReceiver::class.java).apply {
            action = AppFunctionUndoReceiver.ACTION_UNDO_APPFUNCTION
            putExtra("action_id", actionId)
        }
        val undoPendingIntent = PendingIntent.getBroadcast(
            context,
            actionId.hashCode() + 1,
            undoIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(content)
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(R.drawable.ic_notification, "Undo", undoPendingIntent)
            .build()

        manager.notify(actionId.hashCode(), notification)
    }
}

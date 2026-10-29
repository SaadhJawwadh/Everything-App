package com.saadhjawwadh.notebook.appfunctions

import androidx.appfunctions.AppFunctionSerializable

/**
 * Parameter model for logging a financial expense or income transaction.
 */
@AppFunctionSerializable
data class LogExpenseParams(
    val amount: Double,
    val description: String,
    val category: String? = null,
    val accountType: String? = "daily",
    val isExpense: Boolean = true
)

/**
 * Result model returned to the calling AI agent following a transaction log.
 */
@AppFunctionSerializable
data class ExpenseResult(
    val success: Boolean,
    val transactionId: String,
    val formattedSummary: String
)

/**
 * Parameter model for adding a checklist task item.
 */
@AppFunctionSerializable
data class AddTaskParams(
    val title: String,
    val targetNoteTitle: String? = null
)

/**
 * Result model returned to the calling AI agent following checklist task insertion.
 */
@AppFunctionSerializable
data class TaskResult(
    val success: Boolean,
    val taskTitle: String,
    val targetNote: String
)

/**
 * Parameter model for creating a new rich-text note.
 */
@AppFunctionSerializable
data class CreateNoteParams(
    val title: String,
    val content: String,
    val folder: String? = null
)

/**
 * Result model returned to the calling AI agent following note creation.
 */
@AppFunctionSerializable
data class NoteResult(
    val success: Boolean,
    val noteId: String,
    val title: String
)

/**
 * Parameter model for querying cash flow and balance statistics.
 */
@AppFunctionSerializable
data class GetCashFlowSummaryParams(
    val period: String? = "month"
)

/**
 * Result model returned to the calling AI agent following cash flow analysis.
 */
@AppFunctionSerializable
data class CashFlowSummaryResult(
    val success: Boolean,
    val summaryText: String,
    val netBalance: Double,
    val currencySymbol: String
)

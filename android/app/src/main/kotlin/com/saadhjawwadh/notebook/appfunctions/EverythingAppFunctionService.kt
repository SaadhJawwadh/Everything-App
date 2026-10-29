package com.saadhjawwadh.notebook.appfunctions

import android.os.Build
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint

/**
 * Android 16+ AppFunctions Service providing on-device MCP tool execution for Google Gemini
 * and Android system AI agents.
 */
@RequiresApi(Build.VERSION_CODES.VANILLA_ICE_CREAM)
@AppFunctionServiceEntryPoint(
    serviceName = "GeneratedEverythingAppFunctionService",
    appFunctionXmlFileName = "everything_app_function_service"
)
abstract class BaseEverythingAppFunctionService : AppFunctionService() {

    /**
     * Records a financial expense or income transaction into Everything App's offline ledger.
     *
     * @param params Details of the transaction including amount, description, optional category, and target account.
     * @return Result containing success state, unique transaction ID, and user-facing voice confirmation summary.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun logExpense(params: LogExpenseParams): ExpenseResult {
        return AppFunctionBridge.logExpense(applicationContext, params)
    }

    /**
     * Adds an actionable task item to a checklist or to-do note in Everything App.
     *
     * @param params Details of the task including title and optional target checklist note title.
     * @return Result containing confirmation of the task title and target checklist note.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun addTask(params: AddTaskParams): TaskResult {
        return AppFunctionBridge.addTask(applicationContext, params)
    }

    /**
     * Creates a new rich-text markdown note in Everything App.
     *
     * @param params Note details including title, content text, and optional folder name.
     * @return Result containing unique note ID and confirmed title.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun createNote(params: CreateNoteParams): NoteResult {
        return AppFunctionBridge.createNote(applicationContext, params)
    }

    /**
     * Queries the user's current net cash flow balance, monthly spending, and income totals in Everything App.
     *
     * @param params Query scope filter (e.g., "month", "today", or "all").
     * @return Result containing calculated balance, currency symbol, and spoken natural-language summary.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun getCashFlowSummary(params: GetCashFlowSummaryParams): CashFlowSummaryResult {
        return AppFunctionBridge.getCashFlowSummary(applicationContext, params)
    }
}

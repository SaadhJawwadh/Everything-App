package com.saadhjawwadh.notebook

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Isolated native SharedPreferences store (`widget_cache`) for home screen widgets.
 *
 * Keeps sensitive financial metrics, checklist snapshots, and widget configuration out of
 * `FlutterSharedPreferences` and uses synchronous `.commit()` across engines and isolates.
 */
object WidgetCacheStore {
    const val PREFS_NAME = "widget_cache"
    const val LEGACY_FLUTTER_PREFS = "FlutterSharedPreferences"

    const val KEY_FINANCE_SNAPSHOT = "finance_snapshot_json"
    const val KEY_TODO_NOTES = "todo_notes_json"
    const val KEY_PENDING_TOGGLES = "pending_toggles_json"
    const val KEY_PENDING_QUICK_ADDS = "pending_quick_adds_json"
    const val SYNTHETIC_NEW_TASKS_NOTE_ID = "__pending_new_tasks__"
    const val KEY_ACTIVE_NOTE_ID = "active_note_id"
    const val KEY_ACTIVE_NOTE_TITLE = "active_note_title"
    const val PREFIX_ACTIVE_NOTE_ID = "active_note_id_"
    const val PREFIX_ACTIVE_NOTE_TITLE = "active_note_title_"

    const val KEY_SHOW_FINANCIAL_MANAGER = "show_financial_manager"
    const val KEY_APP_LOCK_ENABLED = "app_lock_enabled"
    const val KEY_LOCK_FINANCES = "lock_finances"
    const val KEY_HIDE_WIDGET_DATA_WHEN_LOCKED = "hide_widget_data_when_locked"
    const val KEY_SCREENSHOT_SHIELD_ENABLED = "screenshot_shield_enabled"
    const val KEY_USE_DYNAMIC_COLOR = "use_dynamic_color"

    const val STAGING_FINANCE_KEY = "flutter.widget_bg_staging_finance"
    const val STAGING_TODO_KEY = "flutter.widget_bg_staging_todo"

    private val LEGACY_EXACT_KEYS = setOf(
        "flutter.widget_income_month",
        "flutter.widget_category_breakdown",
        "flutter.widget_sparkline_data",
        "flutter.widget_recent_transactions",
        "flutter.widget_todo_notes_json",
        "flutter.widget_finance_json",
        "flutter.widget_is_trending_up"
    )

    private val LEGACY_PREFIXES = listOf(
        "flutter.widget_spent_",
        "flutter.widget_net_",
        "flutter.widget_budget_",
        "flutter.widget_top_category",
        "flutter.widget_forecast_"
    )

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun flutterPrefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(LEGACY_FLUTTER_PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun getFinanceSnapshotJson(context: Context): String =
        prefs(context).getString(KEY_FINANCE_SNAPSHOT, "{}") ?: "{}"

    @Synchronized
    fun setFinanceSnapshotJson(context: Context, json: String): Boolean =
        prefs(context).edit().putString(KEY_FINANCE_SNAPSHOT, json).commit()

    @Synchronized
    fun getTodoNotesJson(context: Context): String =
        prefs(context).getString(KEY_TODO_NOTES, "[]") ?: "[]"

    @Synchronized
    fun setTodoNotesJson(context: Context, json: String): Boolean =
        prefs(context).edit().putString(KEY_TODO_NOTES, json).commit()

    @Synchronized
    fun getPendingTogglesJson(context: Context): String =
        prefs(context).getString(KEY_PENDING_TOGGLES, "[]") ?: "[]"

    @Synchronized
    fun setPendingTogglesJson(context: Context, json: String): Boolean =
        prefs(context).edit().putString(KEY_PENDING_TOGGLES, json).commit()

    @Synchronized
    fun getPendingQuickAddsJson(context: Context): String =
        prefs(context).getString(KEY_PENDING_QUICK_ADDS, "[]") ?: "[]"

    @Synchronized
    fun setPendingQuickAddsJson(context: Context, json: String): Boolean =
        prefs(context).edit().putString(KEY_PENDING_QUICK_ADDS, json).commit()

    @Synchronized
    fun getActiveNoteId(context: Context, appWidgetId: Int): String {
        val store = prefs(context)
        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
            store.contains("$PREFIX_ACTIVE_NOTE_ID$appWidgetId")
        ) {
            return store.getString("$PREFIX_ACTIVE_NOTE_ID$appWidgetId", "ALL_NOTES") ?: "ALL_NOTES"
        }
        return store.getString(KEY_ACTIVE_NOTE_ID, "ALL_NOTES") ?: "ALL_NOTES"
    }

    @Synchronized
    fun getActiveNoteTitle(context: Context, appWidgetId: Int): String {
        val store = prefs(context)
        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID &&
            store.contains("$PREFIX_ACTIVE_NOTE_TITLE$appWidgetId")
        ) {
            return store.getString("$PREFIX_ACTIVE_NOTE_TITLE$appWidgetId", "") ?: ""
        }
        return store.getString(KEY_ACTIVE_NOTE_TITLE, "") ?: ""
    }

    @Synchronized
    fun setActiveNoteForWidget(
        context: Context,
        appWidgetId: Int,
        noteId: String,
        title: String
    ): Boolean {
        val editor = prefs(context).edit()
        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            editor.putString("$PREFIX_ACTIVE_NOTE_ID$appWidgetId", noteId)
            editor.putString("$PREFIX_ACTIVE_NOTE_TITLE$appWidgetId", title)
        } else {
            editor.putString(KEY_ACTIVE_NOTE_ID, noteId)
            editor.putString(KEY_ACTIVE_NOTE_TITLE, title)
        }
        return editor.commit()
    }

    @Synchronized
    fun setGlobalActiveNote(context: Context, noteId: String, title: String): Boolean =
        prefs(context).edit()
            .putString(KEY_ACTIVE_NOTE_ID, noteId)
            .putString(KEY_ACTIVE_NOTE_TITLE, title)
            .commit()

    @Synchronized
    fun removeWidgetActiveNotes(context: Context, appWidgetIds: IntArray): Boolean {
        val editor = prefs(context).edit()
        for (appWidgetId in appWidgetIds) {
            editor.remove("$PREFIX_ACTIVE_NOTE_ID$appWidgetId")
            editor.remove("$PREFIX_ACTIVE_NOTE_TITLE$appWidgetId")
        }
        return editor.commit()
    }

    @Synchronized
    fun migrateWidgetId(context: Context, oldId: Int, newId: Int): Boolean {
        if (oldId == newId ||
            oldId == AppWidgetManager.INVALID_APPWIDGET_ID ||
            newId == AppWidgetManager.INVALID_APPWIDGET_ID
        ) {
            return false
        }
        val store = prefs(context)
        val oldIdKey = "$PREFIX_ACTIVE_NOTE_ID$oldId"
        val oldTitleKey = "$PREFIX_ACTIVE_NOTE_TITLE$oldId"
        if (!store.contains(oldIdKey) && !store.contains(oldTitleKey)) {
            return false
        }
        val editor = store.edit()
        if (store.contains(oldIdKey)) {
            editor.putString(
                "$PREFIX_ACTIVE_NOTE_ID$newId",
                store.getString(oldIdKey, "ALL_NOTES") ?: "ALL_NOTES"
            )
            editor.remove(oldIdKey)
        }
        if (store.contains(oldTitleKey)) {
            editor.putString(
                "$PREFIX_ACTIVE_NOTE_TITLE$newId",
                store.getString(oldTitleKey, "") ?: ""
            )
            editor.remove(oldTitleKey)
        }
        return editor.commit()
    }

    @Synchronized
    fun getWidgetActiveNoteIds(context: Context): Map<String, String> {
        val store = prefs(context)
        val result = mutableMapOf<String, String>()
        val globalId = store.getString(KEY_ACTIVE_NOTE_ID, null)
        if (!globalId.isNullOrEmpty()) {
            result["global"] = globalId
        }
        for ((key, value) in store.all) {
            if (key.startsWith(PREFIX_ACTIVE_NOTE_ID) && value is String) {
                val widgetId = key.removePrefix(PREFIX_ACTIVE_NOTE_ID)
                if (widgetId.isNotEmpty()) {
                    result[widgetId] = value
                }
            }
        }
        return result
    }

    @Synchronized
    fun updateWidgetActiveNoteTitles(context: Context, updates: Map<*, *>): Boolean {
        val editor = prefs(context).edit()
        var modified = false
        for ((rawKey, rawVal) in updates) {
            val key = rawKey?.toString() ?: continue
            val isGlobal = key == "global" || key == KEY_ACTIVE_NOTE_ID
            val widgetId = when {
                isGlobal -> null
                key.startsWith(PREFIX_ACTIVE_NOTE_ID) -> key.removePrefix(PREFIX_ACTIVE_NOTE_ID)
                else -> key
            }

            val newId: String?
            val newTitle: String?
            when (rawVal) {
                is Map<*, *> -> {
                    newId = rawVal["id"]?.toString() ?: rawVal["noteId"]?.toString()
                    newTitle = rawVal["title"]?.toString()
                }
                is String -> {
                    newId = null
                    newTitle = rawVal
                }
                else -> {
                    newId = null
                    newTitle = null
                }
            }

            if (isGlobal) {
                if (newId != null) {
                    editor.putString(KEY_ACTIVE_NOTE_ID, newId)
                    modified = true
                }
                if (newTitle != null) {
                    editor.putString(KEY_ACTIVE_NOTE_TITLE, newTitle)
                    modified = true
                }
            } else if (!widgetId.isNullOrEmpty()) {
                if (newId != null) {
                    editor.putString("$PREFIX_ACTIVE_NOTE_ID$widgetId", newId)
                    modified = true
                }
                if (newTitle != null) {
                    editor.putString("$PREFIX_ACTIVE_NOTE_TITLE$widgetId", newTitle)
                    modified = true
                }
            }
        }
        return if (modified) editor.commit() else true
    }

    @Synchronized
    fun syncConfig(
        context: Context,
        showFinancialManager: Boolean? = null,
        appLockEnabled: Boolean,
        lockFinances: Boolean,
        hideWidgetDataWhenLocked: Boolean = false,
        screenshotShieldEnabled: Boolean,
        useDynamicColor: Boolean? = null
    ): Boolean {
        val editor = prefs(context).edit()
            .putBoolean(KEY_APP_LOCK_ENABLED, appLockEnabled)
            .putBoolean(KEY_LOCK_FINANCES, lockFinances)
            .putBoolean(KEY_HIDE_WIDGET_DATA_WHEN_LOCKED, hideWidgetDataWhenLocked)
            .putBoolean(KEY_SCREENSHOT_SHIELD_ENABLED, screenshotShieldEnabled)
        if (showFinancialManager != null) {
            editor.putBoolean(KEY_SHOW_FINANCIAL_MANAGER, showFinancialManager)
        }
        if (useDynamicColor != null) {
            editor.putBoolean(KEY_USE_DYNAMIC_COLOR, useDynamicColor)
        }
        return editor.commit()
    }

    // Home screen widgets always display live data (matching Google Keep / WhatsApp),
    // while in-app navigation remains protected by App Lock and per-module locks.
    fun isTodoLocked(context: Context): Boolean = false

    fun isFinanceLocked(context: Context): Boolean = false

    @Synchronized
    fun isFinancialManagerEnabled(context: Context): Boolean {
        val store = prefs(context)
        val fPrefs = flutterPrefs(context)
        if (fPrefs.contains("flutter.showFinancialManager")) {
            val flutterValue = fPrefs.getBoolean("flutter.showFinancialManager", false)
            if (!store.contains(KEY_SHOW_FINANCIAL_MANAGER) ||
                store.getBoolean(KEY_SHOW_FINANCIAL_MANAGER, false) != flutterValue
            ) {
                store.edit().putBoolean(KEY_SHOW_FINANCIAL_MANAGER, flutterValue).commit()
            }
            return flutterValue
        }
        return store.getBoolean(KEY_SHOW_FINANCIAL_MANAGER, false)
    }

    fun isAppLockEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_APP_LOCK_ENABLED, false)

    fun isScreenshotShieldEnabled(context: Context): Boolean {
        val store = prefs(context)
        return if (store.contains(KEY_SCREENSHOT_SHIELD_ENABLED)) {
            store.getBoolean(KEY_SCREENSHOT_SHIELD_ENABLED, false)
        } else {
            flutterPrefs(context).getBoolean("flutter.screenshotShieldEnabled", false)
        }
    }

    fun isUseDynamicColor(context: Context): Boolean {
        val store = prefs(context)
        return if (store.contains(KEY_USE_DYNAMIC_COLOR)) {
            store.getBoolean(KEY_USE_DYNAMIC_COLOR, true)
        } else {
            flutterPrefs(context).getBoolean("flutter.useDynamicColor", true)
        }
    }

    @Synchronized
    fun drainBackgroundStaging(context: Context): Boolean {
        val fPrefs = flutterPrefs(context)
        val cache = prefs(context)
        val cacheEditor = cache.edit()
        val fEditor = fPrefs.edit()

        var drainedStaging = false
        var cacheDirty = false
        var flutterDirty = false

        val stagedFinance = fPrefs.getString(STAGING_FINANCE_KEY, null)
        if (stagedFinance != null) {
            cacheEditor.putString(KEY_FINANCE_SNAPSHOT, stagedFinance)
            fEditor.remove(STAGING_FINANCE_KEY)
            drainedStaging = true
            cacheDirty = true
            flutterDirty = true
        }

        val stagedTodo = fPrefs.getString(STAGING_TODO_KEY, null)
        if (stagedTodo != null) {
            cacheEditor.putString(KEY_TODO_NOTES, stagedTodo)
            fEditor.remove(STAGING_TODO_KEY)
            drainedStaging = true
            cacheDirty = true
            flutterDirty = true
        }

        if (fPrefs.contains("flutter.showFinancialManager")) {
            val flutterValue = fPrefs.getBoolean("flutter.showFinancialManager", false)
            if (!cache.contains(KEY_SHOW_FINANCIAL_MANAGER) ||
                cache.getBoolean(KEY_SHOW_FINANCIAL_MANAGER, false) != flutterValue
            ) {
                cacheEditor.putBoolean(KEY_SHOW_FINANCIAL_MANAGER, flutterValue)
                cacheDirty = true
            }
        }

        // Migrate any pre-upgrade active note mappings or pending toggles into isolated store
        for ((key, value) in fPrefs.all) {
            when {
                key == "flutter.widget_active_note_id" && value is String -> {
                    if (!cache.contains(KEY_ACTIVE_NOTE_ID)) {
                        cacheEditor.putString(KEY_ACTIVE_NOTE_ID, value)
                        cacheDirty = true
                    }
                    fEditor.remove(key)
                    flutterDirty = true
                }
                key == "flutter.widget_active_note_title" && value is String -> {
                    if (!cache.contains(KEY_ACTIVE_NOTE_TITLE)) {
                        cacheEditor.putString(KEY_ACTIVE_NOTE_TITLE, value)
                        cacheDirty = true
                    }
                    fEditor.remove(key)
                    flutterDirty = true
                }
                key.startsWith("flutter.widget_active_note_id_") && value is String -> {
                    val idSuffix = key.removePrefix("flutter.widget_active_note_id_")
                    val targetKey = "$PREFIX_ACTIVE_NOTE_ID$idSuffix"
                    if (!cache.contains(targetKey)) {
                        cacheEditor.putString(targetKey, value)
                        cacheDirty = true
                    }
                    fEditor.remove(key)
                    flutterDirty = true
                }
                key.startsWith("flutter.widget_active_note_title_") && value is String -> {
                    val idSuffix = key.removePrefix("flutter.widget_active_note_title_")
                    val targetKey = "$PREFIX_ACTIVE_NOTE_TITLE$idSuffix"
                    if (!cache.contains(targetKey)) {
                        cacheEditor.putString(targetKey, value)
                        cacheDirty = true
                    }
                    fEditor.remove(key)
                    flutterDirty = true
                }
                key == "flutter.widget_pending_toggles" && value is String -> {
                    if (!cache.contains(KEY_PENDING_TOGGLES) && value != "[]") {
                        cacheEditor.putString(KEY_PENDING_TOGGLES, value)
                        cacheDirty = true
                    }
                    fEditor.remove(key)
                    flutterDirty = true
                }
                key in LEGACY_EXACT_KEYS || LEGACY_PREFIXES.any { key.startsWith(it) } -> {
                    fEditor.remove(key)
                    flutterDirty = true
                }
            }
        }

        if (cacheDirty) {
            cacheEditor.commit()
        }
        if (flutterDirty) {
            fEditor.commit()
        }
        return drainedStaging
    }

    @Synchronized
    fun toggleTodoItemOptimistically(
        context: Context,
        noteId: String,
        lineIndex: Int,
        text: String,
        fallbackIsDone: Boolean
    ): Boolean {
        var newIsDone = !fallbackIsDone

        val notesJsonStr = getTodoNotesJson(context)
        try {
            val notesArr = JSONArray(notesJsonStr)
            var found = false
            for (i in 0 until notesArr.length()) {
                val noteObj = notesArr.getJSONObject(i)
                if (noteObj.optString("id") == noteId) {
                    val itemsArr = noteObj.optJSONArray("items") ?: continue
                    var matchedIdx = -1

                    // Pass 1: Match by lineIndex >= 0 first
                    if (lineIndex >= 0) {
                        for (j in 0 until itemsArr.length()) {
                            val itemObj = itemsArr.getJSONObject(j)
                            if (itemObj.optInt("lineIndex", -1) == lineIndex) {
                                matchedIdx = j
                                break
                            }
                        }
                    }

                    // Pass 2: Fallback to text match
                    if (matchedIdx < 0 && text.isNotEmpty()) {
                        for (j in 0 until itemsArr.length()) {
                            val itemObj = itemsArr.getJSONObject(j)
                            if (itemObj.optString("text", "").trim() == text.trim()) {
                                matchedIdx = j
                                break
                            }
                        }
                    }

                    if (matchedIdx >= 0) {
                        val itemObj = itemsArr.getJSONObject(matchedIdx)
                        val currentLiveDone = itemObj.optBoolean("isDone", fallbackIsDone)
                        newIsDone = !currentLiveDone
                        itemObj.put("isDone", newIsDone)

                        if (noteObj.has("checkedCount") && noteObj.has("totalCount")) {
                            val delta = if (newIsDone) 1 else -1
                            val total = noteObj.optInt("totalCount", itemsArr.length())
                            val checked = (noteObj.optInt("checkedCount", 0) + delta).coerceIn(0, total)
                            noteObj.put("checkedCount", checked)
                            noteObj.put("pendingCount", (total - checked).coerceAtLeast(0))
                        }
                        found = true
                    }
                    break
                }
            }
            if (found) {
                setTodoNotesJson(context, notesArr.toString())
            }
        } catch (_: Exception) {}

        val pendingJsonStr = getPendingTogglesJson(context)
        try {
            val pendingArr = JSONArray(pendingJsonStr)
            var foundExisting = false
            for (i in 0 until pendingArr.length()) {
                val existingObj = pendingArr.getJSONObject(i)
                val existingNoteId = existingObj.optString("noteId")
                val existingLineIdx = existingObj.optInt("lineIndex", -1)
                val existingText = existingObj.optString("text", "")

                val isSameItem = existingNoteId == noteId && if (lineIndex >= 0 && existingLineIdx >= 0) {
                    existingLineIdx == lineIndex
                } else {
                    text.isNotEmpty() && existingText.trim() == text.trim()
                }

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
            setPendingTogglesJson(context, pendingArr.toString())
        } catch (_: Exception) {}

        return newIsDone
    }

    @Synchronized
    fun addTodoItemOptimistically(
        context: Context,
        requestedNoteId: String,
        taskText: String
    ): String {
        val cleaned = taskText.trim()
        if (cleaned.isEmpty()) return ""

        var resolvedNoteId = ""
        try {
            val notesArr = JSONArray(getTodoNotesJson(context))
            var targetIdx = -1

            if (requestedNoteId.isNotBlank() && requestedNoteId != "ALL_NOTES") {
                for (i in 0 until notesArr.length()) {
                    if (notesArr.getJSONObject(i).optString("id") == requestedNoteId) {
                        targetIdx = i
                        break
                    }
                }
            }

            if (targetIdx < 0) {
                val defaultTitles = setOf("my tasks", "quick tasks", "todo", "tasks")
                for (i in 0 until notesArr.length()) {
                    val titleLower = notesArr.getJSONObject(i).optString("title", "").trim().lowercase()
                    if (titleLower in defaultTitles) {
                        targetIdx = i
                        break
                    }
                }
            }

            if (targetIdx < 0 && notesArr.length() > 0) {
                targetIdx = 0
            }

            val noteObj = if (targetIdx >= 0) {
                notesArr.getJSONObject(targetIdx)
            } else {
                JSONObject().apply {
                    put("id", SYNTHETIC_NEW_TASKS_NOTE_ID)
                    put("title", "My Tasks")
                    put("pendingCount", 0)
                    put("checkedCount", 0)
                    put("totalCount", 0)
                    put("items", JSONArray())
                }.also { notesArr.put(it) }
            }

            resolvedNoteId = noteObj.optString("id", SYNTHETIC_NEW_TASKS_NOTE_ID)
            val itemsArr = noteObj.optJSONArray("items") ?: JSONArray().also {
                noteObj.put("items", it)
            }

            val newItemObj = JSONObject().apply {
                put("lineIndex", -1)
                put("text", cleaned)
                put("isDone", false)
            }
            itemsArr.put(newItemObj)

            val prevTotal = if (noteObj.has("totalCount")) {
                noteObj.optInt("totalCount", itemsArr.length() - 1)
            } else {
                itemsArr.length() - 1
            }
            val prevPending = if (noteObj.has("pendingCount")) {
                noteObj.optInt("pendingCount", itemsArr.length() - 1)
            } else {
                itemsArr.length() - 1
            }
            noteObj.put("totalCount", prevTotal + 1)
            noteObj.put("pendingCount", prevPending + 1)

            setTodoNotesJson(context, notesArr.toString())
        } catch (_: Exception) {
            if (resolvedNoteId.isEmpty()) {
                resolvedNoteId = if (requestedNoteId.isNotBlank() && requestedNoteId != "ALL_NOTES") {
                    requestedNoteId
                } else {
                    SYNTHETIC_NEW_TASKS_NOTE_ID
                }
            }
        }

        try {
            val pendingArr = JSONArray(getPendingQuickAddsJson(context))
            val quickAddObj = JSONObject().apply {
                put("id", java.util.UUID.randomUUID().toString())
                put("noteId", resolvedNoteId)
                put("text", cleaned)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArr.put(quickAddObj)
            setPendingQuickAddsJson(context, pendingArr.toString())
        } catch (_: Exception) {}

        return resolvedNoteId
    }

    @Synchronized
    fun getSnapshotMap(context: Context): Map<String, Any?> {
        val store = prefs(context)
        return mapOf(
            KEY_FINANCE_SNAPSHOT to getFinanceSnapshotJson(context),
            KEY_TODO_NOTES to getTodoNotesJson(context),
            KEY_PENDING_TOGGLES to getPendingTogglesJson(context),
            KEY_PENDING_QUICK_ADDS to getPendingQuickAddsJson(context),
            KEY_ACTIVE_NOTE_ID to (store.getString(KEY_ACTIVE_NOTE_ID, "ALL_NOTES") ?: "ALL_NOTES"),
            KEY_ACTIVE_NOTE_TITLE to (store.getString(KEY_ACTIVE_NOTE_TITLE, "") ?: ""),
            KEY_SHOW_FINANCIAL_MANAGER to isFinancialManagerEnabled(context),
            KEY_APP_LOCK_ENABLED to store.getBoolean(KEY_APP_LOCK_ENABLED, false),
            KEY_LOCK_FINANCES to store.getBoolean(KEY_LOCK_FINANCES, false),
            KEY_HIDE_WIDGET_DATA_WHEN_LOCKED to store.getBoolean(KEY_HIDE_WIDGET_DATA_WHEN_LOCKED, false),
            KEY_SCREENSHOT_SHIELD_ENABLED to store.getBoolean(KEY_SCREENSHOT_SHIELD_ENABLED, false),
            "active_widget_ids" to getWidgetActiveNoteIds(context)
        )
    }
}

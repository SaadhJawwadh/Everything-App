package com.saadhjawwadh.notebook

import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.app.KeyguardManager
import android.os.PowerManager
import android.os.Build
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.os.Bundle
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.ContentValues
import android.provider.MediaStore
import android.content.ClipboardManager
import android.content.ClipData
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.saadhjawwadh.notebook/device_lock"
    private val WIDGET_CHANNEL = "com.saadhjawwadh.notebook/widget"
    private var screenOffLock = false
    private var receiver: BroadcastReceiver? = null
    private var pendingWidgetAction: String? = null
    private var pendingSharedText: String? = null

    companion object {
        private var instance: MainActivity? = null
        private var widgetChannel: MethodChannel? = null

        fun notifyWidgetToggle() {
            instance?.runOnUiThread {
                widgetChannel?.invokeMethod("onWidgetToggle", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        instance = this
        handleIntent(intent)
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                screenOffLock = true
            }
        }
        registerReceiver(receiver, filter)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        if (pendingWidgetAction != null) {
            runOnUiThread {
                widgetChannel?.invokeMethod("onPendingAction", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        screenOffLock = false
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        val context = this
        val appWidgetManager = AppWidgetManager.getInstance(context)

        val financeIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, FinanceWidgetProvider::class.java)
        )
        if (financeIds.isNotEmpty()) {
            val financeIntent = Intent(context, FinanceWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, financeIds)
            }
            context.sendBroadcast(financeIntent)
        }

        val notesIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, NotesWidgetProvider::class.java)
        )
        if (notesIds.isNotEmpty()) {
            val notesIntent = Intent(context, NotesWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, notesIds)
            }
            context.sendBroadcast(notesIntent)
        }

        TodoWidgetProvider.updateAllWidgets(context)
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            "com.saadhjawwadh.notebook.ADD_TRANSACTION" -> pendingWidgetAction = "add_transaction"
            "com.saadhjawwadh.notebook.VIEW_LEDGER" -> pendingWidgetAction = "view_ledger"
            "com.saadhjawwadh.notebook.VIEW_BUDGETS" -> pendingWidgetAction = "view_budgets"
            "com.saadhjawwadh.notebook.VIEW_TRENDS" -> pendingWidgetAction = "view_trends"
            "com.saadhjawwadh.notebook.NEW_NOTE" -> pendingWidgetAction = "new_note"
            "com.saadhjawwadh.notebook.SEARCH" -> pendingWidgetAction = "search"
            "com.saadhjawwadh.notebook.SCAN_RECEIPT" -> pendingWidgetAction = "scan_receipt"
            "com.saadhjawwadh.notebook.SYNC_DEVICES" -> pendingWidgetAction = "sync_devices"
            "com.saadhjawwadh.notebook.QUICK_ADD_TODO" -> {
                val activeNoteId = intent.getStringExtra("active_note_id") ?: "ALL_NOTES"
                pendingWidgetAction = "quick_add_todo:$activeNoteId"
            }
            "com.saadhjawwadh.notebook.ACTION_OPEN_NOTE" -> {
                val openNoteId = intent.getStringExtra("open_note_id") ?: ""
                val lineIndex = intent.getIntExtra("line_index", -1)
                pendingWidgetAction = "open_note:$openNoteId:$lineIndex"
            }
            "com.saadhjawwadh.notebook.PIN_TODO_WIDGET" -> {
                requestPinTodoWidget()
            }
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                if (!text.isNullOrEmpty()) {
                    pendingSharedText = text
                    pendingWidgetAction = "process_text"
                }
            }
        }
        if (intent?.getBooleanExtra("pin_todo_widget", false) == true) {
            requestPinTodoWidget()
        }
    }

    private fun requestPinTodoWidget(): Boolean {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O &&
            appWidgetManager.isRequestPinAppWidgetSupported
        ) {
            val component = ComponentName(this, TodoWidgetProvider::class.java)
            appWidgetManager.requestPinAppWidget(component, null, null)
        } else {
            false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
            widgetChannel = null
        }
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDeviceLocked") {
                val isLocked = checkIsDeviceLocked() || screenOffLock
                result.success(isLocked)
            } else if (call.method == "resetLockFlag") {
                screenOffLock = false
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val context = this@MainActivity
                    val appWidgetManager = AppWidgetManager.getInstance(context)

                    val financeIds = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, FinanceWidgetProvider::class.java)
                    )
                    if (financeIds.isNotEmpty()) {
                        val financeIntent = Intent(context, FinanceWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, financeIds)
                        }
                        context.sendBroadcast(financeIntent)
                    }

                    val notesIds = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, NotesWidgetProvider::class.java)
                    )
                    if (notesIds.isNotEmpty()) {
                        val notesIntent = Intent(context, NotesWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, notesIds)
                        }
                        context.sendBroadcast(notesIntent)
                    }

                    // Update Todo & Checklist Widget
                    TodoWidgetProvider.updateAllWidgets(context)

                    result.success(true)
                }
                "pinTodoWidget" -> {
                    result.success(requestPinTodoWidget())
                }
                "getPendingAction" -> {
                    result.success(pendingWidgetAction)
                    pendingWidgetAction = null
                }
                "getPendingSharedText" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.saadhjawwadh.notebook/story_media").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "story_${System.currentTimeMillis()}.png"
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "Image bytes cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val resolver = contentResolver
                        val contentValues = ContentValues().apply {
                            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/EverythingApp")
                                put(MediaStore.Images.Media.IS_PENDING, 1)
                            }
                        }
                        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                        if (uri != null) {
                            resolver.openOutputStream(uri)?.use { os ->
                                os.write(bytes)
                                os.flush()
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                contentValues.clear()
                                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                                resolver.update(uri, contentValues, null, null)
                            }
                            result.success(mapOf(
                                "success" to true,
                                "uri" to uri.toString(),
                                "path" to "Pictures/EverythingApp/$filename"
                            ))
                        } else {
                            result.error("SAVE_FAILED", "Failed to create MediaStore entry", null)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage, null)
                    }
                }
                "copyImageToClipboard" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "story_clip_${System.currentTimeMillis()}.png"
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "Image bytes cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val cardDir = File(cacheDir, "story_cards")
                        if (!cardDir.exists()) cardDir.mkdirs()
                        val file = File(cardDir, filename)
                        FileOutputStream(file).use { fos ->
                            fos.write(bytes)
                            fos.flush()
                        }
                        val uri = FileProvider.getUriForFile(
                            this@MainActivity,
                            "${applicationContext.packageName}.story_provider",
                            file
                        )
                        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newUri(contentResolver, "Story Card", uri)
                        grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        clipboard.setPrimaryClip(clip)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("COPY_FAILED", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkIsDeviceLocked(): Boolean {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        
        val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            powerManager.isInteractive
        } else {
            @Suppress("DEPRECATION")
            powerManager.isScreenOn
        }
 
        if (!isInteractive) {
            return true
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            keyguardManager.isDeviceLocked
        } else {
            keyguardManager.isKeyguardLocked
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        try {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        } catch (e: IllegalStateException) {
            // Guard against third-party plugins attempting multiple replies on MethodChannel Result
        } catch (e: Exception) {
            // Prevent uncaught native exceptions during permission result handling
        }
    }
}

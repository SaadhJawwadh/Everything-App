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
import android.net.wifi.WifiManager

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.saadhjawwadh.notebook/device_lock"
    private val WIDGET_CHANNEL = "com.saadhjawwadh.notebook/widget"
    private var screenOffLock = false
    // Set when the screen turns off; unlike [screenOffLock] it is NOT cleared in
    // onResume, so Dart can read it once after resuming and lock immediately.
    @Volatile private var screenOffSinceBackground = false
    private var receiver: BroadcastReceiver? = null
    private var pendingWidgetAction: String? = null
    private var pendingSharedText: String? = null
    private var pendingIntentExtras: Map<String, Any?>? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var hasPublishedWidgetPreviews = false
    private var liteRtHandler: LiteRtChannelHandler? = null

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
                screenOffSinceBackground = true
            }
        }
        registerReceiver(receiver, filter)
        acquireMulticastLock()
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
        acquireMulticastLock()
    }

    override fun onPause() {
        super.onPause()
        releaseMulticastLock()
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        hasPublishedWidgetPreviews = false
        val context = applicationContext
        FinanceWidgetProvider.updateAllWidgets(context)
        NotesWidgetProvider.updateAllWidgets(context)
        TodoWidgetProvider.updateAllWidgets(context)
        UnifiedWidgetProvider.updateAllWidgets(context)
    }

    private fun handleIntent(intent: Intent?) {
        val extrasMap = mutableMapOf<String, Any?>()
        intent?.extras?.let { bundle ->
            for (key in listOf(
                "amount",
                "description",
                "category",
                "is_expense",
                "account_type",
                "todo_text",
                "title",
                "content",
                "folder",
                "query"
            )) {
                if (bundle.containsKey(key)) {
                    extrasMap[key] = bundle.get(key)?.toString()
                }
            }
        }
        if (extrasMap.isNotEmpty()) {
            pendingIntentExtras = extrasMap
        }

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
                val text = intent.getStringExtra("text") ?: ""
                pendingWidgetAction = "open_note:$openNoteId:$lineIndex:$text"
            }
            "com.saadhjawwadh.notebook.PIN_TODO_WIDGET" -> {
                requestPinAppWidget("todo")
            }
            "com.saadhjawwadh.notebook.PIN_WIDGET" -> {
                val type = intent.getStringExtra("widget_type") ?: "todo"
                requestPinAppWidget(type)
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
            requestPinAppWidget("todo")
        }
    }

    private fun publishGeneratedWidgetPreviews(context: Context) {
        if (Build.VERSION.SDK_INT < 35 || hasPublishedWidgetPreviews) return
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val category = android.appwidget.AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN
            val mappings = listOf(
                ComponentName(context, FinanceWidgetProvider::class.java) to R.layout.finance_widget_layout,
                ComponentName(context, NotesWidgetProvider::class.java) to R.layout.notes_widget_layout,
                ComponentName(context, TodoWidgetProvider::class.java) to R.layout.todo_widget_layout,
                ComponentName(context, UnifiedWidgetProvider::class.java) to R.layout.unified_widget_layout
            )
            for ((component, layoutRes) in mappings) {
                val remoteViews = android.widget.RemoteViews(context.packageName, layoutRes)
                appWidgetManager.setWidgetPreview(component, category, remoteViews)
            }
            hasPublishedWidgetPreviews = true
        } catch (_: Exception) {
            // Gracefully ignore on OEM launchers that do not support generated previews
        }
    }

    private fun requestPinAppWidget(widgetType: String = "todo"): Boolean {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            !appWidgetManager.isRequestPinAppWidgetSupported
        ) {
            return false
        }

        val component = when (widgetType.lowercase()) {
            "finance" -> ComponentName(this, FinanceWidgetProvider::class.java)
            "unified" -> ComponentName(this, UnifiedWidgetProvider::class.java)
            "notes" -> ComponentName(this, NotesWidgetProvider::class.java)
            else -> ComponentName(this, TodoWidgetProvider::class.java)
        }

        val extras = Bundle()
        // Android 15 (API 35) setWidgetPreview support via EXTRA_APPWIDGET_PREVIEW
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                val layoutRes = when (widgetType.lowercase()) {
                    "finance" -> R.layout.finance_widget_layout
                    "unified" -> R.layout.unified_widget_layout
                    "notes" -> R.layout.notes_widget_layout
                    else -> R.layout.todo_widget_layout
                }
                val previewViews = android.widget.RemoteViews(packageName, layoutRes)
                extras.putParcelable("appWidgetPreview", previewViews)
            } catch (_: Exception) {}
        }

        return try {
            appWidgetManager.requestPinAppWidget(component, if (extras.isEmpty) null else extras, null)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "requestPinAppWidget failed: $e")
            false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        liteRtHandler?.dispose()
        liteRtHandler = null
        releaseMulticastLock()
        multicastLock = null
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

    private fun acquireMulticastLock() {
        try {
            if (multicastLock == null) {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                multicastLock = wifiManager?.createMulticastLock("everything_p2p_multicast_lock")?.apply {
                    setReferenceCounted(true)
                }
            }
            if (multicastLock?.isHeld != true) {
                multicastLock?.acquire()
            }
        } catch (e: Exception) {
            // Ignore if Wi-Fi service is unavailable on some platforms
        }
    }

    private fun releaseMulticastLock() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liteRtHandler = LiteRtChannelHandler(applicationContext).also {
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDeviceLocked") {
                val isLocked = checkIsDeviceLocked() || screenOffLock
                result.success(isLocked)
            } else if (call.method == "resetLockFlag") {
                screenOffLock = false
                result.success(true)
            } else if (call.method == "consumeScreenOff") {
                // Returns whether the screen was turned off since the last call, then clears it.
                val wasOff = screenOffSinceBackground
                screenOffSinceBackground = false
                result.success(wasOff)
            } else if (call.method == "setSecureRecents") {
                // Hide app content from the Recents thumbnail while app lock is on (API 33+).
                // FLAG_SECURE is deliberately avoided so screenshots keep working.
                val hide = call.argument<Boolean>("hide") ?: false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    setRecentsScreenshotEnabled(!hide)
                }
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
                    val context = applicationContext
                    FinanceWidgetProvider.updateAllWidgets(context)
                    NotesWidgetProvider.updateAllWidgets(context)
                    TodoWidgetProvider.updateAllWidgets(context)
                    UnifiedWidgetProvider.updateAllWidgets(context)
                    publishGeneratedWidgetPreviews(context)
                    result.success(true)
                }
                "pinWidget", "requestPinAppWidget" -> {
                    val type = call.argument<String>("type") ?: "todo"
                    result.success(requestPinAppWidget(type))
                }
                "pinTodoWidget" -> {
                    result.success(requestPinAppWidget("todo"))
                }
                "peekPendingAction" -> {
                    result.success(pendingWidgetAction)
                }
                "getPendingAction" -> {
                    result.success(pendingWidgetAction)
                    pendingWidgetAction = null
                }
                "getPendingIntentExtras" -> {
                    result.success(pendingIntentExtras)
                    pendingIntentExtras = null
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

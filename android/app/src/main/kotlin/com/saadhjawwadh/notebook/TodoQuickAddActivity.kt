package com.saadhjawwadh.notebook

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import org.json.JSONArray

class TodoQuickAddActivity : Activity() {

    private var isDismissing = false
    private var activeNoteId: String = "ALL_NOTES"
    private lateinit var inputView: EditText
    private lateinit var statusView: TextView
    private lateinit var saveButton: View
    private lateinit var anotherButton: View

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        if (intent != null) {
            setIntent(intent)
            bindForIntent(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            overridePendingTransition(0, 0)
        }

        if (WidgetCacheStore.isScreenshotShieldEnabled(this)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        setContentView(R.layout.activity_todo_quick_add)

        val scrim = findViewById<View>(R.id.quick_add_scrim)
        val card = findViewById<View>(R.id.quick_add_card)
        inputView = findViewById(R.id.quick_add_input)
        statusView = findViewById(R.id.quick_add_status)
        saveButton = findViewById(R.id.quick_add_btn_save)
        anotherButton = findViewById(R.id.quick_add_btn_another)

        if (scrim != null) {
            ViewCompat.setOnApplyWindowInsetsListener(scrim) { view, windowInsets ->
                val insets = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() or
                        WindowInsetsCompat.Type.displayCutout() or
                        WindowInsetsCompat.Type.ime()
                )
                view.setPadding(insets.left, insets.top, insets.right, insets.bottom)
                WindowInsetsCompat.CONSUMED
            }
        }

        if (scrim != null && card != null) {
            scrim.alpha = 0f
            card.alpha = 0f
            card.scaleX = 0.95f
            card.scaleY = 0.95f
            scrim.animate()
                .alpha(1f)
                .setDuration(180L)
                .setInterpolator(DecelerateInterpolator())
                .start()
            card.animate()
                .alpha(1f)
                .scaleX(1f)
                .scaleY(1f)
                .setDuration(180L)
                .setInterpolator(DecelerateInterpolator())
                .start()
        }

        scrim?.setOnClickListener {
            hideIme()
            dismissWithAnimation()
        }
        findViewById<View>(R.id.quick_add_btn_cancel)?.setOnClickListener {
            hideIme()
            dismissWithAnimation()
        }
        saveButton.setOnClickListener {
            submitTask(keepOpen = false)
        }
        anotherButton.setOnClickListener {
            submitTask(keepOpen = true)
        }

        updateActionStates(hasText = false)
        inputView.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                updateActionStates(!s.isNullOrBlank())
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        inputView.setOnEditorActionListener { _, actionId, event ->
            val isEnter = event != null &&
                event.keyCode == KeyEvent.KEYCODE_ENTER &&
                event.action == KeyEvent.ACTION_DOWN
            if (actionId == EditorInfo.IME_ACTION_DONE || isEnter) {
                submitTask(keepOpen = false)
                true
            } else {
                false
            }
        }

        bindForIntent(intent)
        showIme()
    }

    private fun bindForIntent(activeIntent: Intent) {
        val extraId = activeIntent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        val appWidgetId = if (extraId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            extraId
        } else {
            AppWidgetManager.INVALID_APPWIDGET_ID
        }

        val intentNoteId = activeIntent.getStringExtra("active_note_id")
        activeNoteId = if (!intentNoteId.isNullOrBlank()) {
            intentNoteId
        } else {
            WidgetCacheStore.getActiveNoteId(this, appWidgetId)
        }

        val intentTitle = activeIntent.getStringExtra("active_note_title")?.trim().orEmpty()
        val resolvedTitle = when {
            intentTitle.isNotEmpty() -> intentTitle
            activeNoteId.isNotBlank() && activeNoteId != "ALL_NOTES" -> {
                val fromWidget = WidgetCacheStore.getActiveNoteTitle(this, appWidgetId).trim()
                fromWidget.ifEmpty { lookupNoteTitle(activeNoteId) }
            }
            else -> getString(R.string.widget_all_action_items)
        }

        val titleView = findViewById<TextView>(R.id.quick_add_title)
        val subtitleView = findViewById<TextView>(R.id.quick_add_subtitle)
        titleView.text = resolvedTitle.ifEmpty { getString(R.string.widget_quick_add_title) }
        subtitleView.text = getString(R.string.widget_quick_add_title)
    }

    private fun lookupNoteTitle(noteId: String): String {
        try {
            val arr = JSONArray(WidgetCacheStore.getTodoNotesJson(this))
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") == noteId) {
                    val t = obj.optString("title", "").trim()
                    if (t.isNotEmpty()) return t
                }
            }
        } catch (_: Exception) {}
        return getString(R.string.widget_checklist_fallback)
    }

    private fun updateActionStates(hasText: Boolean) {
        saveButton.isEnabled = hasText
        saveButton.alpha = if (hasText) 1.0f else 0.45f
        anotherButton.isEnabled = hasText
        anotherButton.alpha = if (hasText) 1.0f else 0.45f
    }

    private fun submitTask(keepOpen: Boolean) {
        val text = inputView.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return

        inputView.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
        WidgetCacheStore.addTodoItemOptimistically(
            context = applicationContext,
            requestedNoteId = activeNoteId,
            taskText = text
        )

        TodoWidgetProvider.updateAllWidgets(applicationContext)
        UnifiedWidgetProvider.updateAllWidgets(applicationContext)
        MainActivity.notifyWidgetToggle()

        if (keepOpen) {
            inputView.setText("")
            statusView.text = getString(R.string.widget_quick_add_added_fmt, text)
            statusView.visibility = View.VISIBLE
            inputView.requestFocus()
        } else {
            hideIme()
            dismissWithAnimation()
        }
    }

    private fun showIme() {
        inputView.requestFocus()
        WindowInsetsControllerCompat(window, inputView).show(WindowInsetsCompat.Type.ime())
        inputView.post {
            if (!isFinishing && !isDestroyed) {
                val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                imm?.showSoftInput(inputView, InputMethodManager.SHOW_IMPLICIT)
            }
        }
    }

    private fun hideIme() {
        WindowInsetsControllerCompat(window, inputView).hide(WindowInsetsCompat.Type.ime())
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(inputView.windowToken, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        hideIme()
        dismissWithAnimation()
    }

    private fun dismissWithAnimation() {
        if (isDismissing) return
        isDismissing = true
        val scrim = findViewById<View>(R.id.quick_add_scrim)
        val card = findViewById<View>(R.id.quick_add_card)
        if (scrim == null || card == null) {
            finishNow()
            return
        }
        scrim.animate()
            .alpha(0f)
            .setDuration(120L)
            .setInterpolator(AccelerateInterpolator())
            .start()
        card.animate()
            .alpha(0f)
            .scaleX(0.96f)
            .scaleY(0.96f)
            .setDuration(120L)
            .setInterpolator(AccelerateInterpolator())
            .withEndAction { finishNow() }
            .start()
    }

    private fun finishNow() {
        finish()
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 34) {
            overridePendingTransition(0, 0)
        }
    }
}

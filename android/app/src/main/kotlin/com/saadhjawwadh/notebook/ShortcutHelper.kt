package com.saadhjawwadh.notebook

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

object ShortcutHelper {

    fun syncDynamicShortcuts(context: Context) {
        val appContext = context.applicationContext ?: context
        try {
            val shortcuts = if (WidgetCacheStore.isFinancialManagerEnabled(appContext)) {
                listOf(
                    ShortcutInfoCompat.Builder(appContext, "new_transaction")
                        .setShortLabel(appContext.getString(R.string.shortcut_new_transaction_short))
                        .setLongLabel(appContext.getString(R.string.shortcut_new_transaction_long))
                        .setIcon(IconCompat.createWithResource(appContext, R.drawable.ic_shortcut_new_transaction))
                        .setIntent(
                            Intent(appContext, MainActivity::class.java).apply {
                                action = "com.saadhjawwadh.notebook.ADD_TRANSACTION"
                            }
                        )
                        .build(),
                    ShortcutInfoCompat.Builder(appContext, "scan_receipt")
                        .setShortLabel(appContext.getString(R.string.shortcut_scan_receipt_short))
                        .setLongLabel(appContext.getString(R.string.shortcut_scan_receipt_long))
                        .setIcon(IconCompat.createWithResource(appContext, R.drawable.ic_shortcut_scan_receipt))
                        .setIntent(
                            Intent(appContext, MainActivity::class.java).apply {
                                action = "com.saadhjawwadh.notebook.SCAN_RECEIPT"
                            }
                        )
                        .build()
                )
            } else {
                listOf(
                    ShortcutInfoCompat.Builder(appContext, "search")
                        .setShortLabel(appContext.getString(R.string.shortcut_search_short))
                        .setLongLabel(appContext.getString(R.string.shortcut_search_long))
                        .setIcon(IconCompat.createWithResource(appContext, R.drawable.ic_shortcut_search))
                        .setIntent(
                            Intent(appContext, MainActivity::class.java).apply {
                                action = "com.saadhjawwadh.notebook.SEARCH"
                            }
                        )
                        .build()
                )
            }
            ShortcutManagerCompat.setDynamicShortcuts(appContext, shortcuts)
        } catch (_: Exception) {
            // Gracefully ignore on launchers without shortcut support
        }
    }
}

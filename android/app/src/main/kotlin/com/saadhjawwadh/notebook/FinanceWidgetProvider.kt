package com.saadhjawwadh.notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import org.json.JSONObject

class FinanceWidgetProvider : AppWidgetProvider() {

    private data class FinanceSnapshot(
        val spentToday: String,
        val spentMonth: String,
        val netMonth: String,
        val netPositive: Boolean,
        val account1Name: String,
        val account2Name: String,
        val dailyBalance: String,
        val savingsBalance: String,
        val enableSavingsVault: Boolean,
        val enableBudgetsAndAnalytics: Boolean,
        val showSplitBills: Boolean,
        val splitBillsPending: String,
        val budgetPercent: Int,
        val budgetLabel: String,
        val topCategory: String,
        val topCategoryAmount: String,
        val forecastAmount: String,
        val forecastPace: String,
        val sparklinePoints: List<Float>,
        val hasEnoughSparklineData: Boolean
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId, newOptions)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onDisabled(context: Context) {
        if (!WidgetCacheStore.isFinancialManagerEnabled(context)) {
            WidgetVisibilityManager.disableComponentIfUnused(context, FinanceWidgetProvider::class.java)
        }
        super.onDisabled(context)
    }

    fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        options: Bundle? = null
    ) {
        val isDisabled = !WidgetCacheStore.isFinancialManagerEnabled(context)
        val isLocked = !isDisabled && WidgetCacheStore.isFinanceLocked(context)
        val snapshot = if (isDisabled || isLocked) null else parseSnapshot(context)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sparklineBitmap = if (
                snapshot != null &&
                snapshot.enableBudgetsAndAnalytics &&
                snapshot.hasEnoughSparklineData
            ) {
                generateSparklineBitmap(
                    context = context,
                    points = snapshot.sparklinePoints,
                    isAlert = snapshot.forecastPace != "on_track"
                )
            } else {
                null
            }

            val stripViews = buildStripViews(context, isDisabled, isLocked, snapshot)
            val compactViews = buildCompactViews(context, isDisabled, isLocked, snapshot)
            val standardViews = buildFullViews(
                context = context,
                layoutRes = R.layout.finance_widget_layout,
                isExpanded = false,
                isDisabled = isDisabled,
                isLocked = isLocked,
                snapshot = snapshot,
                sparklineBitmap = sparklineBitmap
            )
            val expandedViews = buildFullViews(
                context = context,
                layoutRes = R.layout.finance_widget_expanded,
                isExpanded = true,
                isDisabled = isDisabled,
                isLocked = isLocked,
                snapshot = snapshot,
                sparklineBitmap = sparklineBitmap
            )

            val sizeMap = mapOf(
                SizeF(110f, 56f) to stripViews,
                SizeF(180f, 56f) to stripViews,
                SizeF(140f, 110f) to compactViews,
                SizeF(250f, 110f) to standardViews,
                SizeF(360f, 280f) to expandedViews
            )
            appWidgetManager.updateAppWidget(appWidgetId, RemoteViews(sizeMap))
        } else {
            val opts = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            val isStrip = minHeight in 1..90
            val isCompact = !isStrip && ((minWidth in 1..220) || (minHeight in 1..150))
            val isExpanded = !isStrip && !isCompact && minWidth >= 340 && minHeight >= 260

            val views = when {
                isStrip -> buildStripViews(context, isDisabled, isLocked, snapshot)
                isCompact -> buildCompactViews(context, isDisabled, isLocked, snapshot)
                else -> {
                    val sparklineBitmap = if (
                        snapshot != null &&
                        snapshot.enableBudgetsAndAnalytics &&
                        snapshot.hasEnoughSparklineData
                    ) {
                        generateSparklineBitmap(
                            context = context,
                            points = snapshot.sparklinePoints,
                            isAlert = snapshot.forecastPace != "on_track"
                        )
                    } else {
                        null
                    }
                    buildFullViews(
                        context = context,
                        layoutRes = if (isExpanded) R.layout.finance_widget_expanded else R.layout.finance_widget_layout,
                        isExpanded = isExpanded,
                        isDisabled = isDisabled,
                        isLocked = isLocked,
                        snapshot = snapshot,
                        sparklineBitmap = sparklineBitmap
                    )
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun parseSnapshot(context: Context): FinanceSnapshot {
        val raw = WidgetCacheStore.getFinanceSnapshotJson(context)
        return try {
            val json = JSONObject(raw)
            val sparkArray = json.optJSONArray("sparklinePoints")
            val points = mutableListOf<Float>()
            if (sparkArray != null) {
                for (i in 0 until sparkArray.length()) {
                    points.add(sparkArray.optDouble(i, 0.0).toFloat())
                }
            }
            val pace = json.optString("forecastPace", "").ifBlank {
                if (json.optBoolean("isTrendingUp", false)) "over_pace" else "on_track"
            }
            val hasEnough = json.optBoolean("hasEnoughSparklineData", points.size >= 2) && points.size >= 2

            FinanceSnapshot(
                spentToday = json.optString("spentToday", "--").ifBlank { "--" },
                spentMonth = json.optString("spentMonth", "--").ifBlank { "--" },
                netMonth = json.optString("netMonth", "--").ifBlank { "--" },
                netPositive = json.optBoolean("netPositive", true),
                account1Name = json.optString("account1Name", "Daily").ifBlank { "Daily" },
                account2Name = json.optString("account2Name", "Savings").ifBlank { "Savings" },
                dailyBalance = json.optString("dailyBalance", json.optString("dailyNet", "--")).ifBlank { "--" },
                savingsBalance = json.optString("savingsBalance", json.optString("savingsNet", "--")).ifBlank { "--" },
                enableSavingsVault = json.optBoolean("enableSavingsVault", true),
                enableBudgetsAndAnalytics = json.optBoolean("enableBudgetsAndAnalytics", true),
                showSplitBills = json.optBoolean("showSplitBills", false),
                splitBillsPending = json.optString("splitBillsPending", ""),
                budgetPercent = json.optInt("budgetPercent", -1),
                budgetLabel = json.optString("budgetLabel", ""),
                topCategory = json.optString("topCategory", ""),
                topCategoryAmount = json.optString("topCategoryAmount", ""),
                forecastAmount = json.optString("forecastAmount", ""),
                forecastPace = pace,
                sparklinePoints = points,
                hasEnoughSparklineData = hasEnough
            )
        } catch (_: Exception) {
            FinanceSnapshot(
                spentToday = "--",
                spentMonth = "--",
                netMonth = "--",
                netPositive = true,
                account1Name = "Daily",
                account2Name = "Savings",
                dailyBalance = "--",
                savingsBalance = "--",
                enableSavingsVault = true,
                enableBudgetsAndAnalytics = true,
                showSplitBills = false,
                splitBillsPending = "",
                budgetPercent = -1,
                budgetLabel = "",
                topCategory = "",
                topCategoryAmount = "",
                forecastAmount = "",
                forecastPace = "on_track",
                sparklinePoints = emptyList(),
                hasEnoughSparklineData = false
            )
        }
    }

    private fun applyLockOrDisabledMask(
        context: Context,
        views: RemoteViews,
        isDisabled: Boolean,
        isLocked: Boolean
    ): Boolean {
        val manageIntent = actionPendingIntent(context, ACTION_VIEW_LEDGER, 5)
        views.setOnClickPendingIntent(android.R.id.background, manageIntent)

        if (isDisabled) {
            views.setViewVisibility(R.id.finance_content_container, View.GONE)
            views.setViewVisibility(R.id.finance_locked_container, View.VISIBLE)
            views.setTextViewText(
                R.id.finance_locked_label,
                context.getString(R.string.widget_finances_disabled)
            )
            views.setOnClickPendingIntent(R.id.finance_locked_container, manageIntent)
            return true
        }

        if (isLocked) {
            views.setViewVisibility(R.id.finance_content_container, View.GONE)
            views.setViewVisibility(R.id.finance_locked_container, View.VISIBLE)
            views.setTextViewText(
                R.id.finance_locked_label,
                context.getString(R.string.widget_locked_title)
            )
            views.setOnClickPendingIntent(R.id.finance_locked_container, manageIntent)
            return true
        }

        views.setViewVisibility(R.id.finance_locked_container, View.GONE)
        views.setViewVisibility(R.id.finance_content_container, View.VISIBLE)
        return false
    }

    private fun buildStripViews(
        context: Context,
        isDisabled: Boolean,
        isLocked: Boolean,
        snapshot: FinanceSnapshot?
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.finance_widget_strip)
        if (applyLockOrDisabledMask(context, views, isDisabled, isLocked) || snapshot == null) {
            return views
        }

        views.setTextViewText(R.id.finance_strip_today, snapshot.spentToday)
        bindNetViews(
            views,
            R.id.finance_strip_net_positive,
            R.id.finance_strip_net_negative,
            snapshot.netMonth,
            snapshot.netPositive
        )

        val ledgerPendingIntent = actionPendingIntent(context, ACTION_VIEW_LEDGER, 2)
        val addPendingIntent = actionPendingIntent(context, ACTION_ADD_TRANSACTION, 1)
        val scanPendingIntent = actionPendingIntent(context, ACTION_SCAN_RECEIPT, 4)

        views.setOnClickPendingIntent(android.R.id.background, ledgerPendingIntent)
        views.setOnClickPendingIntent(R.id.finance_strip_add, addPendingIntent)
        views.setOnClickPendingIntent(R.id.finance_strip_scan, scanPendingIntent)
        return views
    }

    private fun buildCompactViews(
        context: Context,
        isDisabled: Boolean,
        isLocked: Boolean,
        snapshot: FinanceSnapshot?
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.finance_widget_compact)
        if (applyLockOrDisabledMask(context, views, isDisabled, isLocked) || snapshot == null) {
            return views
        }

        views.setTextViewText(R.id.widget_account_chip, snapshot.account1Name)
        views.setTextViewText(R.id.widget_today_spent, snapshot.spentToday)
        bindNetViews(
            views,
            R.id.widget_month_net_positive,
            R.id.widget_month_net_negative,
            snapshot.netMonth,
            snapshot.netPositive
        )

        views.setOnClickPendingIntent(
            android.R.id.background,
            actionPendingIntent(context, ACTION_VIEW_LEDGER, 2)
        )
        views.setOnClickPendingIntent(
            R.id.widget_add_button,
            actionPendingIntent(context, ACTION_ADD_TRANSACTION, 1)
        )
        return views
    }

    private fun buildFullViews(
        context: Context,
        layoutRes: Int,
        isExpanded: Boolean,
        isDisabled: Boolean,
        isLocked: Boolean,
        snapshot: FinanceSnapshot?,
        sparklineBitmap: Bitmap?
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutRes)
        if (applyLockOrDisabledMask(context, views, isDisabled, isLocked) || snapshot == null) {
            return views
        }

        views.setTextViewText(R.id.widget_account_chip, snapshot.account1Name)
        views.setTextViewText(R.id.widget_today_spent, snapshot.spentToday)
        views.setTextViewText(R.id.widget_month_spent, snapshot.spentMonth)
        bindNetViews(
            views,
            R.id.widget_month_net_positive,
            R.id.widget_month_net_negative,
            snapshot.netMonth,
            snapshot.netPositive
        )

        if (!snapshot.enableBudgetsAndAnalytics) {
            views.setViewVisibility(R.id.widget_analytics_card, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_analytics_card, View.VISIBLE)
            val displayForecast = if (snapshot.forecastAmount.isNotBlank()) {
                snapshot.forecastAmount
            } else {
                snapshot.spentMonth
            }
            views.setTextViewText(R.id.widget_forecast_amount, displayForecast)

            when (snapshot.forecastPace) {
                "exhausted" -> {
                    views.setViewVisibility(R.id.widget_forecast_trend_alert, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_forecast_trend_normal, View.GONE)
                    views.setTextViewText(
                        R.id.widget_forecast_trend_alert,
                        context.getString(R.string.widget_pace_exhausted)
                    )
                }
                "over_pace" -> {
                    views.setViewVisibility(R.id.widget_forecast_trend_alert, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_forecast_trend_normal, View.GONE)
                    views.setTextViewText(
                        R.id.widget_forecast_trend_alert,
                        context.getString(R.string.widget_pace_fast)
                    )
                }
                else -> {
                    views.setViewVisibility(R.id.widget_forecast_trend_alert, View.GONE)
                    views.setViewVisibility(R.id.widget_forecast_trend_normal, View.VISIBLE)
                    views.setTextViewText(
                        R.id.widget_forecast_trend_normal,
                        context.getString(R.string.widget_pace_on_track)
                    )
                }
            }

            if (sparklineBitmap != null) {
                views.setViewVisibility(R.id.widget_sparkline_plot, View.VISIBLE)
                views.setViewVisibility(R.id.widget_sparkline_empty, View.GONE)
                views.setImageViewBitmap(R.id.widget_sparkline_plot, sparklineBitmap)
            } else {
                views.setViewVisibility(R.id.widget_sparkline_plot, View.GONE)
                views.setViewVisibility(R.id.widget_sparkline_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_sparkline_empty,
                    context.getString(R.string.widget_sparkline_empty_hint)
                )
            }
        }

        if (isExpanded) {
            if (snapshot.enableSavingsVault) {
                views.setViewVisibility(R.id.widget_dual_account_row, View.VISIBLE)
                views.setTextViewText(R.id.widget_daily_label, snapshot.account1Name)
                views.setTextViewText(R.id.widget_daily_value, snapshot.dailyBalance)
                views.setTextViewText(R.id.widget_savings_label, snapshot.account2Name)
                views.setTextViewText(R.id.widget_savings_value, snapshot.savingsBalance)
            } else {
                views.setViewVisibility(R.id.widget_dual_account_row, View.GONE)
            }

            if (snapshot.enableBudgetsAndAnalytics && snapshot.budgetPercent >= 0) {
                views.setViewVisibility(R.id.widget_budget_section, View.VISIBLE)
                views.setTextViewText(R.id.widget_budget_label, snapshot.budgetLabel)
                views.setTextViewText(R.id.widget_budget_percent, "${snapshot.budgetPercent}%")
            } else {
                views.setViewVisibility(R.id.widget_budget_section, View.GONE)
            }

            if (snapshot.enableBudgetsAndAnalytics && snapshot.topCategory.isNotBlank()) {
                views.setViewVisibility(R.id.widget_top_category_label, View.VISIBLE)
                val catText = if (snapshot.topCategoryAmount.isNotBlank()) {
                    "${snapshot.topCategory} • ${snapshot.topCategoryAmount}"
                } else {
                    snapshot.topCategory
                }
                views.setTextViewText(R.id.widget_top_category_label, catText)
            } else {
                views.setViewVisibility(R.id.widget_top_category_label, View.GONE)
            }

            if (snapshot.showSplitBills && snapshot.splitBillsPending.isNotBlank()) {
                views.setViewVisibility(R.id.widget_split_bills_chip, View.VISIBLE)
                views.setTextViewText(R.id.widget_split_bills_chip, snapshot.splitBillsPending)
            } else {
                views.setViewVisibility(R.id.widget_split_bills_chip, View.GONE)
            }
        }

        val addPendingIntent = actionPendingIntent(context, ACTION_ADD_TRANSACTION, 1)
        val ledgerPendingIntent = actionPendingIntent(context, ACTION_VIEW_LEDGER, 2)
        val budgetsPendingIntent = actionPendingIntent(context, ACTION_VIEW_BUDGETS, 3)
        val scanPendingIntent = actionPendingIntent(context, ACTION_SCAN_RECEIPT, 4)

        views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)
        views.setOnClickPendingIntent(R.id.widget_scan_button, scanPendingIntent)
        views.setOnClickPendingIntent(R.id.widget_overview_grid, ledgerPendingIntent)
        views.setOnClickPendingIntent(R.id.widget_analytics_card, budgetsPendingIntent)
        views.setOnClickPendingIntent(android.R.id.background, ledgerPendingIntent)

        return views
    }

    private fun bindNetViews(
        views: RemoteViews,
        positiveViewId: Int,
        negativeViewId: Int,
        netMonth: String,
        netPositive: Boolean
    ) {
        if (netPositive) {
            views.setViewVisibility(positiveViewId, View.VISIBLE)
            views.setViewVisibility(negativeViewId, View.GONE)
            views.setTextViewText(positiveViewId, netMonth)
        } else {
            views.setViewVisibility(positiveViewId, View.GONE)
            views.setViewVisibility(negativeViewId, View.VISIBLE)
            views.setTextViewText(negativeViewId, netMonth)
        }
    }

    private fun generateSparklineBitmap(
        context: Context,
        points: List<Float>,
        isAlert: Boolean
    ): Bitmap? {
        if (points.size < 2) return null

        val density = context.resources.displayMetrics.density
        val width = (170f * density).toInt().coerceIn(220, 680)
        val height = (60f * density).toInt().coerceIn(80, 240)
        val scale = width / 340f

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val paddingX = 16f * scale
        val paddingY = 18f * scale
        val n = points.size

        var maxVal = points.maxOrNull() ?: 1f
        var minVal = points.minOrNull() ?: 0f
        if (maxVal == minVal) {
            maxVal += 10f
            minVal = (minVal - 10f).coerceAtLeast(0f)
        }
        val range = (maxVal - minVal).coerceAtLeast(1f)

        val coords = mutableListOf<PointF>()
        val stepX = (width - 2f * paddingX) / (n - 1)
        for (i in 0 until n) {
            val x = paddingX + i * stepX
            val normY = (points[i] - minVal) / range
            val y = height - paddingY - normY * (height - 2f * paddingY)
            coords.add(PointF(x, y))
        }

        val useDynamicColor = WidgetCacheStore.isUseDynamicColor(context)
        val primaryColor = ContextCompat.getColor(
            context,
            if (useDynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                R.color.widget_accent
            } else {
                R.color.widget_primary
            }
        )
        val tertiaryColor = ContextCompat.getColor(
            context,
            if (isAlert) R.color.widget_expense else R.color.widget_income
        )

        val fillPath = Path()
        fillPath.moveTo(coords[0].x, coords[0].y)
        for (i in 0 until n - 1) {
            val p1 = coords[i]
            val p2 = coords[i + 1]
            val cx = (p1.x + p2.x) / 2f
            fillPath.cubicTo(cx, p1.y, cx, p2.y, p2.x, p2.y)
        }
        fillPath.lineTo(coords.last().x, height.toFloat())
        fillPath.lineTo(coords.first().x, height.toFloat())
        fillPath.close()

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            shader = LinearGradient(
                0f, 0f, 0f, height.toFloat(),
                Color.argb(55, Color.red(primaryColor), Color.green(primaryColor), Color.blue(primaryColor)),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawPath(fillPath, fillPaint)

        val solidPath = Path()
        solidPath.moveTo(coords[0].x, coords[0].y)
        val solidEndIdx = if (n >= 3) n - 2 else n - 1
        for (i in 0 until solidEndIdx) {
            val p1 = coords[i]
            val p2 = coords[i + 1]
            val cx = (p1.x + p2.x) / 2f
            solidPath.cubicTo(cx, p1.y, cx, p2.y, p2.x, p2.y)
        }

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 6f * scale
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            color = primaryColor
        }
        canvas.drawPath(solidPath, strokePaint)

        if (n >= 3) {
            val dashPath = Path()
            val p1 = coords[solidEndIdx]
            val p2 = coords[n - 1]
            val cx = (p1.x + p2.x) / 2f
            dashPath.moveTo(p1.x, p1.y)
            dashPath.cubicTo(cx, p1.y, cx, p2.y, p2.x, p2.y)

            val dashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 5.5f * scale
                strokeCap = Paint.Cap.ROUND
                pathEffect = DashPathEffect(floatArrayOf(12f * scale, 10f * scale), 0f)
                color = tertiaryColor
            }
            canvas.drawPath(dashPath, dashPaint)
        }

        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = primaryColor
        }
        val dotHolePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        }
        for (i in 0 until (if (n >= 3) n - 1 else n)) {
            canvas.drawCircle(coords[i].x, coords[i].y, 7f * scale, dotPaint)
            canvas.drawCircle(coords[i].x, coords[i].y, 3.5f * scale, dotHolePaint)
        }

        val forecastDot = coords.last()
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.argb(80, Color.red(tertiaryColor), Color.green(tertiaryColor), Color.blue(tertiaryColor))
        }
        val targetDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = tertiaryColor
        }
        canvas.drawCircle(forecastDot.x, forecastDot.y, 14f * scale, glowPaint)
        canvas.drawCircle(forecastDot.x, forecastDot.y, 8.5f * scale, targetDotPaint)
        canvas.drawCircle(forecastDot.x, forecastDot.y, 4f * scale, dotHolePaint)

        return bitmap
    }

    private fun actionPendingIntent(context: Context, action: String, slot: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            data = Uri.parse("widget://finance/slot/$slot")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            REQUEST_CODE_BASE + slot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        private const val REQUEST_CODE_BASE = 200_000
        private const val ACTION_ADD_TRANSACTION = "com.saadhjawwadh.notebook.ADD_TRANSACTION"
        private const val ACTION_VIEW_LEDGER = "com.saadhjawwadh.notebook.VIEW_LEDGER"
        private const val ACTION_VIEW_BUDGETS = "com.saadhjawwadh.notebook.VIEW_BUDGETS"
        private const val ACTION_SCAN_RECEIPT = "com.saadhjawwadh.notebook.SCAN_RECEIPT"

        fun updateAllWidgets(context: Context) {
            val appContext = context.applicationContext ?: context
            val appWidgetManager = AppWidgetManager.getInstance(appContext)
            val thisWidget = ComponentName(appContext, FinanceWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (allWidgetIds.isNotEmpty()) {
                val provider = FinanceWidgetProvider()
                for (id in allWidgetIds) {
                    provider.updateAppWidget(appContext, appWidgetManager, id)
                }
            }
        }
    }
}

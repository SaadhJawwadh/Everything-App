import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Centralized locale-aware formatting utility for Everything App.
/// Adheres to Material 3 Expressive and i18n standards by formatting
/// currencies, dates, times, and numbers according to device/app locale.
class AppFormatters {
  AppFormatters._();

  static final Map<String, NumberFormat> _numCache = {};
  static final Map<String, DateFormat> _dateCache = {};

  static final NumberFormat _amountFixedFmt = NumberFormat('#,##0.00');
  static final NumberFormat _amountCompactDecFmt = NumberFormat('#,##0.##');
  static final NumberFormat _amountIntFmt = NumberFormat('#,##0');
  static final DateFormat _time12hFmt = DateFormat('hh:mm a');
  static final DateFormat _monthDayFmt = DateFormat.MMMd();

  static String formatAmountFixed(double amount) => _amountFixedFmt.format(amount);
  static String formatAmountCompactDec(double amount) => _amountCompactDecFmt.format(amount);
  static String formatAmountInt(double amount) => _amountIntFmt.format(amount);
  static String formatTime12h(DateTime dt) => _time12hFmt.format(dt);
  static String formatMonthDay(DateTime dt) => _monthDayFmt.format(dt);

  static NumberFormat _cachedNum(String key, NumberFormat Function() builder) {
    if (_numCache.length >= 32) _numCache.clear();
    return _numCache.putIfAbsent(key, builder);
  }

  static DateFormat _cachedDate(String key, DateFormat Function() builder) {
    if (_dateCache.length >= 32) _dateCache.clear();
    return _dateCache.putIfAbsent(key, builder);
  }

  /// Formats a financial currency [amount] according to the active [BuildContext] locale.
  /// 
  /// If [currency] is omitted, falls back to the user's preferred currency in [SettingsProvider].
  /// [showDecimals] controls whether cents/kopecks are displayed (default true).
  /// [compact] creates concise shorthand formats (e.g. 1.2K, 3.5M).
  static String formatCurrency(
    BuildContext context,
    double amount, {
    String? currency,
    bool showDecimals = true,
    bool compact = false,
  }) {
    final locale = Localizations.localeOf(context).toString();
    String activeCurrency = currency ?? '';
    if (activeCurrency.isEmpty) {
      try {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        activeCurrency = settings.currencySymbol;
      } catch (_) {
        activeCurrency = '';
      }
    }

    if (compact) {
      final compactFormat = _cachedNum('compact_$locale', () => NumberFormat.compact(locale: locale));
      final formattedNumber = compactFormat.format(amount);
      return activeCurrency.isNotEmpty
          ? '$activeCurrency$formattedNumber'
          : formattedNumber;
    }

    try {
      final digits = showDecimals ? (amount.truncateToDouble() == amount && !showDecimals ? 0 : 2) : 0;
      final formatter = _cachedNum(
        'curr_${locale}_${activeCurrency}_$digits',
        () => NumberFormat.currency(
          locale: locale,
          symbol: activeCurrency,
          decimalDigits: digits,
        ),
      );
      return formatter.format(amount).trim();
    } catch (_) {
      // Fallback in case of unknown locale or malformed symbol
      final numFormat = showDecimals ? _amountFixedFmt : _amountIntFmt;
      return activeCurrency.isNotEmpty
          ? '$activeCurrency ${numFormat.format(amount)}'
          : numFormat.format(amount);
    }
  }

  /// Formats a [DateTime] into a localized medium date, e.g. "Oct 22, 2026" or "22 окт. 2026 г.".
  static String formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    try {
      return _cachedDate('yMMMd_$locale', () => DateFormat.yMMMd(locale)).format(date);
    } catch (_) {
      return _cachedDate('yMMMd_default', () => DateFormat.yMMMd()).format(date);
    }
  }

  /// Formats a [DateTime] into a localized short date, e.g. "Oct 22" or "22 окт.".
  static String formatShortDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    try {
      return _cachedDate('MMMd_$locale', () => DateFormat.MMMd(locale)).format(date);
    } catch (_) {
      return _monthDayFmt.format(date);
    }
  }

  /// Formats a [DateTime] into a localized time, e.g. "2:30 PM" or "14:30".
  static String formatTime(BuildContext context, DateTime time) {
    final locale = Localizations.localeOf(context).toString();
    try {
      return _cachedDate('jm_$locale', () => DateFormat.jm(locale)).format(time);
    } catch (_) {
      return _cachedDate('jm_default', () => DateFormat.jm()).format(time);
    }
  }

  /// Formats a [DateTime] into a localized date and time, e.g. "Oct 22, 2026, 2:30 PM".
  static String formatDateTime(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    try {
      return '${_cachedDate('yMMMd_$locale', () => DateFormat.yMMMd(locale)).format(dateTime)}, ${_cachedDate('jm_$locale', () => DateFormat.jm(locale)).format(dateTime)}';
    } catch (_) {
      return '${_cachedDate('yMMMd_default', () => DateFormat.yMMMd()).format(dateTime)}, ${_cachedDate('jm_default', () => DateFormat.jm()).format(dateTime)}';
    }
  }

  /// Formats an integer or decimal number with locale grouping separators (e.g. 1,000 or 1 000).
  static String formatNumber(BuildContext context, num number, {int? decimalDigits}) {
    final locale = Localizations.localeOf(context).toString();
    try {
      final formatter = decimalDigits != null
          ? _cachedNum('dec_${locale}_$decimalDigits', () => NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimalDigits))
          : _cachedNum('dec_$locale', () => NumberFormat.decimalPattern(locale));
      return formatter.format(number);
    } catch (_) {
      return number.toString();
    }
  }
}

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/split_bill_model.dart';

import '../../../screens/app_lock_screen.dart';

class SplitShareService {
  static String formatBillSummary(
    SplitBillModel bill, {
    String currencySymbol = 'Rs.',
    String? defaultPaymentInfo,
  }) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final formattedDate = dateFormat.format(bill.date);
    final groupHeader = bill.groupTag != null && bill.groupTag!.isNotEmpty ? ' (${bill.groupTag})' : '';

    final buffer = StringBuffer();
    buffer.writeln('🧾 ${bill.title}$groupHeader');
    buffer.writeln('🗓️ $formattedDate • Total: $currencySymbol ${bill.totalAmount.toStringAsFixed(2).replaceAll('.00', '')}');
    buffer.writeln('');

    if (bill.isPayerUser) {
      buffer.writeln('• ${bill.payerName} (Paid for bill): $currencySymbol ${bill.userShare.toStringAsFixed(2).replaceAll('.00', '')} ✅');
      for (final p in bill.participants) {
        if (p.contactName.trim().toLowerCase() != 'you') {
          final statusIcon = p.hasPaid ? '✅ Paid' : '⏳ Pending';
          buffer.writeln('• ${p.contactName}: $currencySymbol ${p.shareAmount.toStringAsFixed(2).replaceAll('.00', '')} $statusIcon');
        }
      }
    } else {
      buffer.writeln('• ${bill.payerName} (Paid for bill) ✅');
      for (final p in bill.participants) {
        if (p.contactName.trim().toLowerCase() == bill.payerName.trim().toLowerCase()) {
          continue;
        }
        final statusIcon = p.hasPaid ? '✅ Paid' : '⏳ Pending';
        buffer.writeln('• ${p.contactName}: $currencySymbol ${p.shareAmount.toStringAsFixed(2).replaceAll('.00', '')} $statusIcon');
      }
    }

    if (bill.isPayerUser && defaultPaymentInfo != null && defaultPaymentInfo.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💳 Payment Details:');
      buffer.writeln(defaultPaymentInfo.trim());
    }

    return buffer.toString().trim();
  }

  static String formatPersonReminder({
    required String contactName,
    required String billTitle,
    required double shareAmount,
    String currencySymbol = 'Rs.',
    String? defaultPaymentInfo,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('👋 Hey $contactName,');
    buffer.writeln('Your share for "$billTitle" is $currencySymbol ${shareAmount.toStringAsFixed(2).replaceAll('.00', '')}.');
    
    if (defaultPaymentInfo != null && defaultPaymentInfo.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💳 Send to:');
      buffer.writeln(defaultPaymentInfo.trim());
    }
    return buffer.toString().trim();
  }

  static String formatPersonPendingStatement({
    required String contactName,
    required List<SplitBillModel> openBills,
    required double totalAmount,
    String currencySymbol = 'Rs.',
    String? defaultPaymentInfo,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('👋 Hey $contactName,');
    final formattedTotal = totalAmount.abs().toStringAsFixed(2).replaceAll('.00', '');
    final directionSign = totalAmount >= 0 ? '+' : '-';
    buffer.writeln('Here is a summary of our shared balance:');
    buffer.writeln('💰 Total Balance: $directionSign$currencySymbol $formattedTotal (${totalAmount >= 0 ? "Please send" : "I will pay"})');

    if (openBills.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📋 Pending Bills:');
      final dateFormat = DateFormat('MMM d, yyyy');
      for (final bill in openBills) {
        final dateStr = dateFormat.format(bill.date);
        if (bill.isPayerUser) {
          final p = bill.participants.where((part) =>
              part.contactName.trim().toLowerCase() == contactName.trim().toLowerCase() && !part.hasPaid).firstOrNull;
          if (p != null) {
            final shareStr = p.shareAmount.toStringAsFixed(2).replaceAll('.00', '');
            buffer.writeln('• ${bill.title} ($dateStr): +$currencySymbol $shareStr (Owes you)');
          }
        } else {
          final shareStr = bill.userShare.toStringAsFixed(2).replaceAll('.00', '');
          buffer.writeln('• ${bill.title} ($dateStr): -$currencySymbol $shareStr (You owe $contactName)');
        }
      }
    }

    if (totalAmount > 0 && defaultPaymentInfo != null && defaultPaymentInfo.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💳 Send to:');
      buffer.writeln(defaultPaymentInfo.trim());
    }

    return buffer.toString().trim();
  }

  static Future<void> shareToWhatsAppOrSystem(
    SplitBillModel bill, {
    String currencySymbol = 'Rs.',
    String? defaultPaymentInfo,
  }) async {
    final text = formatBillSummary(
      bill,
      currencySymbol: currencySymbol,
      defaultPaymentInfo: defaultPaymentInfo,
    );
    AppLockScreen.ignoreNextResumeLock();
    await Share.share(
      text,
      subject: 'Split Bill: ${bill.title}',
    );
  }

  static Future<void> shareText(String text, {String? subject}) async {
    AppLockScreen.ignoreNextResumeLock();
    await Share.share(
      text,
      subject: subject,
    );
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

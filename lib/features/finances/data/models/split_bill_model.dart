import 'package:flutter/material.dart';

enum SplitStatus { unsettled, partial, settled }

enum SplitMode { equal, exact }

class SplitParticipantModel {
  final String id;
  final String billId;
  final String contactName;
  final double shareAmount;
  final bool hasPaid;
  final DateTime? paidAt;
  final int? settlementTransactionId;

  const SplitParticipantModel({
    required this.id,
    required this.billId,
    required this.contactName,
    required this.shareAmount,
    this.hasPaid = false,
    this.paidAt,
    this.settlementTransactionId,
  });

  SplitParticipantModel copyWith({
    String? id,
    String? billId,
    String? contactName,
    double? shareAmount,
    bool? hasPaid,
    DateTime? paidAt,
    int? settlementTransactionId,
    bool clearSettlementTxId = false,
  }) {
    return SplitParticipantModel(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      contactName: contactName ?? this.contactName,
      shareAmount: shareAmount ?? this.shareAmount,
      hasPaid: hasPaid ?? this.hasPaid,
      paidAt: paidAt ?? this.paidAt,
      settlementTransactionId: clearSettlementTxId
          ? null
          : (settlementTransactionId ?? this.settlementTransactionId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billId': billId,
      'contactName': contactName,
      'shareAmount': shareAmount,
      'hasPaid': hasPaid ? 1 : 0,
      'paidAt': paidAt?.toIso8601String(),
      'settlementTransactionId': settlementTransactionId,
    };
  }

  factory SplitParticipantModel.fromMap(Map<String, dynamic> map) {
    return SplitParticipantModel(
      id: map['id'] as String,
      billId: map['billId'] as String,
      contactName: map['contactName'] as String,
      shareAmount: (map['shareAmount'] as num).toDouble(),
      hasPaid: (map['hasPaid'] as int? ?? 0) == 1,
      paidAt: map['paidAt'] != null ? DateTime.tryParse(map['paidAt'] as String) : null,
      settlementTransactionId: map['settlementTransactionId'] as int?,
    );
  }
}

class SplitBillModel {
  final String id;
  final int? transactionId;
  final String title;
  final double totalAmount;
  final String payerName;
  final bool isPayerUser;
  final SplitMode splitMode;
  final String? groupTag;
  final DateTime date;
  final String? notes;
  final String? receiptImagePath;
  final SplitStatus status;
  final DateTime? deletedAt;
  final List<SplitParticipantModel> participants;

  const SplitBillModel({
    required this.id,
    this.transactionId,
    required this.title,
    required this.totalAmount,
    this.payerName = 'You',
    this.isPayerUser = true,
    this.splitMode = SplitMode.equal,
    this.groupTag,
    required this.date,
    this.notes,
    this.receiptImagePath,
    this.status = SplitStatus.unsettled,
    this.deletedAt,
    this.participants = const [],
  });

  /// The user's explicit participant entry if present
  SplitParticipantModel? get userParticipant {
    final list = participants.where((p) => p.contactName.trim().toLowerCase() == 'you').toList();
    return list.isNotEmpty ? list.first : null;
  }

  /// The user's personal share of the bill
  double get userShare {
    final userPart = userParticipant;
    if (userPart != null) {
      return userPart.shareAmount;
    }
    // If not listed as explicit participant and user paid, user share is remainder
    final othersTotal = participants.where((p) => p.contactName.trim().toLowerCase() != 'you').fold<double>(0.0, (sum, p) => sum + p.shareAmount);
    final remainder = totalAmount - othersTotal;
    return remainder > 0 ? remainder : 0.0;
  }

  /// Whether the user has settled their personal share (always true if user was the payer)
  bool get isUserSharePaid {
    if (isPayerUser) return true;
    final userPart = userParticipant;
    if (userPart != null) {
      return userPart.hasPaid;
    }
    return status == SplitStatus.settled;
  }

  /// Total amount other people still owe to the user for this bill
  double get totalOwedToUser {
    if (!isPayerUser) return 0.0;
    return participants
        .where((p) => !p.hasPaid && p.contactName.trim().toLowerCase() != 'you')
        .fold<double>(0.0, (sum, p) => sum + p.shareAmount);
  }

  /// Total amount the user still owes to a friend for this bill
  double get totalUserOwes {
    if (isPayerUser) return 0.0;
    return isUserSharePaid ? 0.0 : userShare;
  }

  /// Total amount already received back by the user
  double get totalReceived {
    if (!isPayerUser) return 0.0;
    return participants
        .where((p) => p.hasPaid && p.contactName.trim().toLowerCase() != 'you')
        .fold<double>(0.0, (sum, p) => sum + p.shareAmount);
  }

  /// Total expected from others (excluding user's own share)
  double get totalOthersShare {
    return participants
        .where((p) => p.contactName.trim().toLowerCase() != 'you')
        .fold<double>(0.0, (sum, p) => sum + p.shareAmount);
  }

  /// Number of participants who have not settled yet
  int get pendingCount {
    return participants.where((p) => !p.hasPaid && p.contactName.trim().toLowerCase() != 'you').length;
  }

  /// Whether the bill is fully settled from the user's perspective
  /// (If you paid: all participants paid you back; If someone else paid: you paid your share)
  bool get isFullySettled {
    if (isPayerUser) {
      final others = participants.where((p) => p.contactName.trim().toLowerCase() != 'you');
      if (others.isEmpty) return true;
      return others.every((p) => p.hasPaid);
    } else {
      return isUserSharePaid;
    }
  }

  SplitStatus computeDerivedStatus() {
    if (isFullySettled) return SplitStatus.settled;
    if (isPayerUser && totalReceived > 0) return SplitStatus.partial;
    return SplitStatus.unsettled;
  }

  SplitBillModel copyWith({
    String? id,
    int? transactionId,
    String? title,
    double? totalAmount,
    String? payerName,
    bool? isPayerUser,
    SplitMode? splitMode,
    String? groupTag,
    DateTime? date,
    String? notes,
    String? receiptImagePath,
    SplitStatus? status,
    DateTime? deletedAt,
    List<SplitParticipantModel>? participants,
  }) {
    return SplitBillModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      payerName: payerName ?? this.payerName,
      isPayerUser: isPayerUser ?? this.isPayerUser,
      splitMode: splitMode ?? this.splitMode,
      groupTag: groupTag ?? this.groupTag,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      status: status ?? this.status,
      deletedAt: deletedAt ?? this.deletedAt,
      participants: participants ?? this.participants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'title': title,
      'totalAmount': totalAmount,
      'payerName': payerName,
      'isPayerUser': isPayerUser ? 1 : 0,
      'splitMode': splitMode.name,
      'groupTag': groupTag,
      'date': date.toIso8601String(),
      'notes': notes,
      'receiptImagePath': receiptImagePath,
      'status': status.name,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory SplitBillModel.fromMap(Map<String, dynamic> map, {List<SplitParticipantModel> participants = const []}) {
    return SplitBillModel(
      id: map['id'] as String,
      transactionId: map['transactionId'] as int?,
      title: map['title'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      payerName: map['payerName'] as String? ?? 'You',
      isPayerUser: (map['isPayerUser'] as int? ?? 1) == 1,
      splitMode: (map['splitMode'] as String?) == 'exact' ? SplitMode.exact : SplitMode.equal,
      groupTag: map['groupTag'] as String?,
      date: DateTime.tryParse(map['date'] as String) ?? DateTime.now(),
      notes: map['notes'] as String?,
      receiptImagePath: map['receiptImagePath'] as String?,
      status: _parseStatus(map['status'] as String?),
      deletedAt: map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt'] as String) : null,
      participants: participants,
    );
  }

  static SplitStatus _parseStatus(String? str) {
    if (str == 'settled') return SplitStatus.settled;
    if (str == 'partial') return SplitStatus.partial;
    return SplitStatus.unsettled;
  }
}

class SplitContactModel {
  final String name;
  final String? phoneNumber;
  final int colorValue;
  final DateTime lastUsed;

  const SplitContactModel({
    required this.name,
    this.phoneNumber,
    required this.colorValue,
    required this.lastUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'colorValue': colorValue,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory SplitContactModel.fromMap(Map<String, dynamic> map) {
    return SplitContactModel(
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String?,
      colorValue: map['colorValue'] as int? ?? Colors.teal.toARGB32(),
      lastUsed: map['lastUsed'] != null ? DateTime.tryParse(map['lastUsed'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }
}

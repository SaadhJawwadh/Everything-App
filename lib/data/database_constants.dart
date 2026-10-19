class TableNames {
  static const String notes = 'notes';
  static const String tags = 'tags';
  static const String transactions = 'transactions';
  static const String categoryDefinitions = 'category_definitions';
  static const String smsContacts = 'sms_contacts';
  static const String periodLogs = 'period_logs';
  static const String recurringRules = 'recurring_rules';
  static const String deletedTransactionSmsIds = 'deleted_transaction_sms_ids';
  static const String splitBills = 'split_bills';
  static const String splitParticipants = 'split_participants';
  static const String splitContacts = 'split_contacts';
  static const String deletedPeriodLogs = 'deleted_period_logs';
  static const String savingsGoals = 'savings_goals';
}

class SavingsGoalFields {
  static const String id = 'id';
  static const String title = 'title';
  static const String targetAmount = 'targetAmount';
  static const String currentAmount = 'currentAmount';
  static const String targetDate = 'targetDate';
  static const String targetMonths = 'targetMonths';
  static const String monthlyContribution = 'monthlyContribution';
  static const String category = 'category';
  static const String account = 'account';
  static const String colorValue = 'colorValue';
  static const String iconCodePoint = 'iconCodePoint';
  static const String isCompleted = 'isCompleted';
  static const String createdAt = 'createdAt';
  static const String completedAt = 'completedAt';
  static const String deletedAt = 'deletedAt';
}

class SplitBillFields {
  static const String id = 'id';
  static const String transactionId = 'transactionId';
  static const String title = 'title';
  static const String totalAmount = 'totalAmount';
  static const String payerName = 'payerName';
  static const String isPayerUser = 'isPayerUser';
  static const String splitMode = 'splitMode';
  static const String groupTag = 'groupTag';
  static const String date = 'date';
  static const String notes = 'notes';
  static const String receiptImagePath = 'receiptImagePath';
  static const String status = 'status';
  static const String deletedAt = 'deletedAt';
}

class SplitParticipantFields {
  static const String id = 'id';
  static const String billId = 'billId';
  static const String contactName = 'contactName';
  static const String shareAmount = 'shareAmount';
  static const String hasPaid = 'hasPaid';
  static const String paidAt = 'paidAt';
  static const String settlementTransactionId = 'settlementTransactionId';
}

class SplitContactFields {
  static const String name = 'name';
  static const String phoneNumber = 'phoneNumber';
  static const String colorValue = 'colorValue';
  static const String lastUsed = 'lastUsed';
}

class NoteFields {
  static const String id = 'id';
  static const String title = 'title';
  static const String content = 'content';
  static const String dateCreated = 'dateCreated';
  static const String dateModified = 'dateModified';
  static const String color = 'color';
  static const String isPinned = 'isPinned';
  static const String isArchived = 'isArchived';
  static const String imagePath = 'imagePath';
  static const String category = 'category';
  static const String tags = 'tags';
  static const String previewText = 'previewText';
  static const String deletedAt = 'deletedAt';
  static const String reminderAt = 'reminderAt';
  static const String isLocked = 'isLocked';
}

class RecurringRuleFields {
  static const String id = 'id';
  static const String description = 'description';
  static const String amount = 'amount';
  static const String category = 'category';
  static const String isExpense = 'isExpense';
  static const String frequency = 'frequency'; // daily | weekly | monthly
  static const String nextDue = 'nextDue';
}

class TagFields {
  static const String name = 'name';
  static const String color = 'color';
}

class CategoryFields {
  static const String name = 'name';
  static const String color = 'color';
  static const String keywords = 'keywords';
  static const String isBuiltIn = 'isBuiltIn';
  static const String iconCodePoint = 'iconCodePoint';
}

class SmsContactFields {
  static const String id = 'id';
  static const String senderIds = 'senderIds';
  static const String label = 'label';
  static const String isBuiltIn = 'isBuiltIn';
  static const String isBlocked = 'isBlocked';
}

class PeriodLogFields {
  static const String id = 'id';
  static const String startDate = 'startDate';
  static const String endDate = 'endDate';
  static const String intensity = 'intensity';
  static const String notes = 'notes';
  static const String symptoms = 'symptoms';
}

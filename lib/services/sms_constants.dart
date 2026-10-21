class SmsConstants {
  static const bankSenders = {
    'COMBANK', 'Comm-Bank', 'CBSL', 'ComBank_Q+',
    'PEOBANK', 'PeoplesB', 'PBOCSL', 'PEOPLBK',
    'HNB', 'HNBANK', 'HNBAlerts',
    'SAMPATH', 'Sampath', 'SAMPTBK',
    'BOCCSL', 'BOC', 'BOCSL',
    'NDB', 'NDBBANK',
    'SEYLAN', 'Seybank', 'SEYLNBK',
    'AMANABNK', 'AMANA', 'AMANABK',
    'NTB', 'NTBBANK',
    'LOLC',
    'HSBC', 'SCB', 'CITI', 'AXIS', 'ICICI', 'SBI', 'HDFC', 'KOTAK',
    'ENBD', 'DBS', 'CHASE', 'BOA', 'BARCLAYS', 'BANK', 'ALERTS', 'CARD',
    '900', 'SBERBANK', 'SBER', 'T-BANK', 'TINKOFF', 'VTB', 'ALFABANK', 'ALFA-BANK',
    'RAIFFEISEN', 'GAZPROMBANK',
  };

  static const senderToBankName = <String, String>{
    'COMBANK': 'Commercial Bank',
    'Comm-Bank': 'Commercial Bank',
    'CBSL': 'Commercial Bank',
    'ComBank_Q+': 'Commercial Bank',
    'PEOBANK': 'Peoples Bank',
    'PeoplesB': 'Peoples Bank',
    'PBOCSL': 'Peoples Bank',
    'PEOPLBK': 'Peoples Bank',
    'HNB': 'HNB',
    'HNBANK': 'HNB',
    'HNBAlerts': 'HNB',
    'SAMPATH': 'Sampath Bank',
    'Sampath': 'Sampath Bank',
    'SAMPTBK': 'Sampath Bank',
    'BOCCSL': 'BOC',
    'BOC': 'BOC',
    'BOCSL': 'BOC',
    'NDB': 'NDB Bank',
    'NDBBANK': 'NDB Bank',
    'SEYLAN': 'Seylan Bank',
    'Seybank': 'Seylan Bank',
    'SEYLNBK': 'Seylan Bank',
    'AMANABNK': 'Amana Bank',
    'AMANA': 'Amana Bank',
    'AMANABK': 'Amana Bank',
    'NTB': 'Nations Trust Bank',
    'NTBBANK': 'Nations Trust Bank',
    'LOLC': 'LOLC Finance',
    '900': 'Sberbank',
    'SBERBANK': 'Sberbank',
    'SBER': 'Sberbank',
    'TINKOFF': 'Tinkoff',
    'T-BANK': 'T-Bank',
    'VTB': 'VTB',
    'ALFABANK': 'Alfa-Bank',
    'ALFA-BANK': 'Alfa-Bank',
    'RAIFFEISEN': 'Raiffeisenbank',
  };

  static final amountRegex = RegExp(
      r'(?:(?:LKR|Rs\.?|INR|USD|EUR|GBP|AED|SAR|JPY|CAD|AUD|SGD|MYR|NZD|CHF|RUB|[₹\$€£¥₽])\s*([\d\s,]+(?:\.\d{1,2})?)|([\d\s,]+(?:\.\d{1,2})?)\s*(?:RUB|руб\.?|р\.?|[₹\$€£¥₽]))',
      caseSensitive: false);
  static final bareAmountRegex = RegExp(r'\b(?:of|amt|amount|sum)\s+([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);

  static RegExp buildPreferredAmountRegex(String currency) {
    final escaped = RegExp.escape(currency.trim());
    return RegExp(
      r'(?:' + escaped + r'\s*([\d\s,]+(?:\.\d{1,2})?)|([\d\s,]+(?:\.\d{1,2})?)\s*' + escaped + r')',
      caseSensitive: false,
    );
  }

  static final posMerchantRegex = RegExp(
      r"\b(?:POS|ECOM|AUTH|MERCHANT)[\s/:\-]+(?:\d+[\s/:\-]+)?([A-Za-z\u0400-\u04FF][A-Za-z0-9\u0400-\u04FF\s&'\-\.]{1,60}?)(?=\s*(?:[,.\n]|$|\bref\b|\bauth\b|\bbal\b|\bon\b|\bvia\b))",
      caseSensitive: false);
  static final vpaMerchantRegex = RegExp(
      r"\b(?:VPA|UPI(?:\s*ID)?|to)\s*[:/]?\s*([a-zA-Z0-9.\-_]{2,30})@",
      caseSensitive: false);
  static final quotedMerchantRegex = RegExp(
      r'(?:at|to|for|from|merchant)\s*["\u201C\u2018\u0027]([A-Za-z0-9\u0400-\u04FF\s&\u0027\-\.]{2,60}?)["\u201D\u2019\u0027]',
      caseSensitive: false);

  static final depositRegex = RegExp(r'\b(deposit(?:ed)?|crm\s+deposit|cash\s+deposit|deposit\s+from|digital\s+banking\s+credit)\b', caseSensitive: false);
  static final purchaseRegex = RegExp(r'\b(purchase(?:d)?|authorised|authorized)\b', caseSensitive: false);
  static final instalmentRegex = RegExp(r'\b(instalment|installment|emi|monthly\s+payment)\b', caseSensitive: false);
  static final dueReminderRegex = RegExp(r'\b(due\s+tomorrow|due\s+today|due\s+in\s+\d+|payment\s+is\s+due|is\s+due\s+on|total\s+due|minimum\s+due|min\s+due)\b', caseSensitive: false);
  static final withdrawalRegex = RegExp(r'\b(withdrawn|withdrawal|atm\s+withdrawal|atm\s+debit)\b', caseSensitive: false);
  static final transferRegex = RegExp(r'\b(transfer|digital-transfer|digital\s*transfer|fund\s*transfer|wire\s*transfer|inter\s*bank\s*transfer|transferred(?:\s+to)?|transferred(?:\s+from)?|tfr|trf|cefts|ib\s*cefts)\b', caseSensitive: false);
  static final debitRegex = RegExp(
      r'(?:\b(debit(?:ed)?|withdrawn|withdrawal|spent|charged|purchase(?:d)?|authorised|authorized|approved|payment(?:\s+of)?|deduct(?:ed)?|paid|digital-transfer|transfer\s+to|attempted|txn\s+of|trf\s+of)\b|(?<![a-zA-Z0-9\u0400-\u04FF])(покупка|оплата|списание|снятие)(?![a-zA-Z0-9\u0400-\u04FF]))',
      caseSensitive: false);
  static final creditRegex = RegExp(
      r'(?:\b(credit(?:ed)?|credit\s+for|credit\s+of|received|received\s+from|deposited|deposit|deposit\s+from|transfer\s+from|transferred\s+from|transferred\s+to\s+you|credited\s+to|salary|salary\s+credited|payment\s+received|incoming\s+transfer|cash\s+deposit|profit\s+credited)\b|(?<![a-zA-Z0-9\u0400-\u04FF])(зачисление|пополнение|зарплата|перевод\s+от)(?![a-zA-Z0-9\u0400-\u04FF]))',
      caseSensitive: false);
  static final inwardTransferRegex = RegExp(r'\b(transfer\s+from|transferred\s+from|received\s+from|deposit\s+from|credited\s+from|sent\s+you)\b', caseSensitive: false);
  static final selfTransferRegex = RegExp(r'\b(transfer\s+to\s+own\s+account|transfer\s+to\s+own|transfer\s+to\s+savings|transfer\s+from\s+savings|transfer\s+to\s+combank|transfer\s+to\s+self|internal\s+transfer|self\s+transfer|transfer\s+to\s+saadh|to:\s*saadh|to\s+saadh|saadh\s+com|saadh\s+tab|credit\s+card\s+payment|card\s+settlement|payment\s+towards\s+card)\b', caseSensitive: false);
  static final reversalRegex = RegExp(r'\b(reversal|reversed|refund(?:ed)?|chargeback|credit\s+back|amount\s+refunded|money\s+returned|returned\s+to\s+your\s+card|reversed\s+back)\b', caseSensitive: false);
  static final cancellationRegex = RegExp(r'\b(cancelled|cancellation|transaction\s+failed|declined|not\s+processed|unsuccessful)\b', caseSensitive: false);
  static final promotionalRegex = RegExp(
      r'\b(offer|offers|dining\s+offer|discount|discounts|promo|exclusive|earn\s+\d+\s+points|cashback|cash\s*back|get\s+\d+%|voucher|reward\s+point|apply\s+now|eligible|eligible\s+for|loan\s+up\s+to|credit\s+limit\s+(?:increase|enhancement)|special\s+deal|enjoy\s+(?:up\s+to|\d+%)|subscribe|deal\s+at|deals\s+at|save\s+up\s+to|valid\s+(?:till|until|on)|when\s+you\s+spend|on\s+spend\s+of|on\s+minimum\s+spend|purchases?\s+(?:above|over|exceeding)|buy\s+1\s+get\s+1|bogo|pre-approved|use\s+coupon|use\s+promo(?:\s+code)?\s+[A-Za-z0-9]+|coupon\s+code\s+[A-Za-z0-9]+|promo\s+code\s+[A-Za-z0-9]+)\b',
      caseSensitive: false);
  static final otpRegex = RegExp(
      r'\b(otp|verification\s+code|v-code|one\s+time\s+password|secret\s+code|do\s+not\s+share|use\s+code\s+\d+|pin\s+code)\b',
      caseSensitive: false);
  static final executedTransactionRegex = RegExp(
      r'\b(has\s+been\s+debited|has\s+been\s+authori[sz]ed|debited\s+(?:for|with|by|from)|was\s+charged|charged\s+for|txn\s+of\s+.*approved|paid\s+to|withdrawn\s+from|purchase\s+of\s+.*successful|payment\s+to\s+.*successful|debited\s+to|credited\s+with|deposited\s+to|received\s+from|transfer\s+successful)\b',
      caseSensitive: false);
  
  static final piiCardRegex = RegExp(r'\*\d{4,}|ending\s+[#\*]?\d{4,}|\bno\.?\s*\d{4,}|\ba\/c\s*[\d*x]+|\bxxxx\d{4,}|\b\d{16}\b|\b\d{4,}\*+\d{4,}\b', caseSensitive: false);
  static final piiRefRegex = RegExp(r'\bref(?:\s*no\.?)?\s*:?\s*[\w\d]+|\btxn(?:\s*id)?\s*:?\s*[\w\d]+|\bauth(?:\s*code)?\s*:?\s*[\w\d]+|\btran\s*id\s*:?\s*[\w\d]+|\border\s+id\s*:?\s*[\w\d]+|\border\s*#?\s*[\d]+|\bcode\s*\d+|\b(?=[A-Za-z0-9]*\d)[A-Za-z0-9]{10,}\b', caseSensitive: false);
  static final piiBalanceRegex = RegExp(r'avl\s*bal[^\d]*[\d,]+(?:\.\d{1,2})?|avail?(?:able)?\s*bal(?:ance)?\s*:?\s*(?:lkr|rs\.?)?\s*[\d,]+(?:\.\d{1,2})?|\bbal\s*:?\s*(?:lkr|rs\.?)?\s*[\d,]+(?:\.\d{1,2})?|(?:баланс|остаток)\s*:?\s*[\d\s,]+(?:\.\d{1,2})?\s*(?:р\.?|руб\.?|rub|₽)?', caseSensitive: false);
  static final piiDateTimePhoneRegex = RegExp(r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b|\b\d{1,2}:\d{2}\s*(?:[ap]m)?\b|\b0\d{9}\b|\b\d{10,11}\b', caseSensitive: false);
  static final urlRegex = RegExp(r'https?://\S+', caseSensitive: false);
  static final noiseWordsRegex = RegExp(r'\b(?:your|has\s+before|has\s+been|dear|valued|customer|card|account|transaction|bank|balance|available|avl|bal|via|the|please|contact|call|if\s+not\s+you|do\s+not\s+share|cardholder|attempted|use\s+code|to\s+approve|within)\b', caseSensitive: false);

  static const reversalSentinel = '__reversal__';
}

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

class AppConstants {
  static const String repoUrl = 'https://github.com/SaadhJawwadh/Note-taking';
  static const String releaseUrl = '$repoUrl/releases';

  static const List<CurrencyInfo> curatedCurrencies = [
    CurrencyInfo(code: 'LKR', symbol: 'Rs.', name: 'Sri Lankan Rupee'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar'),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro'),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound'),
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
    CurrencyInfo(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal'),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
    CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
    CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
    CurrencyInfo(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar'),
    CurrencyInfo(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    CurrencyInfo(code: 'RUB', symbol: '₽', name: 'Russian Ruble'),
  ];

  static List<String> get currencies =>
      curatedCurrencies.map((c) => c.code).toList();

  static CurrencyInfo getCurrencyInfo(String code) {
    final clean = code.trim().toUpperCase();
    return curatedCurrencies.firstWhere(
      (c) =>
          c.code.toUpperCase() == clean ||
          c.symbol.toUpperCase() == clean,
      orElse: () => CurrencyInfo(
        code: clean,
        symbol: code.trim(),
        name: clean,
      ),
    );
  }
}

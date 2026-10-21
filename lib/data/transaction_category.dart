import 'package:flutter/material.dart';
import 'category_definition.dart';
import '../features/finances/data/transaction_repository.dart';
import 'category_constants.dart';

class TransactionCategory {
  TransactionCategory._();

  static const String other = CategoryConstants.other;
  static const List<String> all = CategoryConstants.all;
  static const Map<String, List<String>> keywords = CategoryConstants.keywords;
  static const Map<String, Color> badgeColors = CategoryConstants.badgeColors;

  static bool _matches(String desc, String kw) {
    return RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false).hasMatch(desc);
  }

  static String fromDescription(String description) {
    final desc = description.toLowerCase();
    final compounds = <(String, String)>[];
    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        if (kw.contains(' ')) compounds.add((kw, entry.key));
      }
    }
    compounds.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final (kw, cat) in compounds) {
      if (_matches(desc, kw)) return cat;
    }
    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        if (!kw.contains(' ') && _matches(desc, kw)) return entry.key;
      }
    }
    return other;
  }

  static List<CategoryDefinition> _cache = [];

  static Future<void> reload() async {
    _cache = await TransactionRepository.instance.getAllCategoryDefinitions();
  }

  static List<String> get allNames => _cache.isNotEmpty ? _cache.map((c) => c.name).toList() : all;

  static String fromDescriptionCached(String description) {
    if (_cache.isEmpty) return fromDescription(description);
    final desc = description.toLowerCase();
    final compounds = <(String, String)>[];
    for (final cat in _cache) {
      for (final kw in cat.keywords) {
        if (kw.contains(' ')) compounds.add((kw, cat.name));
      }
    }
    compounds.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    for (final (kw, name) in compounds) {
      if (_matches(desc, kw)) return name;
    }
    for (final cat in _cache) {
      for (final kw in cat.keywords) {
        if (!kw.contains(' ') && _matches(desc, kw)) return cat.name;
      }
    }
    return other;
  }

  static Color colorFor(String category) {
    if (_cache.isNotEmpty) {
      for (final def in _cache) {
        if (def.name == category) return Color(def.colorValue);
      }
    }
    return badgeColors[category] ?? const Color(0xFF9E9E9E);
  }

  static const List<IconData> swatches = [
    // Food & Dining
    Icons.restaurant_outlined,
    Icons.local_cafe_outlined,
    Icons.fastfood_outlined,
    Icons.local_bar_outlined,
    Icons.bakery_dining_outlined,
    Icons.local_pizza_outlined,

    // Groceries & Shopping
    Icons.local_grocery_store_outlined,
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.card_giftcard_outlined,
    Icons.storefront_outlined,

    // Transportation & Travel
    Icons.directions_car_outlined,
    Icons.local_gas_station_outlined,
    Icons.directions_bus_outlined,
    Icons.subway_outlined,
    Icons.local_taxi_outlined,
    Icons.flight_outlined,
    Icons.commute_outlined,

    // Bills, Utilities & Living
    Icons.home_outlined,
    Icons.power_outlined,
    Icons.water_drop_outlined,
    Icons.wifi_outlined,
    Icons.phone_android_outlined,
    Icons.tv_outlined,
    Icons.build_outlined,

    // Finance & Wealth
    Icons.payment_outlined,
    Icons.savings_outlined,
    Icons.account_balance_outlined,
    Icons.currency_exchange_outlined,
    Icons.trending_up_outlined,
    Icons.receipt_long_outlined,
    Icons.credit_card_outlined,

    // Health, Wellness & Personal Care
    Icons.medical_services_outlined,
    Icons.medication_outlined,
    Icons.fitness_center_outlined,
    Icons.spa_outlined,
    Icons.content_cut_outlined,

    // Entertainment & Leisure
    Icons.subscriptions_outlined,
    Icons.sports_esports_outlined,
    Icons.movie_outlined,
    Icons.music_note_outlined,
    Icons.theater_comedy_outlined,

    // Family, Education & Work
    Icons.school_outlined,
    Icons.work_outlined,
    Icons.laptop_mac_outlined,
    Icons.computer_outlined,
    Icons.child_friendly_outlined,
    Icons.pets_outlined,
    Icons.volunteer_activism_outlined,
    Icons.category_outlined,
  ];

  static Map<int, IconData>? _knownIconsCache;
  static Map<int, IconData> get _knownIcons {
    return _knownIconsCache ??= {
      for (final icon in swatches) icon.codePoint: icon,
    };
  }

  static IconData iconFor(String category) {
    if (_cache.isNotEmpty) {
      for (final def in _cache) {
        if (def.name == category && def.iconCodePoint != null) {
          final known = _knownIcons[def.iconCodePoint!];
          if (known != null) return known;
        }
      }
    }
    switch (category.toLowerCase()) {
      case 'transport':
      case 'commute':
        return Icons.directions_car_outlined;
      case 'food & dining':
      case 'food':
        return Icons.restaurant_outlined;
      case 'subscriptions':
        return Icons.subscriptions_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'utilities':
      case 'bills':
        return Icons.power_outlined;
      case 'health':
      case 'medical':
        return Icons.medical_services_outlined;
      case 'entertainment':
      case 'leisure':
        return Icons.sports_esports_outlined;
      case 'payments':
      case 'loans':
        return Icons.payment_outlined;
      case 'deposit':
      case 'income':
      case 'salary':
        return Icons.savings_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'housing':
      case 'home':
        return Icons.home_outlined;
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'groceries':
        return Icons.local_grocery_store_outlined;
      case 'transfer':
      case 'saving':
        return Icons.swap_horiz_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  static String localizedName(BuildContext context, String category) {
    try {
      final lang = Localizations.localeOf(context).languageCode;
      if (lang == 'ru') {
        switch (category.toLowerCase()) {
          case 'food & dining':
          case 'food':
            return 'Еда и рестораны';
          case 'transport':
          case 'commute':
            return 'Транспорт';
          case 'groceries':
            return 'Продукты';
          case 'shopping':
            return 'Покупки';
          case 'utilities':
          case 'bills':
            return 'Коммунальные';
          case 'subscriptions':
            return 'Подписки';
          case 'health':
          case 'medical':
            return 'Здоровье';
          case 'entertainment':
          case 'leisure':
            return 'Развлечения';
          case 'deposit':
          case 'income':
          case 'salary':
            return 'Доход';
          case 'transfer':
          case 'saving':
            return 'Переводы';
          case 'education':
            return 'Образование';
          case 'travel':
            return 'Путешествия';
          case 'housing':
          case 'home':
            return 'Жилье';
          case 'fitness':
            return 'Фитнес';
          case 'payments':
          case 'loans':
            return 'Платежи';
          case 'other':
            return 'Другое';
          default:
            return category;
        }
      }
    } catch (_) {}
    return category;
  }
}

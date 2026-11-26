import 'package:flutter/material.dart';
import '../../../../data/database_constants.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';

typedef SavingsGoal = SavingsGoalModel;

class SavingsGoalModel {
  static const List<IconData> defaultIcons = [
    // Savings & Financial Vault
    Icons.savings_rounded,
    Icons.account_balance_rounded,
    Icons.wallet_rounded,
    Icons.paid_rounded,
    Icons.trending_up_rounded,
    Icons.shield_rounded,

    // Travel & Adventure
    Icons.flight_takeoff_rounded,
    Icons.beach_access_rounded,
    Icons.luggage_rounded,
    Icons.explore_rounded,
    Icons.hiking_rounded,
    Icons.hotel_rounded,

    // Tech, Gadgets & Creative
    Icons.smartphone_rounded,
    Icons.laptop_mac_rounded,
    Icons.tablet_mac_rounded,
    Icons.headphones_rounded,
    Icons.videogame_asset_rounded,
    Icons.photo_camera_rounded,
    Icons.watch_rounded,
    Icons.tv_rounded,

    // Vehicles & Mobility
    Icons.directions_car_rounded,
    Icons.two_wheeler_rounded,
    Icons.directions_bike_rounded,
    Icons.electric_car_rounded,
    Icons.car_rental_rounded,

    // Home, Living & Family
    Icons.home_rounded,
    Icons.chair_rounded,
    Icons.kitchen_rounded,
    Icons.construction_rounded,
    Icons.bed_rounded,
    Icons.child_friendly_rounded,

    // Education, Milestones & Celebrations
    Icons.school_rounded,
    Icons.menu_book_rounded,
    Icons.workspace_premium_rounded,
    Icons.redeem_rounded,
    Icons.favorite_rounded,
    Icons.cake_rounded,
    Icons.celebration_rounded,

    // Health, Fitness & Wellness
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.medical_services_rounded,
    Icons.sports_soccer_rounded,
  ];

  static IconData getIcon(int codePoint) {
    for (final icon in defaultIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    for (final icon in TransactionCategory.swatches) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.savings_rounded;
  }
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final int targetMonths;
  final double monthlyContribution;
  final String category;
  final String account;
  final int colorValue;
  final int iconCodePoint;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  const SavingsGoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.targetMonths = 6,
    this.monthlyContribution = 0.0,
    this.category = 'Savings',
    this.account = AccountType.savings,
    this.colorValue = 0xFF00796B,
    this.iconCodePoint = 0xe57f, // Icons.savings_rounded
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.deletedAt,
  });

  double get progressRatio {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressRatio * 100).round();

  double get remainingAmount {
    final rem = targetAmount - currentAmount;
    return rem > 0 ? rem : 0.0;
  }

  double get effectiveMonthlyPace {
    if (remainingAmount <= 0) return 0.0;
    if (targetDate != null) {
      final now = DateTime.now();
      final diffDays = targetDate!.difference(now).inDays;
      final monthsRemaining = (diffDays / 30.44).ceil();
      if (monthsRemaining > 0) {
        return remainingAmount / monthsRemaining;
      }
      return remainingAmount;
    }
    if (targetMonths > 0) {
      return remainingAmount / targetMonths;
    }
    return monthlyContribution > 0 ? monthlyContribution : remainingAmount;
  }

  int get estimatedMonthsRemaining {
    if (remainingAmount <= 0) return 0;
    final pace = monthlyContribution > 0 ? monthlyContribution : effectiveMonthlyPace;
    if (pace <= 0) return 1;
    return (remainingAmount / pace).ceil();
  }

  int get milestoneTier {
    final pct = progressPercent;
    if (pct >= 100) return 4;
    if (pct >= 75) return 3;
    if (pct >= 50) return 2;
    if (pct >= 25) return 1;
    return 0;
  }

  String get milestoneLabel {
    switch (milestoneTier) {
      case 4:
        return 'Completed!';
      case 3:
        return 'Almost there!';
      case 2:
        return 'Halfway';
      case 1:
        return 'Quarterway';
      default:
        return '';
    }
  }

  SavingsGoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    int? targetMonths,
    double? monthlyContribution,
    String? category,
    String? account,
    int? colorValue,
    int? iconCodePoint,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? deletedAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      targetMonths: targetMonths ?? this.targetMonths,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      category: category ?? this.category,
      account: account ?? this.account,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      SavingsGoalFields.id: id,
      SavingsGoalFields.title: title,
      SavingsGoalFields.targetAmount: targetAmount,
      SavingsGoalFields.currentAmount: currentAmount,
      SavingsGoalFields.targetDate: targetDate?.toIso8601String(),
      SavingsGoalFields.targetMonths: targetMonths,
      SavingsGoalFields.monthlyContribution: monthlyContribution,
      SavingsGoalFields.category: category,
      SavingsGoalFields.account: account,
      SavingsGoalFields.colorValue: colorValue,
      SavingsGoalFields.iconCodePoint: iconCodePoint,
      SavingsGoalFields.isCompleted: isCompleted ? 1 : 0,
      SavingsGoalFields.createdAt: createdAt.toIso8601String(),
      SavingsGoalFields.completedAt: completedAt?.toIso8601String(),
      SavingsGoalFields.deletedAt: deletedAt?.toIso8601String(),
    };
  }

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map) {
    return SavingsGoalModel(
      id: map[SavingsGoalFields.id] as String,
      title: map[SavingsGoalFields.title] as String? ?? '',
      targetAmount: (map[SavingsGoalFields.targetAmount] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map[SavingsGoalFields.currentAmount] as num?)?.toDouble() ?? 0.0,
      targetDate: map[SavingsGoalFields.targetDate] != null
          ? DateTime.tryParse(map[SavingsGoalFields.targetDate] as String)
          : null,
      targetMonths: (map[SavingsGoalFields.targetMonths] as num?)?.toInt() ?? 6,
      monthlyContribution: (map[SavingsGoalFields.monthlyContribution] as num?)?.toDouble() ?? 0.0,
      category: map[SavingsGoalFields.category] as String? ?? 'Savings',
      account: map[SavingsGoalFields.account] as String? ?? AccountType.savings,
      colorValue: (map[SavingsGoalFields.colorValue] as num?)?.toInt() ?? 0xFF00796B,
      iconCodePoint: (map[SavingsGoalFields.iconCodePoint] as num?)?.toInt() ?? 0xe57f,
      isCompleted: (map[SavingsGoalFields.isCompleted] as int? ?? 0) == 1,
      createdAt: map[SavingsGoalFields.createdAt] != null
          ? DateTime.tryParse(map[SavingsGoalFields.createdAt] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map[SavingsGoalFields.completedAt] != null
          ? DateTime.tryParse(map[SavingsGoalFields.completedAt] as String)
          : null,
      deletedAt: map[SavingsGoalFields.deletedAt] != null
          ? DateTime.tryParse(map[SavingsGoalFields.deletedAt] as String)
          : null,
    );
  }
}

import 'package:flutter/widgets.dart';

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.storeId,
    required this.storeName,
    this.merchantName = '',
    required this.storeAddress,
    required this.businessHours,
    required this.businessWeekdays,
    required this.contactPhone,
    required this.price,
    required this.category,
    required this.tags,
    required this.ingredients,
    required this.nutritionTags,
    required this.calories,
    required this.weightGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.distanceMeters,
    required this.stockCount,
    required this.ecoPriorityScore,
    required this.recommendationReason,
    required this.imageUrl,
    required this.icon,
    this.specialLabel,
    this.originalPrice,
    this.discountLabel,
    this.expiresAt,
    this.isExpiringSoon = false,
    this.isFavorite = false,
    this.storeBrand,
    this.hasDistance = true,
  });

  final String id;
  final String name;
  final String storeId;
  final String storeName;
  final String merchantName;
  final String storeAddress;
  final String businessHours;
  final List<int> businessWeekdays;
  final String contactPhone;
  final int price;
  final int? originalPrice;
  final String? discountLabel;
  final String category;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> nutritionTags;
  final int calories;
  final int weightGrams;
  final int proteinGrams;
  final int fatGrams;
  final int carbsGrams;
  final int distanceMeters;
  final int stockCount;
  final DateTime? expiresAt;
  final bool isExpiringSoon;
  final double ecoPriorityScore;
  final String recommendationReason;
  final String imageUrl;
  final IconData icon;
  final String? specialLabel;
  final bool isFavorite;
  final String? storeBrand;
  final bool hasDistance;

  String get priceLabel => 'NT\$ $price';

  String get caloriesLabel => '$calories kcal';

  String get weightLabel => '$weightGrams g';

  String get proteinLabel => '$proteinGrams g';

  String get fatLabel => '$fatGrams g';

  String get carbsLabel => '$carbsGrams g';

  String get businessWeekdaysLabel {
    if (businessWeekdays.length == 7) {
      return '每日營業';
    }

    const weekdayLabels = {
      DateTime.monday: '週一',
      DateTime.tuesday: '週二',
      DateTime.wednesday: '週三',
      DateTime.thursday: '週四',
      DateTime.friday: '週五',
      DateTime.saturday: '週六',
      DateTime.sunday: '週日',
    };

    final sortedWeekdays = [...businessWeekdays]..sort();
    return sortedWeekdays
        .map((weekday) => weekdayLabels[weekday])
        .whereType<String>()
        .join('、');
  }

  String get businessScheduleLabel => '$businessWeekdaysLabel $businessHours';

  bool isOpenOn(DateTime date) {
    return businessWeekdays.contains(date.weekday);
  }

  String get distanceLabel {
    if (!hasDistance) return '距離未提供';
    if (distanceMeters >= 1000) {
      final kilometers = distanceMeters / 1000;
      return '距離 ${kilometers.toStringAsFixed(1)} 公里';
    }

    return '距離 $distanceMeters 公尺';
  }

  String get timeLeftLabel {
    if (expiresAt == null) {
      return '無保存期限資料';
    }

    final remaining = expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) {
      return '已逾期';
    }

    final hours = remaining.inHours;
    if (hours >= 1) {
      return '剩 $hours 小時';
    }

    final minutes = remaining.inMinutes.clamp(1, 59);
    return '剩 $minutes 分鐘';
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? storeId,
    String? storeName,
    String? merchantName,
    String? storeAddress,
    String? businessHours,
    List<int>? businessWeekdays,
    String? contactPhone,
    int? price,
    int? originalPrice,
    String? discountLabel,
    String? category,
    List<String>? tags,
    List<String>? ingredients,
    List<String>? nutritionTags,
    int? calories,
    int? weightGrams,
    int? proteinGrams,
    int? fatGrams,
    int? carbsGrams,
    int? distanceMeters,
    int? stockCount,
    DateTime? expiresAt,
    bool? isExpiringSoon,
    double? ecoPriorityScore,
    String? recommendationReason,
    String? imageUrl,
    IconData? icon,
    String? specialLabel,
    bool? isFavorite,
    String? storeBrand,
    bool? hasDistance,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      merchantName: merchantName ?? this.merchantName,
      storeAddress: storeAddress ?? this.storeAddress,
      businessHours: businessHours ?? this.businessHours,
      businessWeekdays: businessWeekdays ?? this.businessWeekdays,
      contactPhone: contactPhone ?? this.contactPhone,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountLabel: discountLabel ?? this.discountLabel,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      ingredients: ingredients ?? this.ingredients,
      nutritionTags: nutritionTags ?? this.nutritionTags,
      calories: calories ?? this.calories,
      weightGrams: weightGrams ?? this.weightGrams,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      stockCount: stockCount ?? this.stockCount,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpiringSoon: isExpiringSoon ?? this.isExpiringSoon,
      ecoPriorityScore: ecoPriorityScore ?? this.ecoPriorityScore,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      specialLabel: specialLabel ?? this.specialLabel,
      isFavorite: isFavorite ?? this.isFavorite,
      storeBrand: storeBrand ?? this.storeBrand,
      hasDistance: hasDistance ?? this.hasDistance,
    );
  }
}

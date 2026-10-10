import 'package:my_app/models/food_item.dart';

enum FoodSearchSortOption {
  recommended,
  nearest,
  lowestPrice,
  lowerCalories,
  highProtein,
  expiringFirst;

  String get label {
    return switch (this) {
      FoodSearchSortOption.recommended => '推薦優先',
      FoodSearchSortOption.nearest => '距離最近',
      FoodSearchSortOption.lowestPrice => '價格最低',
      FoodSearchSortOption.lowerCalories => '熱量較低',
      FoodSearchSortOption.highProtein => '高蛋白優先',
      FoodSearchSortOption.expiringFirst => '即期優惠優先',
    };
  }
}

class FoodSearchFilters {
  const FoodSearchFilters({
    this.categories = const {},
    this.tags = const {},
    this.maxPrice,
    this.maxDistanceMeters,
    this.expiringOnly = false,
  });

  final Set<String> categories;
  final Set<String> tags;
  final int? maxPrice;
  final int? maxDistanceMeters;
  final bool expiringOnly;

  String get summaryLabel {
    final labels = <String>[
      if (expiringOnly) '只看即期',
      ...categories,
      ...tags,
      if (maxPrice != null) '$maxPrice 元內',
      if (maxDistanceMeters != null) '$maxDistanceMeters 公尺內',
    ];

    return labels.join(' / ');
  }

  FoodSearchFilters copyWith({
    Set<String>? categories,
    Set<String>? tags,
    int? maxPrice,
    int? maxDistanceMeters,
    bool? expiringOnly,
    bool clearMaxPrice = false,
    bool clearMaxDistance = false,
  }) {
    return FoodSearchFilters(
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
      maxDistanceMeters: clearMaxDistance
          ? null
          : maxDistanceMeters ?? this.maxDistanceMeters,
      expiringOnly: expiringOnly ?? this.expiringOnly,
    );
  }
}

class FoodSearchService {
  const FoodSearchService();

  static const Map<String, Set<String>> _keywordAliases = {
    '甜點': {'甜點', '麵包甜點', '銅鑼燒', '點心'},
    '點心': {'點心', '甜點', '麵包甜點', '銅鑼燒'},
    '下午茶': {'下午茶', '甜點', '麵包甜點', '銅鑼燒'},
    '麵包': {'麵包', '麵包甜點'},
    '飲料': {'飲料', '飲品', '果汁', '茶'},
    '喝的': {'喝的', '飲品', '果汁', '茶'},
    '麵': {'麵', '麵食', '烏龍'},
    '早餐': {'早餐', '飯糰', '麵包甜點'},
    '午餐': {'午餐', '便當', '餐盒', '麵食', '飯糰'},
    '晚餐': {'晚餐', '便當', '餐盒', '麵食'},
    '正餐': {'正餐', '便當', '餐盒', '麵食'},
    '蔬菜': {'蔬菜', '鮮蔬', '沙拉'},
    '健康': {'健康', '沙拉', '低脂', '低熱量', '蔬食'},
    '減脂': {'減脂', '低脂', '低熱量', '沙拉'},
    '健身': {'健身', '高蛋白', '雞胸'},
    '素食': {'素食', '蔬食'},
  };

  List<FoodItem> search({
    required List<FoodItem> foods,
    String query = '',
    FoodSearchFilters filters = const FoodSearchFilters(),
    FoodSearchSortOption sortOption = FoodSearchSortOption.recommended,
  }) {
    final keyword = query.trim().toLowerCase();

    final results = foods.where((food) {
      if (keyword.isNotEmpty && !_matchesKeyword(food, keyword)) {
        return false;
      }

      if (filters.categories.isNotEmpty &&
          !filters.categories.contains(food.category)) {
        return false;
      }

      if (filters.tags.isNotEmpty &&
          !filters.tags.any((tag) => food.tags.contains(tag))) {
        return false;
      }

      if (filters.maxPrice != null && food.price > filters.maxPrice!) {
        return false;
      }

      if (filters.maxDistanceMeters != null &&
          food.distanceMeters > filters.maxDistanceMeters!) {
        return false;
      }

      if (filters.expiringOnly && !food.isExpiringSoon) {
        return false;
      }

      return true;
    }).toList();

    results.sort((a, b) => _compareFoods(a, b, sortOption));

    return results;
  }

  int _compareFoods(FoodItem a, FoodItem b, FoodSearchSortOption sortOption) {
    return switch (sortOption) {
      FoodSearchSortOption.recommended => _compareRecommended(a, b),
      FoodSearchSortOption.nearest => a.distanceMeters.compareTo(
        b.distanceMeters,
      ),
      FoodSearchSortOption.lowestPrice => _thenByDistance(
        a.price.compareTo(b.price),
        a,
        b,
      ),
      FoodSearchSortOption.lowerCalories => _thenByDistance(
        a.calories.compareTo(b.calories),
        a,
        b,
      ),
      FoodSearchSortOption.highProtein => _thenByDistance(
        b.proteinGrams.compareTo(a.proteinGrams),
        a,
        b,
      ),
      FoodSearchSortOption.expiringFirst => _thenByDistance(
        _compareExpiring(a, b),
        a,
        b,
      ),
    };
  }

  int _compareRecommended(FoodItem a, FoodItem b) {
    final ecoCompare = b.ecoPriorityScore.compareTo(a.ecoPriorityScore);
    if (ecoCompare != 0) {
      return ecoCompare;
    }

    return a.distanceMeters.compareTo(b.distanceMeters);
  }

  int _compareExpiring(FoodItem a, FoodItem b) {
    final expiringCompare = (b.isExpiringSoon ? 1 : 0).compareTo(
      a.isExpiringSoon ? 1 : 0,
    );
    if (expiringCompare != 0) {
      return expiringCompare;
    }

    final expiryA = a.expiresAt;
    final expiryB = b.expiresAt;
    if (expiryA != null && expiryB != null) {
      return expiryA.compareTo(expiryB);
    }

    return b.ecoPriorityScore.compareTo(a.ecoPriorityScore);
  }

  int _thenByDistance(int primaryCompare, FoodItem a, FoodItem b) {
    if (primaryCompare != 0) {
      return primaryCompare;
    }

    return a.distanceMeters.compareTo(b.distanceMeters);
  }

  bool _matchesKeyword(FoodItem food, String keyword) {
    final searchableText = [
      food.name,
      food.merchantName,
      food.category,
      ...food.tags,
      ...food.ingredients,
      ...food.nutritionTags,
    ].join(' ').toLowerCase();

    final tokens = keyword
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    return tokens.every((token) {
      final candidates = _keywordAliases[token] ?? {token};
      return candidates.any(searchableText.contains);
    });
  }
}

import 'dart:math';

import 'package:my_app/models/food_item.dart';
import 'package:my_app/services/food_search_service.dart';

class FoodWheelService {
  const FoodWheelService({this.searchService = const FoodSearchService()});

  final FoodSearchService searchService;

  List<FoodItem> getCandidates({
    required List<FoodItem> foods,
    FoodSearchFilters filters = const FoodSearchFilters(),
    DateTime? now,
  }) {
    if (!_hasActiveFilters(filters)) {
      return const [];
    }

    final today = now ?? DateTime.now();
    return searchService
        .search(foods: foods, filters: filters)
        .where((food) => food.isOpenAt(today))
        .toList();
  }

  FoodItem? spin({required List<FoodItem> candidates, Random? random}) {
    return spinByCategory(candidates: candidates, random: random)?.food;
  }

  WheelSpinResult? spinByCategory({
    required List<FoodItem> candidates,
    Random? random,
  }) {
    final categories = getCandidateCategories(candidates);
    if (categories.isEmpty) {
      return null;
    }

    final randomSource = random ?? Random();
    final category = categories[randomSource.nextInt(categories.length)];
    final categoryCandidates = getCandidatesByCategory(candidates, category);
    final food =
        categoryCandidates[randomSource.nextInt(categoryCandidates.length)];

    return WheelSpinResult(
      category: category,
      food: food,
      categoryCandidates: categoryCandidates,
    );
  }

  List<String> getCandidateCategories(List<FoodItem> candidates) {
    final categories = candidates.map((food) => food.category).toSet().toList()
      ..sort();
    return List.unmodifiable(categories);
  }

  List<FoodItem> getCandidatesByCategory(
    List<FoodItem> candidates,
    String category,
  ) {
    return List.unmodifiable(
      candidates.where((food) => food.category == category),
    );
  }

  bool _hasActiveFilters(FoodSearchFilters filters) {
    return filters.categories.isNotEmpty ||
        filters.tags.isNotEmpty ||
        filters.maxPrice != null ||
        filters.maxDistanceMeters != null ||
        filters.expiringOnly;
  }
}

class WheelSpinResult {
  const WheelSpinResult({
    required this.category,
    required this.food,
    required this.categoryCandidates,
  });

  final String category;
  final FoodItem food;
  final List<FoodItem> categoryCandidates;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/services/food_search_service.dart';

void main() {
  const service = FoodSearchService();

  test('search matches food name, merchant, tag, and ingredient text', () {
    final foods = MockFoodRepository.allFoods;

    expect(
      service.search(foods: foods, query: '雞胸').map((food) => food.name),
      contains('舒肥雞胸餐盒'),
    );
    expect(
      service.search(foods: foods, query: '晨光').map((food) => food.name),
      isNotEmpty,
    );
    expect(
      service.search(foods: foods, query: '低脂').map((food) => food.name),
      isNotEmpty,
    );
  });

  test('filters by category, budget, distance, and expiring status', () {
    final results = service.search(
      foods: MockFoodRepository.allFoods,
      filters: const FoodSearchFilters(
        categories: {'便當'},
        maxPrice: 100,
        maxDistanceMeters: 300,
        expiringOnly: true,
      ),
    );

    expect(results, isNotEmpty);
    expect(results.every((food) => food.category == '便當'), isTrue);
    expect(results.every((food) => food.price <= 100), isTrue);
    expect(results.every((food) => food.distanceMeters <= 300), isTrue);
    expect(results.every((food) => food.isExpiringSoon), isTrue);
  });

  test('sorts search results by distance', () {
    final results = service.search(
      foods: MockFoodRepository.allFoods,
      sortOption: FoodSearchSortOption.nearest,
    );

    expect(results, isNotEmpty);
    for (var index = 1; index < results.length; index += 1) {
      expect(
        results[index - 1].distanceMeters <= results[index].distanceMeters,
        isTrue,
      );
    }
  });

  test('sorts search results by lowest price', () {
    final results = service.search(
      foods: MockFoodRepository.allFoods,
      sortOption: FoodSearchSortOption.lowestPrice,
    );

    expect(results, isNotEmpty);
    for (var index = 1; index < results.length; index += 1) {
      expect(results[index - 1].price <= results[index].price, isTrue);
    }
  });

  test('sorts search results by calories and protein', () {
    final lowerCalories = service.search(
      foods: MockFoodRepository.allFoods,
      sortOption: FoodSearchSortOption.lowerCalories,
    );
    final highProtein = service.search(
      foods: MockFoodRepository.allFoods,
      sortOption: FoodSearchSortOption.highProtein,
    );

    expect(lowerCalories.first.calories <= lowerCalories.last.calories, isTrue);
    expect(
      highProtein.first.proteinGrams >= highProtein.last.proteinGrams,
      isTrue,
    );
  });

  test('sorts expiring foods before regular foods', () {
    final results = service.search(
      foods: MockFoodRepository.allFoods,
      sortOption: FoodSearchSortOption.expiringFirst,
    );

    expect(results, isNotEmpty);
    expect(results.first.isExpiringSoon, isTrue);
  });
}

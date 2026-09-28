import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/services/food_search_service.dart';
import 'package:my_app/services/food_wheel_service.dart';

void main() {
  const service = FoodWheelService();

  test('returns no candidates before setting wheel filters', () {
    final candidates = service.getCandidates(
      foods: MockFoodRepository.allFoods,
    );

    expect(candidates, isEmpty);
  });

  test('gets wheel candidates from search filters before spinning', () {
    final wednesday = DateTime(2026, 8, 26, 12);
    final candidates = service.getCandidates(
      foods: MockFoodRepository.allFoods,
      filters: const FoodSearchFilters(
        tags: {'低脂'},
        maxPrice: 150,
        maxDistanceMeters: 1000,
      ),
      now: wednesday,
    );

    expect(candidates, isNotEmpty);
    expect(candidates.every((food) => food.isOpenOn(wednesday)), isTrue);
    expect(candidates.every((food) => food.tags.contains('低脂')), isTrue);
    expect(candidates.every((food) => food.price <= 150), isTrue);
    expect(candidates.every((food) => food.distanceMeters <= 1000), isTrue);
  });

  test('excludes wheel candidates from stores closed today', () {
    final wednesday = DateTime(2026, 8, 26, 12);
    final closedFood = MockFoodRepository.allFoods.first.copyWith(
      tags: const ['測試標籤', '高蛋白'],
      businessWeekdays: const [DateTime.thursday],
    );
    final openFood = MockFoodRepository.allFoods[1].copyWith(
      tags: const ['測試標籤', '素食'],
      businessWeekdays: const [DateTime.wednesday],
    );

    final candidates = service.getCandidates(
      foods: [closedFood, openFood],
      filters: const FoodSearchFilters(tags: {'測試標籤'}),
      now: wednesday,
    );

    expect(candidates, [openFood]);
  });

  test('spin returns null when there are no candidates', () {
    final selectedFood = service.spin(candidates: const []);

    expect(selectedFood, isNull);
  });

  test(
    'spin picks a food from the provided candidate list without weighting',
    () {
      final candidates = MockFoodRepository.allFoods.take(4).toList();

      final selectedFood = service.spin(
        candidates: candidates,
        random: Random(3),
      );

      expect(candidates, contains(selectedFood));
    },
  );

  test('spin by category picks a category before selecting food', () {
    final candidates = MockFoodRepository.allFoods
        .where((food) => food.category == '便當' || food.category == '飯糰')
        .take(8)
        .toList();

    final result = service.spinByCategory(
      candidates: candidates,
      random: Random(4),
    );

    expect(result, isNotNull);
    expect(result!.food.category, result.category);
    expect(
      result.categoryCandidates.every(
        (food) => food.category == result.category,
      ),
      isTrue,
    );
  });
}

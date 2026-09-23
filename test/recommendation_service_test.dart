import 'package:my_app/models/food_feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/models/user_preference.dart';
import 'package:my_app/services/recommendation_service.dart';

void main() {
  final wednesday = DateTime(2026, 8, 26);

  test('mock repository contains 100 foods', () {
    expect(MockFoodRepository.allFoods, hasLength(100));
  });

  test('convenience expiring data follows distance limit', () {
    expect(
      MockFoodRepository.convenienceStoresByBrand(
        null,
        maxDistanceMeters: 1000,
      ),
      hasLength(7),
    );
    expect(
      MockFoodRepository.convenienceStoresByBrand(
        null,
        maxDistanceMeters: 1500,
      ),
      hasLength(9),
    );
    expect(
      MockFoodRepository.expiringFoodsByBrand(null, maxDistanceMeters: 1000),
      hasLength(20),
    );
    expect(
      MockFoodRepository.expiringFoodsByBrand(null, maxDistanceMeters: 1500),
      hasLength(26),
    );
  });

  test('mock foods have two to three preference tags', () {
    expect(
      MockFoodRepository.allFoods.every(
        (food) => food.tags.length >= 2 && food.tags.length <= 3,
      ),
      isTrue,
    );
  });

  test('mock foods have valid business weekdays', () {
    expect(
      MockFoodRepository.allFoods.every(
        (food) =>
            food.businessWeekdays.isNotEmpty &&
            food.businessWeekdays.every(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            ),
      ),
      isTrue,
    );
  });

  test(
    'recommendations keep open nearby foods under budget and include expiring items',
    () {
      const service = RecommendationService();

      final recommendations = service.getRecommendations(
        foods: MockFoodRepository.allFoods,
        preference: UserPreference.defaultPreference,
        now: wednesday,
      );

      expect(recommendations, isNotEmpty);
      expect(
        recommendations.every(
          (food) =>
              food.isOpenOn(wednesday) &&
              food.price <= UserPreference.defaultPreference.budgetMax &&
              food.distanceMeters <=
                  UserPreference.defaultPreference.distanceLimitMeters,
        ),
        isTrue,
      );
      expect(recommendations.any((food) => food.isExpiringSoon), isTrue);
    },
  );

  test(
    'recommendations prioritize foods matching selected preference tags',
    () {
      const service = RecommendationService();
      const vegetarianPreference = UserPreference(
        dietaryPreferences: ['素食'],
        budgetMin: 0,
        budgetMax: 200,
        distanceLimitMeters: 1500,
        preferredTags: ['素食'],
        avoidIngredients: [],
        wasteReductionEnabled: false,
      );

      final recommendations = service.getRecommendations(
        foods: MockFoodRepository.allFoods,
        preference: vegetarianPreference,
        now: wednesday,
      );

      expect(recommendations, isNotEmpty);
      expect(recommendations.first.tags, contains('素食'));
    },
  );

  test('score breakdown explains recommendation factors', () {
    const service = RecommendationService();
    final food = MockFoodRepository.allFoods.first;
    final score = service.scoreFood(food, UserPreference.defaultPreference);

    expect(score.totalPercent, inInclusiveRange(0, 100));
    expect(score.preferencePercent, inInclusiveRange(0, 100));
    expect(score.distancePercent, inInclusiveRange(0, 100));
    expect(score.budgetPercent, inInclusiveRange(0, 100));
    expect(score.ecoPercent, inInclusiveRange(0, 100));
    expect(score.feedbackPercent, inInclusiveRange(0, 100));
  });

  test('recommendations use food feedback as a ranking signal', () {
    const service = RecommendationService();
    final dislikedFood = MockFoodRepository.allFoods.first.copyWith(
      id: 'feedback-low',
      name: '低分餐點',
      price: 120,
      distanceMeters: 500,
      businessWeekdays: const [DateTime.wednesday],
    );
    final likedFood = MockFoodRepository.allFoods.first.copyWith(
      id: 'feedback-high',
      name: '高分餐點',
      price: 120,
      distanceMeters: 500,
      businessWeekdays: const [DateTime.wednesday],
    );

    final recommendations = service.getRecommendations(
      foods: [dislikedFood, likedFood],
      preference: UserPreference.defaultPreference,
      feedbackByFoodId: {
        dislikedFood.id: FoodFeedback(
          foodId: dislikedFood.id,
          rating: 1,
          tags: const ['不符合偏好'],
          createdAt: DateTime(2026, 8, 26),
        ),
        likedFood.id: FoodFeedback(
          foodId: likedFood.id,
          rating: 5,
          tags: const ['會再回購'],
          createdAt: DateTime(2026, 8, 26),
        ),
      },
      now: wednesday,
    );

    expect(recommendations.first.id, likedFood.id);
  });

  test('recommendations exclude foods closed on the selected date', () {
    const service = RecommendationService();
    final closedFood = MockFoodRepository.allFoods.first.copyWith(
      businessWeekdays: const [DateTime.thursday],
    );
    final openFood = MockFoodRepository.allFoods[1].copyWith(
      businessWeekdays: const [DateTime.wednesday],
    );

    final recommendations = service.getRecommendations(
      foods: [closedFood, openFood],
      preference: const UserPreference(
        dietaryPreferences: [],
        budgetMin: 0,
        budgetMax: 300,
        distanceLimitMeters: 3000,
        preferredTags: [],
        avoidIngredients: [],
        wasteReductionEnabled: false,
      ),
      now: wednesday,
    );

    expect(recommendations, [openFood]);
  });

  test('recommendations keep foods whose store distance is not provided', () {
    const service = RecommendationService();
    final unknownDistanceFood = MockFoodRepository.allFoods.first.copyWith(
      businessWeekdays: const [DateTime.wednesday],
      distanceMeters: 1000001,
      hasDistance: false,
    );

    final recommendations = service.getRecommendations(
      foods: [unknownDistanceFood],
      preference: UserPreference.defaultPreference,
      now: wednesday,
    );

    expect(recommendations, [unknownDistanceFood]);
    expect(
      service
          .scoreFood(unknownDistanceFood, UserPreference.defaultPreference)
          .distanceScore,
      0.5,
    );
  });
}

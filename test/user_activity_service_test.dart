import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = UserActivityService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.initialize();
    service.clearForTesting();
  });

  test('mock foods are not favorite by default', () {
    expect(
      MockFoodRepository.allFoods.every((food) => !food.isFavorite),
      isTrue,
    );
  });

  test(
    'switching members isolates favorites, history and purchase records',
    () async {
      final food = MockFoodRepository.allFoods.first;
      await service.switchAccount('api:member-a');
      service.toggleFavorite(food);
      service.addHistory(food);
      service.addToCart(food);
      service.checkoutCart();
      await service.switchAccount('api:member-b');
      expect(service.favorites, isEmpty);
      expect(service.history, isEmpty);
      expect(service.purchaseRecords, isEmpty);
      await service.switchAccount(null);
      expect(service.favorites, isEmpty);
      await service.switchAccount('api:member-a');
      expect(service.favorites.single.id, food.id);
      expect(service.purchaseRecords, hasLength(1));
      await service.switchAccount(null);
    },
  );

  test('mock foods include nutrition estimates', () {
    expect(MockFoodRepository.allFoods, hasLength(100));
    expect(
      MockFoodRepository.allFoods.every(
        (food) =>
            food.calories > 0 &&
            food.weightGrams > 0 &&
            food.proteinGrams > 0 &&
            food.fatGrams > 0 &&
            food.carbsGrams > 0,
      ),
      isTrue,
    );
  });

  test('mock foods include store recommendation labels', () {
    final labels = MockFoodRepository.allFoods
        .map((food) => food.specialLabel)
        .whereType<String>()
        .toSet();

    expect(labels, containsAll(['今日特餐', '隱藏版', '人氣回購', '即期惜食']));
  });

  test('toggles favorite foods', () {
    final food = MockFoodRepository.allFoods.first;

    service.toggleFavorite(food);

    expect(service.isFavorite(food.id), isTrue);
    expect(service.favorites, hasLength(1));

    service.toggleFavorite(food);

    expect(service.isFavorite(food.id), isFalse);
    expect(service.favorites, isEmpty);
  });

  test('keeps browsing history newest first without duplicates', () {
    final firstFood = MockFoodRepository.allFoods.first;
    final secondFood = MockFoodRepository.allFoods[1];

    service.addHistory(firstFood);
    service.addHistory(secondFood);
    service.addHistory(firstFood);

    expect(service.history.map((food) => food.id), [
      firstFood.id,
      secondFood.id,
    ]);
  });

  test('restores favorite and history food ids from local storage', () async {
    final firstFood = MockFoodRepository.allFoods.first;
    final secondFood = MockFoodRepository.allFoods[1];

    service.toggleFavorite(firstFood);
    service.addHistory(secondFood);

    await service.initialize();

    expect(service.isFavorite(firstFood.id), isTrue);
    expect(service.history.map((food) => food.id), [secondFood.id]);
  });

  test('keeps recent search logs newest first without duplicates', () {
    service.addSearchLog(keyword: '雞', filterSummary: '高蛋白');
    service.addSearchLog(keyword: '沙拉', filterSummary: '低脂');
    service.addSearchLog(keyword: '雞', filterSummary: '高蛋白');

    expect(service.searchLogs.map((log) => log.keyword), ['雞', '沙拉']);
    expect(service.searchLogs.first.filterSummary, '高蛋白');
  });

  test('restores search logs from local storage', () async {
    service.addSearchLog(keyword: '素食', filterSummary: '均衡 / 150 元內');

    await service.initialize();

    expect(service.searchLogs, hasLength(1));
    expect(service.searchLogs.first.keyword, '素食');
    expect(service.searchLogs.first.filterSummary, '均衡 / 150 元內');
  });

  test('clears search logs', () {
    service.addSearchLog(keyword: '雞', filterSummary: '高蛋白');

    service.clearSearchLogs();

    expect(service.searchLogs, isEmpty);
  });

  test('adds cart items and updates quantities', () {
    final food = MockFoodRepository.allFoods.first;

    service.addToCart(food);
    service.addToCart(food);

    expect(service.isInCart(food.id), isTrue);
    expect(service.cartQuantity(food.id), 2);
    expect(service.cartItems, hasLength(1));
    expect(service.cartTotalQuantity, 2);
    expect(service.cartTotalPrice, food.price * 2);

    service.decreaseCartItem(food);

    expect(service.cartQuantity(food.id), 1);
  });

  test('expired foods cannot be added to the cart', () {
    final expired = MockFoodRepository.allFoods.first.copyWith(
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      isExpiringSoon: true,
    );

    expect(service.addToCart(expired), isFalse);
    expect(service.cartItems, isEmpty);
  });

  test('checkout stores purchase record and clears cart', () {
    final firstFood = MockFoodRepository.allFoods.first;
    final secondFood = MockFoodRepository.allFoods[1];

    service.addToCart(firstFood);
    service.addToCart(secondFood);
    service.addToCart(secondFood);

    final record = service.checkoutCart();

    expect(record, isNotNull);
    expect(service.cartItems, isEmpty);
    expect(service.purchaseRecords, hasLength(1));
    expect(service.purchaseRecords.first.totalQuantity, 3);
    expect(
      service.purchaseRecords.first.totalPrice,
      firstFood.price + secondFood.price * 2,
    );
  });

  test('checkout expiring foods accumulates eco achievements', () {
    final expiringFood = MockFoodRepository.expiringFoods.first;
    final discountAmount =
        (expiringFood.originalPrice ?? expiringFood.price) - expiringFood.price;

    service.addToCart(expiringFood);
    service.addToCart(expiringFood);
    service.checkoutCart();

    expect(service.savedFoodCount, 2);
    expect(service.savedAmount, discountAmount * 2);
    expect(service.ecoPoints, greaterThan(0));
  });

  test('stores food rating feedback by food id', () {
    final food = MockFoodRepository.allFoods.first;

    service.saveFoodFeedback(
      food: food,
      rating: 5,
      tags: const ['份量剛好', '會再回購'],
    );

    final feedback = service.feedbackFor(food.id);
    expect(feedback, isNotNull);
    expect(feedback!.rating, 5);
    expect(feedback.tags, ['份量剛好', '會再回購']);
    expect(service.feedbacks, hasLength(1));
  });
}

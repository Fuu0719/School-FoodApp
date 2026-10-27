import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/food_photo.dart';

void main() {
  setUp(() {
    UserActivityService.instance.clearForTesting();
  });

  testWidgets('renders food detail information', (WidgetTester tester) async {
    final food = MockFoodRepository.allFoods.first;

    await tester.pumpWidget(MaterialApp(home: FoodDetailScreen(food: food)));

    expect(find.text('餐點資訊'), findsOneWidget);
    expect(find.text(food.name), findsOneWidget);
    expect(find.byType(FoodPhoto), findsOneWidget);
    expect(find.text('今日特餐'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('推薦原因'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('推薦原因'), findsOneWidget);
    expect(find.text('減廢分數', skipOffstage: false), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('營養估算'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('營養估算'), findsOneWidget);
    expect(find.text(food.caloriesLabel), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('食材資訊'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('食材資訊'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('店家資訊'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('店家資訊'), findsOneWidget);
  });

  testWidgets('toggles favorite button label in food detail', (
    WidgetTester tester,
  ) async {
    final food = MockFoodRepository.allFoods.first;

    await tester.pumpWidget(MaterialApp(home: FoodDetailScreen(food: food)));
    final favoriteButton = find.text('加入收藏');
    await tester.scrollUntilVisible(
      favoriteButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(favoriteButton);
    await tester.pumpAndSettle();

    expect(find.text('加入收藏'), findsOneWidget);
    expect(find.text('加入購物車'), findsOneWidget);

    await tester.tap(favoriteButton);
    await tester.pump();

    expect(find.text('取消收藏'), findsOneWidget);

    await tester.tap(find.text('取消收藏'));
    await tester.pump();

    expect(find.text('加入收藏'), findsOneWidget);
  });

  testWidgets('adds food to cart and opens cart screen', (
    WidgetTester tester,
  ) async {
    final food = MockFoodRepository.allFoods.first;

    await tester.pumpWidget(MaterialApp(home: FoodDetailScreen(food: food)));
    final addToCartButton = find.text('加入購物車');
    await tester.scrollUntilVisible(
      addToCartButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(addToCartButton);
    await tester.pumpAndSettle();

    await tester.tap(addToCartButton);
    await tester.pump();

    expect(find.text('查看購物車'), findsOneWidget);

    await tester.tap(find.text('查看購物車'));
    await tester.pumpAndSettle();

    expect(find.text('購物車'), findsOneWidget);
    expect(find.text(food.name), findsOneWidget);
  });

  testWidgets('expired food cannot be added to cart', (tester) async {
    final food = MockFoodRepository.allFoods.first.copyWith(
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      isExpiringSoon: true,
    );

    await tester.pumpWidget(MaterialApp(home: FoodDetailScreen(food: food)));
    await tester.scrollUntilVisible(
      find.text('餐點已過期'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '餐點已過期'),
    );
    expect(button.onPressed, isNull);
    expect(UserActivityService.instance.cartItems, isEmpty);
  });

  testWidgets('saves rating feedback in food detail', (
    WidgetTester tester,
  ) async {
    final food = MockFoodRepository.allFoods.first;

    await tester.pumpWidget(MaterialApp(home: FoodDetailScreen(food: food)));
    await tester.scrollUntilVisible(
      find.text('餐後回饋'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('feedback-star-4')));
    await tester.tap(find.byKey(const ValueKey('feedback-star-4')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('feedback-tag-份量剛好')));
    await tester.tap(find.byKey(const ValueKey('feedback-tag-份量剛好')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-food-feedback')),
    );
    await tester.tap(find.byKey(const ValueKey('save-food-feedback')));
    await tester.pump();

    final feedback = UserActivityService.instance.feedbackFor(food.id);
    expect(feedback, isNotNull);
    expect(feedback!.rating, 4);
    expect(feedback.tags, contains('份量剛好'));
    expect(find.textContaining('已儲存'), findsOneWidget);
  });
}

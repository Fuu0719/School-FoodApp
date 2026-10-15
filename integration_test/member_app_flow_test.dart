import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/main.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserActivityService.instance.clearForTesting();
    MerchantAuthService.instance.clearForTesting();
    UserProfileService.instance.clearForTesting();
    UserProfileService.instance.loginWithDemo();
  });

  testWidgets(
    'member navigation, checkout, and health summary work on Android',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('膳解人意'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mood-filter-小確幸')));
      await tester.pumpAndSettle();
      expect(find.text('搜尋餐點'), findsOneWidget);
      expect(find.text('目前沒有符合條件的餐點'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('轉盤決定'));
      await tester.pumpAndSettle();
      expect(find.text('食物轉盤'), findsOneWidget);
      await tester.tap(find.text('首頁'));
      await tester.pumpAndSettle();

      final activity = UserActivityService.instance;
      final food = MockFoodRepository.allFoods.first;
      activity.addToCart(food);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('購物車'), findsOneWidget);
      await tester.tap(find.text('結帳'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('點餐成功'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('今日健康摘要'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('今日健康摘要'), findsOneWidget);
      expect(find.text(food.caloriesLabel), findsOneWidget);
      expect(find.text('尚無今日點餐紀錄，完成結帳後會自動累計熱量與營養素。'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('點餐紀錄'),
        -220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('點餐紀錄'), findsOneWidget);

      await tester.tap(find.text('收藏').last);
      await tester.pumpAndSettle();
      expect(find.text('收藏與紀錄'), findsOneWidget);
    },
  );
}

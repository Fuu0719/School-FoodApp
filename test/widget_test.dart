import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/models/user_profile.dart';
import 'package:my_app/services/member_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/main.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/food_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    UserProfileService.instance.configureForTesting(
      MemberApi(
        baseUrl: 'https://test.example/api',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'token': 'widget-token',
              'user': {...UserProfile.demo.toJson(), 'id': '1'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
      const FlutterSecureStorage(),
    );
    UserActivityService.instance.clearForTesting();
    MerchantAuthService.instance.clearForTesting();
    UserProfileService.instance.clearForTesting();
  });

  testWidgets('renders home screen content', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('膳解人意'), findsOneWidget);
    expect(find.text('今日推薦'), findsOneWidget);
    expect(find.text('即期優惠'), findsWidgets);
    expect(find.text('查看推薦'), findsOneWidget);
    expect(find.text('今天想吃哪種感覺？'), findsOneWidget);
  });

  testWidgets('opens search with mood quick filters from home', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byKey(const ValueKey('mood-filter-清爽')));
    await tester.pumpAndSettle();

    expect(find.text('搜尋餐點'), findsOneWidget);
    expect(find.text('排序'), findsOneWidget);
    expect(find.text('推薦優先'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, '沙拉');
    expect(find.text('低脂'), findsWidgets);
    expect(find.text('180 元內'), findsOneWidget);
  });

  testWidgets('opens food detail from home recommendation card', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.scrollUntilVisible(
      find.byType(FoodCard).first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(FoodCard).first);
    await tester.pumpAndSettle();

    expect(find.text('餐點資訊'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('推薦原因'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('推薦原因'), findsOneWidget);
  });

  testWidgets('opens convenience expiring store and product list', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.scrollUntilVisible(
      find.text('鮪魚御飯糰'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('鮪魚御飯糰'));
    await tester.pumpAndSettle();

    expect(find.text('依距離上限 1000 公尺'), findsOneWidget);
    expect(find.textContaining('模擬位置：桃園銘傳大學'), findsOneWidget);
    expect(find.text('全家'), findsWidgets);
    expect(find.text('7-11'), findsWidgets);

    await tester.tap(find.text('全家').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全家龜山銘美店'));
    await tester.pumpAndSettle();

    expect(find.text('門市即期商品'), findsOneWidget);
    expect(find.text('明太子鮭魚飯糰'), findsOneWidget);
  });

  testWidgets('opens cart from home and checks out', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    final service = UserActivityService.instance;
    service.addToCart(MockFoodRepository.allFoods.first);

    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('購物車'), findsOneWidget);
    expect(find.text('結帳'), findsOneWidget);

    await tester.tap(find.text('結帳'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('點餐成功'), findsOneWidget);
    expect(find.textContaining('共 1 項'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('膳解人意'), findsOneWidget);
    expect(service.cartItems, isEmpty);
    expect(service.purchaseRecords, hasLength(1));
  });

  testWidgets('opens search screen after submitting home search', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).first, '雞胸');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('搜尋餐點'), findsOneWidget);
    expect(find.text('餐點、商家、食材或標籤'), findsOneWidget);
    expect(find.textContaining('舒肥雞胸餐盒'), findsWidgets);
  });

  testWidgets('opens wheel screen from home quick action', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('轉盤決定'));
    await tester.pumpAndSettle();

    expect(find.text('食物轉盤'), findsOneWidget);
    expect(find.text('轉盤條件'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('類型轉盤 6 格'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('類型轉盤 6 格'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('請先設定轉盤條件，系統會列出符合條件的候選餐點。'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('請先設定轉盤條件，系統會列出符合條件的候選餐點。'), findsOneWidget);
  });

  testWidgets('wheel spins a category before showing food result', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('轉盤決定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('便當'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('轉出類型'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('轉出類型'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '轉出類型'));
    await tester.pumpAndSettle();

    expect(find.text('今天吃：便當', skipOffstage: false), findsOneWidget);
    expect(find.text('便當 候選餐點', skipOffstage: false), findsOneWidget);
  });

  testWidgets('shows recommendation score rules', (WidgetTester tester) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('查看推薦'));
    await tester.pumpAndSettle();

    expect(find.text('推薦餐點'), findsOneWidget);
    expect(find.text('偏好 35%'), findsOneWidget);
    expect(find.text('距離 18%'), findsOneWidget);
    expect(find.text('回饋 10%'), findsOneWidget);
    expect(find.textContaining('推薦分數'), findsWidgets);

    await tester.tap(find.text('查看推薦原則'));
    await tester.pumpAndSettle();

    expect(find.text('推薦原則'), findsOneWidget);
    expect(find.textContaining('先排除今日未營業'), findsOneWidget);
  });

  testWidgets('opens collection screen from bottom navigation', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();

    expect(find.text('收藏與紀錄'), findsOneWidget);
    expect(find.text('尚未收藏餐點'), findsOneWidget);
  });

  testWidgets('shows search logs in collection screen', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    UserActivityService.instance.addSearchLog(
      keyword: '雞胸',
      filterSummary: '高蛋白',
    );
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜尋紀錄'));
    await tester.pumpAndSettle();

    expect(find.text('雞胸'), findsOneWidget);
    expect(find.text('高蛋白'), findsOneWidget);
  });

  testWidgets('opens search from search log and clears logs', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    UserActivityService.instance.addSearchLog(
      keyword: '雞胸',
      filterSummary: '高蛋白',
    );
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('收藏').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜尋紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('雞胸'));
    await tester.pumpAndSettle();

    expect(find.text('搜尋餐點'), findsOneWidget);
    expect(find.textContaining('舒肥雞胸餐盒'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(find.text('尚無搜尋紀錄'), findsOneWidget);
  });

  testWidgets('redirects to login before opening protected features', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('查看推薦'));
    await tester.pumpAndSettle();

    expect(find.text('會員登入'), findsOneWidget);
    expect(find.text('測試登入'), findsNothing);
  });

  testWidgets('logs in through member API and returns home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('會員登入'), findsOneWidget);
    expect(find.text('測試登入'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('member-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('member-password')),
      'test-password-123',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('member-submit')));
    await tester.tap(find.byKey(const ValueKey('member-submit')));
    await tester.pumpAndSettle();

    expect(find.text('膳解人意'), findsOneWidget);
    expect(find.text('今日推薦'), findsOneWidget);
    expect(UserProfileService.instance.isLoggedIn, isTrue);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('管理者商品上架'), findsNothing);
  });

  testWidgets('opens collection tabs from profile stats', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏').first);
    await tester.pumpAndSettle();

    expect(find.text('收藏與紀錄'), findsOneWidget);
    expect(find.text('尚未收藏餐點'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('瀏覽紀錄').first);
    await tester.pumpAndSettle();

    expect(find.text('收藏與紀錄'), findsOneWidget);
    expect(find.text('尚無瀏覽紀錄'), findsOneWidget);
  });

  testWidgets('opens purchase records from profile order stat', (
    WidgetTester tester,
  ) async {
    UserProfileService.instance.loginWithDemo();
    final service = UserActivityService.instance;
    final food = MockFoodRepository.expiringFoods.first;
    service.addToCart(food);
    service.checkoutCart();

    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('今日健康摘要'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('今日健康摘要'), findsOneWidget);
    expect(find.text('每日需求 1950 kcal'), findsOneWidget);
    expect(find.text('維持健康 / BMI 22.5'), findsOneWidget);
    expect(find.text(food.caloriesLabel), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('減廢成就'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('減廢成就'), findsOneWidget);
    expect(find.text('惜食點數'), findsOneWidget);
    expect(find.text('即期份數'), findsOneWidget);
    expect(find.text('每日減廢任務'), findsOneWidget);
    expect(find.text('全體惜食排行榜'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('消費管理'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('消費管理'), findsOneWidget);
    expect(find.text('本月消費'), findsOneWidget);
    expect(find.text('常買類型'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('點餐紀錄'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('點餐紀錄'));
    await tester.pumpAndSettle();

    expect(find.text('收藏與紀錄'), findsOneWidget);
    expect(find.text('購買紀錄'), findsWidgets);
  });

  testWidgets('creates admin product listing draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('商家登入'), findsOneWidget);

    await tester.tap(find.text('商家登入'));
    await tester.pumpAndSettle();

    expect(find.text('商家登入'), findsOneWidget);
    expect(find.text('商家後台入口'), findsOneWidget);

    await tester.tap(find.text('進入商家後台'));
    await tester.pumpAndSettle();

    expect(find.text('管理者上架'), findsOneWidget);
    expect(find.text('新增商品'), findsOneWidget);
    expect(find.textContaining('目前商家：銘傳校園示範商家'), findsOneWidget);
    expect(find.text('全家龜山銘美店'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '餐點名稱'), '番茄雞胸盒');
    final submitButton = find.widgetWithText(FilledButton, '建立上架草稿');
    await tester.scrollUntilVisible(
      submitButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('番茄雞胸盒'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('待上架商品'), findsWidgets);
    expect(find.text('番茄雞胸盒'), findsOneWidget);
    expect(find.textContaining('全家龜山銘美店'), findsWidgets);
  });
}

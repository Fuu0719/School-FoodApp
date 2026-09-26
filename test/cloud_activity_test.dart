import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/models/pending_checkout.dart';
import 'package:my_app/services/catalog_api.dart';
import 'package:my_app/services/member_activity_api.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/activity_messages.dart';
import 'package:my_app/screens/cart_screen.dart';

class FixtureCatalog extends CatalogApi {
  @override
  Future<CatalogPage> page({String? after}) async => CatalogPage([
    MockFoodRepository.allFoods.first.copyWith(
      id: '1',
      storeId: '1',
      name: '目前商品',
      price: 100,
      stockCount: 10,
    ),
  ], null);
}

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> receipt([String id = '77']) => {
  'id': id,
  'purchasedAt': '2026-09-10T10:00:00.000Z',
  'totalPrice': 160,
  'totalQuantity': 2,
  'ecoPoints': 26,
  'savedAmount': 80,
  'paymentStatus': 'not_processed',
  'items': [
    {
      'foodId': '1',
      'quantity': 2,
      'unitPrice': 80,
      'originalUnitPrice': 120,
      'foodSnapshot': {
        'name': '下單當時餐點',
        'storeName': '原門市',
        'category': '便當',
        'calories': 400,
        'weightGrams': 300,
        'proteinGrams': 20,
        'fatGrams': 10,
        'carbsGrams': 60,
        'isExpiringSoon': true,
        'imageUrl': '',
      },
    },
  ],
};

MemberApi wire(Future<http.Response?> Function(http.Request) handler) =>
    MemberApi(
      baseUrl: 'https://example.test/api',
      client: MockClient((request) async {
        final custom = await handler(request);
        if (custom != null) return custom;
        if (request.method == 'GET' && request.url.path == '/api/me/history') {
          return response({'items': []});
        }
        if (request.method == 'GET') {
          return response({'items': [], 'nextCursor': null});
        }
        return response({'message': 'ok'});
      }),
    );

Future<FoodCatalogRepository> catalog() async {
  final source = FoodCatalogRepository(useCloud: true, api: FixtureCatalog());
  await source.load();
  return source;
}

Future<UserActivityService> connect(
  FoodCatalogRepository source,
  MemberApi api, {
  String account = 'A',
  String token = 'token-a',
  Future<void> Function()? unauthorized,
}) async {
  final service = UserActivityService(catalog: source);
  await service.switchAccount(
    account,
    cloudApi: MemberActivityApi(
      api: api,
      token: token,
      onUnauthorized: unauthorized,
    ),
  );
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'favorite stays unchanged until success and failed requests never report success',
    () async {
      final source = await catalog();
      final pending = Completer<http.Response>();
      var fail = false;
      final api = wire((request) async {
        expect(request.headers['authorization'], 'Bearer token-a');
        if (request.method == 'PUT') return pending.future;
        if (request.method == 'DELETE' && fail) {
          return response({'message': 'cannot remove'}, 500);
        }
        return null;
      });
      final service = await connect(source, api);
      final adding = service.toggleFavorite(source.allFoods.single);
      expect(service.isFavorite('1'), false);
      expect(service.isSyncing, true);
      pending.complete(response({'message': 'ok'}));
      expect(await adding, true);
      expect(service.isFavorite('1'), true);
      fail = true;
      expect(await service.toggleFavorite(source.allFoods.single), false);
      expect(service.isFavorite('1'), true);
      expect(service.errorMessage, 'cannot remove');
    },
  );

  test(
    'late success and late unauthorized response cannot alter the next account',
    () async {
      for (final status in [200, 401]) {
        final source = await catalog();
        final pending = Completer<http.Response>();
        var invalidatedA = false;
        final service = await connect(
          source,
          wire(
            (request) async => request.method == 'PUT' ? pending.future : null,
          ),
          unauthorized: () async {
            invalidatedA = true;
          },
        );
        final operation = service.toggleFavorite(source.allFoods.single);
        await service.switchAccount(
          'B',
          cloudApi: MemberActivityApi(
            api: wire((_) async => null),
            token: 'token-b',
          ),
        );
        pending.complete(response({'message': 'old session'}, status));
        expect(await operation, false);
        expect(service.favorites, isEmpty);
        expect(service.errorMessage, isNull);
        expect(invalidatedA, false);
      }
    },
  );

  test(
    'history writes wait for an existing sync and clear only after server confirmation',
    () async {
      final source = await catalog();
      final pending = Completer<http.Response>();
      final methods = <String>[];
      final api = wire((request) async {
        if (request.method == 'PUT') return pending.future;
        if (request.url.path.endsWith('/history')) methods.add(request.method);
        return null;
      });
      final service = await connect(source, api);
      final favorite = service.toggleFavorite(source.allFoods.single);
      final view = service.addHistory(source.allFoods.single);
      expect(service.history, isEmpty);
      pending.complete(response({}));
      await favorite;
      await view;
      expect(service.history.single.id, '1');
      expect(methods, contains('POST'));
      await service.clearHistory();
      expect(service.history, isEmpty);
      expect(methods.last, 'DELETE');
    },
  );

  test(
    'ambiguous checkout survives restart, locks editing and reuses one durable key',
    () async {
      final source = await catalog();
      final keys = <String>[];
      var posts = 0;
      final api = wire((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
          keys.add(request.headers['idempotency-key']!);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'items': [
              {'foodId': '1', 'quantity': 2},
            ],
          });
          if (++posts == 1) throw http.ClientException('response lost');
          return response({'order': receipt(), 'replayed': true});
        }
        return null;
      });
      final first = await connect(source, api);
      first.setCartQuantity(source.allFoods.single, 2);
      expect(await first.submitCart(), isNull);
      expect(first.cartTotalQuantity, 2);
      expect(first.hasPendingCheckout, true);
      first.setCartQuantity(source.allFoods.single, 4);
      expect(first.cartTotalQuantity, 2);
      final preferences = await SharedPreferences.getInstance();
      final pendingKey = preferences.getKeys().singleWhere(
        (key) => key.endsWith('pending_checkout'),
      );
      expect(preferences.getString(pendingKey), isNot(contains('token-a')));
      final restarted = await connect(source, api);
      expect(restarted.hasPendingCheckout, true);
      final order = await restarted.submitCart();
      expect(order!.totalPrice, 160);
      expect(order.items.single.food.name, '下單當時餐點');
      expect(restarted.ecoPoints, 26);
      expect(restarted.savedAmount, 80);
      expect(restarted.hasPendingCheckout, false);
      expect(restarted.cartItems, isEmpty);
      expect(keys.length, 2);
      expect(keys.toSet().length, 1);
      expect(preferences.containsKey(pendingKey), false);
    },
  );

  test(
    'double checkout tap sends once and a definite stock rejection unlocks the cart',
    () async {
      final source = await catalog();
      final pending = Completer<http.Response>();
      var posts = 0;
      final service = await connect(
        source,
        wire((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/orders')) {
            posts++;
            return pending.future;
          }
          return null;
        }),
      );
      service.setCartQuantity(source.allFoods.single, 2);
      final first = service.submitCart();
      expect(await service.submitCart(), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(posts, 1);
      pending.complete(response({'message': '庫存不足'}, 409));
      expect(await first, isNull);
      expect(service.hasPendingCheckout, false);
      expect(service.cartLocked, false);
      expect(service.cartTotalQuantity, 2);
      expect(service.purchaseRecords, isEmpty);
    },
  );

  test(
    'receipts and cloud totals do not change with the current food price',
    () async {
      final source = await catalog();
      final service = await connect(
        source,
        wire((request) async {
          if (request.url.path.endsWith('/orders')) {
            return response({
              'items': [
                {'id': '77'},
              ],
              'nextCursor': null,
            });
          }
          if (request.url.path.endsWith('/orders/77')) {
            return response(receipt());
          }
          return null;
        }),
      );
      expect(source.allFoods.single.price, 100);
      expect(service.purchaseRecords.single.totalPrice, 160);
      expect(service.purchaseRecords.single.items.single.food.price, 80);
      expect(service.purchaseRecords.single.items.single.food.calories, 400);
    },
  );

  test(
    '401 clears actual profile and stored session without exposing another account',
    () async {
      final source = await catalog();
      var expired = false;
      final api = wire((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return response({
            'token': 'test-session-token',
            'user': {
              'id': '1',
              'name': '會員',
              'email': 'a@example.test',
              'phone': '',
              'heightCm': 170,
              'weightKg': 65,
              'healthGoal': 'maintain',
              'dietaryTags': [],
              'budgetMax': 150,
              'distanceLimitMeters': 1000,
            },
          });
        }
        if (expired) return response({'message': '登入已失效，請重新登入'}, 401);
        return null;
      });
      final activity = UserActivityService(catalog: source);
      final profile = UserProfileService(api: api, activity: activity);
      await profile.login(
        email: 'a@example.test',
        password: 'test-password-123',
      );
      expect(profile.isLoggedIn, true);
      expired = true;
      expect(await activity.toggleFavorite(source.allFoods.single), false);
      expect(profile.isLoggedIn, false);
      expect(activity.favorites, isEmpty);
      expect(activity.canCheckout, false);
      expect(
        await const FlutterSecureStorage().read(
          key: 'member_session:https://example.test/api',
        ),
        isNull,
      );
    },
  );

  test(
    'pending checkout UUID and validation reject malformed persistent data',
    () {
      final pending = PendingCheckout.create(const [PendingCartLine('1', 2)]);
      expect(
        pending.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(
        PendingCheckout.fromJson(pending.toJson()).items.single.quantity,
        2,
      );
      expect(
        () => PendingCheckout.fromJson({
          'id': pending.id,
          'items': [
            {'foodId': '1', 'quantity': 0},
          ],
        }),
        throwsFormatException,
      );
    },
  );

  test('late order receipt cannot clear the next account cart', () async {
    final source = await catalog();
    final pending = Completer<http.Response>();
    final sent = Completer<void>();
    final service = await connect(
      source,
      wire((request) async {
        if (request.method == 'POST') {
          sent.complete();
          return pending.future;
        }
        return null;
      }),
    );
    service.setCartQuantity(source.allFoods.single, 2);
    final operation = service.submitCart();
    await sent.future;
    await service.switchAccount(
      'B',
      cloudApi: MemberActivityApi(
        api: wire((_) async => null),
        token: 'token-b',
      ),
    );
    service.setCartQuantity(source.allFoods.single, 3);
    pending.complete(response({'order': receipt()}));
    expect(await operation, isNull);
    expect(service.cartTotalQuantity, 3);
    expect(service.purchaseRecords, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('cloud:member:B:cart_items'), ['1:3']);
  });

  test(
    'failed refresh preserves data and order pagination appends once',
    () async {
      var fail = false;
      final source = await catalog();
      final service = await connect(
        source,
        wire((request) async {
          if (fail) return response({'message': 'offline'}, 503);
          if (request.url.path.endsWith('/favorites')) {
            return response({
              'items': [
                {'foodId': '1'},
              ],
              'nextCursor': null,
            });
          }
          if (request.url.path.endsWith('/orders')) {
            final more = request.url.queryParameters['before'] == '77';
            return response({
              'items': [
                {'id': more ? '76' : '77'},
              ],
              'nextCursor': more ? null : '77',
            });
          }
          if (request.url.path.contains('/orders/')) {
            return response(receipt(request.url.pathSegments.last));
          }
          return null;
        }),
      );
      expect(service.hasMoreOrders, true);
      await service.loadMoreOrders();
      expect(service.purchaseRecords.map((order) => order.id), ['77', '76']);
      await service.loadMoreOrders();
      expect(service.purchaseRecords.length, 2);
      fail = true;
      expect(await service.refreshCloud(), false);
      expect(service.isFavorite('1'), true);
      expect(service.purchaseRecords.length, 2);
      expect(service.cloudLoaded, true);
    },
  );

  test(
    'corrupt persisted checkout blocks new orders instead of replacing key',
    () async {
      SharedPreferences.setMockInitialValues({
        'cloud:member:A:pending_checkout': 42,
      });
      var posts = 0;
      final source = await catalog();
      final service = await connect(
        source,
        wire((request) async {
          if (request.method == 'POST') posts++;
          return null;
        }),
      );
      expect(service.canCheckout, false);
      expect(service.cartLocked, true);
      expect(service.checkoutNeedsReview, true);
      expect(service.errorMessage, contains('待確認訂單資料異常'));
      expect(await service.submitCart(), isNull);
      expect(posts, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('cloud:member:A:pending_checkout'), 42);
    },
  );

  testWidgets(
    'pending unavailable product remains retryable on narrow screen',
    (tester) async {
      final pending = PendingCheckout.create(const [PendingCartLine('999', 2)]);
      SharedPreferences.setMockInitialValues({
        'cloud:member:A:pending_checkout': jsonEncode(pending.toJson()),
      });
      final source = await catalog();
      String? sentKey;
      final service = await connect(
        source,
        wire((request) async {
          if (request.method == 'POST') {
            sentKey = request.headers['idempotency-key'];
            return response({'order': receipt()});
          }
          return null;
        }),
      );
      expect(service.cartItems, isEmpty);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CartScreen(
            activity: service,
            onCheckoutComplete: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 項'), findsOneWidget);
      expect(find.text('確認上次訂單'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('確認上次訂單'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(sentKey, pending.id);
      expect(find.text('點餐成功'), findsOneWidget);
      expect(completed, false);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background activity failure is visible through the shared messenger',
    (tester) async {
      final source = await catalog();
      final service = await connect(
        source,
        wire(
          (request) async => request.method == 'PUT'
              ? response({'message': '收藏失敗，請重試'}, 500)
              : null,
        ),
      );
      final key = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: key,
          builder: (_, child) => ActivityMessages(
            messengerKey: key,
            service: service,
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await service.toggleFavorite(source.allFoods.single);
      await tester.pumpAndSettle();
      expect(find.text('收藏失敗，請重試'), findsOneWidget);
      expect(service.isFavorite('1'), false);
    },
  );
}

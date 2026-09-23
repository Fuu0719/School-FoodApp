import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/merchant_product.dart';
import 'package:my_app/models/merchant_registration.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/screens/merchant_products_screen.dart';
import 'package:my_app/screens/merchant_product_editor.dart';
import 'package:my_app/screens/merchant_register_screen.dart';
import 'package:my_app/validation/phone.dart';

const merchant = {
  'id': '1',
  'businessName': '測試商家',
  'email': 'owner@example.test',
  'contactPhone': '',
  'stores': [
    {
      'id': '10',
      'name': '測試門市',
      'address': '測試地址',
      'businessHours': '09:00-20:00',
    },
  ],
};
Map<String, Object?> productJson({String status = 'draft', int revision = 0}) =>
    {
      'id': '7',
      'storeId': '10',
      'storeName': '測試門市',
      'name': '高蛋白便當',
      'category': '便當',
      'price': 80,
      'originalPrice': 100,
      'stockCount': 3,
      'imageUrl': '',
      'calories': 400,
      'weightGrams': 300,
      'proteinGrams': 20,
      'fatGrams': 10,
      'carbsGrams': 60,
      'expiresAt': '2027-01-01T12:00:00.000Z',
      'isExpiringSoon': true,
      'tags': ['高蛋白'],
      'ingredients': ['米'],
      'status': status,
      'revision': revision,
    };
http.Response response(Object data, [int code = 200]) => http.Response(
  jsonEncode(data),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
MemberApi api([
  Future<http.Response?> Function(http.Request)? handler,
]) => MemberApi(
  baseUrl: 'https://example.test/api',
  client: MockClient((request) async {
    final custom = await handler?.call(request);
    if (custom != null) return custom;
    if (request.url.path.endsWith('/auth/login')) {
      return response({'merchant': merchant, 'token': 'a' * 64});
    }
    if (request.url.path.endsWith('/merchant/me')) return response(merchant);
    if (request.url.path.endsWith('/merchant/categories')) {
      return response({
        'items': ['便當'],
      });
    }
    if (request.url.path.endsWith('/products') && request.method == 'GET') {
      return response({
        'items': [productJson()],
        'nextCursor': null,
      });
    }
    if (request.url.path.endsWith('/products') && request.method == 'POST') {
      return response({'product': productJson(), 'replayed': false}, 201);
    }
    if (request.url.path.contains('/products/')) return response(productJson());
    return response({'message': 'ok'});
  }),
);
Future<MerchantAuthService> connect(MemberApi wire) async {
  final service = MerchantAuthService(api: wire, useCloud: true);
  await service.login('owner@example.test', 'Merchant-test-password!');
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  const signup = MerchantRegistration(
    email: 'owner@example.test',
    password: 'Merchant-test-password!',
    businessName: 'Test merchant',
    contactPhone: '',
  );
  testWidgets('optional store phone rejects malformed input before sending', (
    tester,
  ) async {
    var sent = 0;
    final service = await connect(
      api((request) async {
        if (request.url.path.endsWith('/stores') && request.method == 'POST') {
          sent++;
          return response(merchant, 201);
        }
        return null;
      }),
    );
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantRegisterScreen(service: service, createStore: true),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Branch');
    await tester.enterText(find.byType(TextFormField).at(1), 'Address');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.tap(find.text('建立門市'));
    await tester.pumpAndSettle();
    expect(find.text(phoneFormatMessage), findsOneWidget);
    expect(sent, 0);
    await tester.enterText(find.byType(TextFormField).at(2), '');
    await tester.tap(find.text('週一'));
    await tester.tap(find.text('建立門市'));
    await tester.pumpAndSettle();
    expect(sent, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets(
    'custom categories load, validate, deduplicate and persist with edited product',
    (tester) async {
      String? savedCategory;
      final service = await connect(
        api((request) async {
          if (request.url.path.endsWith('/categories')) {
            return response({
              'items': ['歷史商品分類'],
            });
          }
          if (request.method == 'PUT') {
            savedCategory =
                (jsonDecode(request.body) as Map)['category'] as String;
            return response({...productJson(), 'category': savedCategory});
          }
          return null;
        }),
      );
      await service.refresh();
      expect(service.categories, contains('歷史商品分類'));
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantProductEditor(
            service: service,
            product: MerchantProduct.fromJson(productJson()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(find.text('請輸入分類名稱'), findsOneWidget);
      final categoryInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(categoryInput, '  自訂甜點  ');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      expect(find.text('自訂甜點'), findsWidgets);
      await tester.tap(find.byTooltip('新增分類'));
      await tester.pumpAndSettle();
      await tester.enterText(categoryInput, '自訂甜點');
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('category:自訂甜點')),
      );
      expect(dropdown.initialValue, '自訂甜點');
      await tester.scrollUntilVisible(
        find.text('儲存草稿'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('儲存草稿'));
      await tester.pumpAndSettle();
      expect(savedCategory, '自訂甜點');
      expect(service.categories.where((v) => v == '自訂甜點'), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  testWidgets(
    'store deletion confirms, keeps data on failure and removes on success',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      var fail = true;
      final service = await connect(
        api((request) async {
          if (request.method == 'DELETE') {
            calls++;
            expect(request.url.path, '/api/merchant/stores/10');
            expect(request.headers['Authorization'], 'Bearer ${'a' * 64}');
            return fail
                ? response({'message': '刪除未完成，請重試'}, 503)
                : response({...merchant, 'stores': []});
          }
          return null;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: MerchantProductsScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('門市管理（1）'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('刪除 測試門市'));
      await tester.pumpAndSettle();
      expect(find.textContaining('既有訂單紀錄會保留'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.byTooltip('刪除 測試門市'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除門市'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(service.account!.stores, hasLength(1));
      expect(service.products, hasLength(1));
      expect(find.text('刪除未完成，請重試'), findsWidgets);
      fail = false;
      await tester.tap(find.byTooltip('刪除 測試門市'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除門市'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(service.account!.stores, isEmpty);
      expect(service.products, isEmpty);
      expect(find.byTooltip('刪除 測試門市'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  test(
    'deleting a store discards its pending draft but preserves other stores',
    () async {
      var removed = false;
      final otherStore = {
        ...(merchant['stores'] as List).first as Map,
        'id': '11',
      };
      final service = await connect(
        api((request) async {
          if (request.url.path.endsWith('/products') &&
              request.method == 'POST') {
            return response({'message': 'timeout'}, 503);
          }
          if (request.method == 'DELETE') {
            removed = true;
            return response({
              ...merchant,
              'stores': [otherStore],
            });
          }
          if (request.url.path.endsWith('/merchant/me')) {
            return response({
              ...merchant,
              'stores': [
                if (!removed) ...(merchant['stores'] as List),
                otherStore,
              ],
            });
          }
          if (request.url.path.endsWith('/products') &&
              request.method == 'GET') {
            return response({
              'items': [
                productJson(),
                {...productJson(), 'id': '8', 'storeId': '11'},
              ],
              'nextCursor': null,
            });
          }
          return null;
        }),
      );
      await service.refresh();
      await expectLater(
        service.save(MerchantProductInput.fromJson(productJson())),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.hasPendingDraft, isTrue);
      await service.deleteStore('10');
      expect(service.hasPendingDraft, isFalse);
      expect(service.products.map((p) => p.id), ['8']);
      expect(service.account!.stores.single.id, '11');
      expect(
        (await SharedPreferences.getInstance()).getKeys().where(
          (k) => k.startsWith('merchant_pending:'),
        ),
        isEmpty,
      );
      service.dispose();
    },
  );
  testWidgets('store uses 24-hour wheels and authenticated structured fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? sent;
    final service = await connect(
      api((request) async {
        if (request.url.path.endsWith('/stores')) {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['Authorization'], 'Bearer ${'a' * 64}');
          return response({'message': 'store duplicate'}, 409);
        }
        return null;
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantRegisterScreen(service: service, createStore: true),
      ),
    );
    expect(find.text('商家 Email'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Branch');
    await tester.enterText(find.byType(TextFormField).at(1), 'Address');
    await tester.tap(find.text('開始營業'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.use24hFormat, isTrue);
    picker.onDateTimeChanged(DateTime(2026, 1, 1, 8, 30));
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('08:30'), findsOneWidget);
    await tester.tap(find.text('週一'));
    await tester.tap(find.text('建立門市'));
    await tester.pumpAndSettle();
    expect(sent!['opensAt'], '08:30');
    expect(sent!['closesAt'], '18:00');
    expect(sent!['merchantId'], isNull);
    expect(find.text('store duplicate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  testWidgets(
    'registration form validates and retains fields after rejection at narrow width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      final service = MerchantAuthService(
        useCloud: true,
        api: api((request) async {
          calls++;
          return response({'message': 'Email already registered'}, 409);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: MerchantRegisterScreen(service: service)),
      );
      await tester.tap(find.text('建立商家帳號'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      final inputs = find.byType(TextFormField);
      final values = [
        'Test merchant',
        'owner@example.test',
        'Merchant123!',
        'Merchant123!',
        '',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(inputs.at(i), values[i]);
      }
      await tester.tap(find.text('建立商家帳號'));
      await tester.pumpAndSettle();
      expect(find.text('門市名稱'), findsNothing);
      expect(calls, 1);
      expect(find.text('Email already registered'), findsOneWidget);
      expect(find.text('owner@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
  test(
    'registration sends merchant fields without creating a session',
    () async {
      var calls = 0;
      final service = MerchantAuthService(
        useCloud: true,
        api: api((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/merchant/auth/register');
          expect(jsonDecode(request.body), signup.toJson());
          expect(request.headers['authorization'], isNull);
          return response({'message': 'registered'}, 201);
        }),
      );
      await service.register(signup);
      expect(calls, 1);
      expect(service.isLoggedIn, isFalse);
      expect(service.isBusy, isFalse);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      service.dispose();
    },
  );
  test(
    'duplicate registration remains logged out and exposes server error',
    () async {
      final service = MerchantAuthService(
        useCloud: true,
        api: api((request) async {
          return response({'message': 'Email already registered'}, 409);
        }),
      );
      await expectLater(
        service.register(signup),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.errorMessage, 'Email already registered');
      expect(service.isLoggedIn, isFalse);
      expect(service.isBusy, isFalse);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      service.dispose();
    },
  );

  test(
    'cloud login cannot use demo and merchant session is stored separately',
    () async {
      final service = await connect(api());
      expect(() => service.loginWithDemo(), throwsA(isA<MemberApiException>()));
      expect(service.account!.stores.single.id, '10');
      final storage = const FlutterSecureStorage();
      expect(
        await storage.read(key: 'merchant_session:https://example.test/api'),
        'a' * 64,
      );
      expect(
        await storage.read(key: 'member_session:https://example.test/api'),
        isNull,
      );
      final restored = MerchantAuthService(api: api(), useCloud: true);
      await restored.initialize();
      expect(restored.account!.id, '1');
      await service.logout();
      expect(service.isLoggedIn, false);
      expect(
        await storage.read(key: 'merchant_session:https://example.test/api'),
        isNull,
      );
    },
  );

  test(
    'invalid login and expired session never create a fake merchant',
    () async {
      var fail = true;
      final service = MerchantAuthService(
        useCloud: true,
        api: api(
          (request) async =>
              fail ? response({'message': '商家登入已失效'}, 401) : null,
        ),
      );
      await expectLater(
        service.login('owner@example.test', 'wrong-password'),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.isLoggedIn, false);
      fail = false;
      await service.login('owner@example.test', 'Merchant-test-password!');
      await service.refresh();
      expect(service.products.length, 1);
      fail = true;
      await expectLater(service.refresh(), throwsA(isA<MemberApiException>()));
      expect(service.products, isEmpty);
      expect(service.isLoggedIn, false);
    },
  );

  test(
    'lost create response persists payload and reuses key after restart',
    () async {
      final keys = <String>[];
      final bodies = <String>[];
      final wire = api((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/products')) {
          keys.add(request.headers['idempotency-key']!);
          bodies.add(request.body);
          if (keys.length == 1) throw http.ClientException('response lost');
        }
        return null;
      });
      final service = await connect(wire);
      final input = MerchantProductInput.fromJson(productJson());
      await expectLater(
        service.save(input),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.hasPendingDraft, true);
      final restarted = MerchantAuthService(api: wire, useCloud: true);
      await restarted.initialize();
      expect(restarted.pendingInput!.name, input.name);
      final saved = await restarted.save(
        MerchantProductInput.fromJson({
          ...productJson(),
          'name': 'changed input',
        }),
      );
      expect(saved.id, '7');
      expect(keys.length, 2);
      expect(keys[0], keys[1]);
      expect(bodies[0], bodies[1]);
      expect(restarted.hasPendingDraft, false);
      expect(
        (await SharedPreferences.getInstance()).getKeys().where(
          (key) => key.startsWith('merchant_pending'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'duplicate tap is blocked and definite validation rejection allows editing',
    () async {
      final pending = Completer<http.Response>();
      var writes = 0;
      final service = await connect(
        api((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/products')) {
            writes++;
            return pending.future;
          }
          return null;
        }),
      );
      final input = MerchantProductInput.fromJson(productJson());
      final first = service.save(input);
      await expectLater(
        service.save(input),
        throwsA(isA<MemberApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      pending.complete(response({'message': '圖片網址格式不正確'}, 400));
      await expectLater(first, throwsA(isA<MemberApiException>()));
      expect(service.hasPendingDraft, false);
      expect(service.products, isEmpty);
    },
  );

  test(
    'publication failure retains draft and sends observed revision only',
    () async {
      final service = await connect(
        api((request) async {
          if (request.url.path.endsWith('/status')) {
            expect(jsonDecode(request.body), {
              'status': 'active',
              'revision': 0,
            });
            expect(request.headers['authorization'], 'Bearer ${'a' * 64}');
            return response({'message': '商品已更新，請重新載入'}, 409);
          }
          return null;
        }),
      );
      await service.refresh();
      await expectLater(
        service.setStatus(service.products.single, 'active'),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.products.single.status, 'draft');
    },
  );

  test(
    'corrupt pending draft blocks creation without replacing evidence',
    () async {
      SharedPreferences.setMockInitialValues({
        'merchant_pending:https://example.test/api:1': '{broken',
      });
      final service = await connect(api());
      expect(service.pendingCorrupt, true);
      await expectLater(
        service.save(MerchantProductInput.fromJson(productJson())),
        throwsA(isA<MemberApiException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'merchant_pending:https://example.test/api:1',
        ),
        '{broken',
      );
    },
  );

  testWidgets('merchant list and status confirmation fit a narrow screen', (
    tester,
  ) async {
    final service = await connect(
      api(
        (request) async => request.url.path.endsWith('/status')
            ? response(productJson(status: 'active', revision: 1))
            : null,
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: MerchantProductsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('高蛋白便當'), findsOneWidget);
    expect(find.text('草稿'), findsOneWidget);
    await tester.tap(find.byTooltip('商品操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上架'));
    await tester.pumpAndSettle();
    expect(find.text('上架此商品？'), findsOneWidget);
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(find.text('已上架'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editor preserves invalid input and server errors without success notification',
    (tester) async {
      final service = await connect(
        api(
          (request) async =>
              request.method == 'POST' && request.url.path.endsWith('/products')
              ? response({'message': '請檢查商品資料'}, 400)
              : null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: MerchantProductEditor(service: service)),
      );
      final save = find.text('儲存草稿');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('此欄位不可空白'), findsOneWidget);
      final name = find.widgetWithText(TextFormField, '餐點名稱');
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      await tester.enterText(name, '新商品');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('請檢查商品資料'), findsOneWidget);
      expect(find.text('草稿已儲存，尚未上架'), findsNothing);
      expect(tester.widget<TextFormField>(name).controller!.text, '新商品');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cloud login has no default credentials and renders authentication errors',
    (tester) async {
      final service = MerchantAuthService(
        useCloud: true,
        api: api((request) async => response({'message': '帳號尚未啟用'}, 401)),
      );
      await tester.pumpWidget(
        MaterialApp(home: CloudMerchantLoginScreen(service: service)),
      );
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.every((field) => field.controller!.text.isEmpty), true);
      await tester.enterText(
        find.widgetWithText(TextFormField, '商家 Email'),
        'owner@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '密碼'),
        'Merchant-test-password!',
      );
      await tester.tap(find.text('登入商家後台'));
      await tester.pumpAndSettle();
      expect(find.text('帳號尚未啟用'), findsOneWidget);
      expect(find.text('商家商品'), findsNothing);
    },
  );
}

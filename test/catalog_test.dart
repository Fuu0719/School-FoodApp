import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/convenience_store.dart';
import 'package:my_app/services/catalog_api.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/widgets/catalog_gate.dart';

Map<String, Object?> foodJson(String id) => {
  'id': id,
  'name': '測試餐點',
  'storeId': '42',
  'storeName': '測試門市',
  'storeBrand': '全家',
  'storeAddress': '測試地址',
  'businessHours': '00:00-24:00',
  'businessWeekdays': [1, 2, 3, 4, 5, 6, 7],
  'contactPhone': '',
  'price': 100,
  'originalPrice': 120,
  'discountLabel': null,
  'category': '便當',
  'tags': ['均衡', '高蛋白'],
  'ingredients': ['米飯'],
  'nutritionTags': [],
  'calories': 400,
  'weightGrams': 300,
  'proteinGrams': 20,
  'fatGrams': 10,
  'carbsGrams': 60,
  'distanceMeters': 500,
  'stockCount': 10,
  'expiresAt': '2099-01-01T00:00:00.000Z',
  'isExpiringSoon': true,
  'ecoPriorityScore': 0.5,
  'recommendationReason': '',
  'imageUrl': '',
  'specialLabel': null,
};

http.Response page(List<Map<String, Object?>> items, [String? cursor]) =>
    http.Response(
      jsonEncode({'items': items, 'nextCursor': cursor}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
FoodCatalogRepository repository(
  Future<http.Response> Function(http.Request) handler,
) => FoodCatalogRepository(
  useCloud: true,
  api: CatalogApi(
    api: MemberApi(
      client: MockClient(handler),
      baseUrl: 'https://example.test/api',
    ),
  ),
);

void main() {
  test(
    'cloud catalogue maps nutritional fields, string IDs and convenience brands',
    () async {
      final source = repository(
        (_) async => page([foodJson('9007199254740993')]),
      );
      await source.load();
      final food = source.allFoods.single;
      expect(food.id, '9007199254740993');
      expect(food.price, 100);
      expect(food.proteinGrams, 20);
      expect(food.tags, ['均衡', '高蛋白']);
      expect(food.storeId, '42');
      expect(
        source
            .expiringFoodsByBrand(
              ConvenienceBrand.familyMart,
              maxDistanceMeters: 1000,
            )
            .length,
        1,
      );
      expect(
        source.expiringFoodsByBrand(ConvenienceBrand.sevenEleven),
        isEmpty,
      );
      expect(
        source.expiringFoodsByBrand(null, maxDistanceMeters: 100),
        isEmpty,
      );
      final sevenSource = repository(
        (_) async => page([
          {...foodJson('2'), 'storeBrand': '7-ELEVEN'},
        ]),
      );
      await sevenSource.load();
      expect(
        sevenSource.expiringFoodsByBrand(ConvenienceBrand.sevenEleven),
        hasLength(1),
      );
    },
  );

  test(
    'catalogue resolves backend-owned image paths against the API host',
    () async {
      final item = foodJson('1')..['imageUrl'] = '/food-images/bento.jpg';
      final source = repository((_) async => page([item]));
      await source.load();
      expect(
        source.allFoods.single.imageUrl,
        'https://example.test/food-images/bento.jpg',
      );
    },
  );
  test(
    'unknown distance is not shown as zero or a nearby convenience store',
    () async {
      final source = repository(
        (_) async => page([
          {...foodJson('1'), 'distanceMeters': null},
        ]),
      );
      await source.load();
      expect(source.allFoods.single.distanceLabel, '距離未提供');
      expect(source.allFoods.single.hasDistance, false);
      expect(source.convenienceStores, isEmpty);
    },
  );
  test('pagination loads the complete set atomically', () async {
    final source = repository(
      (request) async => request.url.queryParameters['after'] == null
          ? page([foodJson('1')], '1')
          : page([foodJson('2')]),
    );
    expect(source.allFoods, isEmpty);
    await source.load();
    expect(source.allFoods.map((food) => food.id), ['1', '2']);
  });
  test(
    'second-page failure never exposes the partial set or mock foods',
    () async {
      final source = repository(
        (request) async => request.url.queryParameters['after'] == null
            ? page([foodJson('1')], '1')
            : http.Response('{"message":"offline"}', 503),
      );
      await expectLater(source.load(), throwsA(isA<MemberApiException>()));
      expect(source.allFoods, isEmpty);
    },
  );
  test('duplicate pages are rejected', () async {
    final source = repository((_) async => page([foodJson('1')], '1'));
    await expectLater(source.load(), throwsA(isA<MemberApiException>()));
    expect(source.allFoods, isEmpty);
  });
  test(
    'empty cloud catalogue remains empty and demo mode still has 100 products',
    () async {
      final source = repository((_) async => page([]));
      await source.load();
      expect(source.allFoods, isEmpty);
      expect(FoodCatalogRepository(useCloud: false).allFoods.length, 100);
    },
  );
  test(
    'malformed product response is rejected instead of silently dropping products',
    () async {
      for (final invalid in [
        {...foodJson('1'), 'id': 'food-001'},
        {...foodJson('1'), 'price': -1},
        {
          ...foodJson('1'),
          'businessWeekdays': [8],
        },
        {
          ...foodJson('1'),
          'tags': [12],
        },
      ]) {
        await expectLater(
          repository((_) async => page([invalid])).load(),
          throwsA(isA<MemberApiException>()),
        );
      }
    },
  );
  testWidgets(
    'catalogue gate waits for data and then restores activity before showing home',
    (tester) async {
      final pending = Completer<http.Response>();
      var restored = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogGate(
            repository: repository((_) => pending.future),
            onLoaded: () async {
              restored = true;
            },
            child: const Scaffold(body: Text('home')),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('home'), findsNothing);
      pending.complete(page([]));
      await tester.pumpAndSettle();
      expect(restored, true);
      expect(find.text('home'), findsOneWidget);
    },
  );
  testWidgets(
    'catalogue failure and retry fit a small phone without mock fallback',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var attempts = 0;
      final source = repository(
        (_) async => ++attempts == 1
            ? http.Response('{"message":"offline"}', 503)
            : page([]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CatalogGate(
            repository: source,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('offline'), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(source.allFoods, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('重新載入商品'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

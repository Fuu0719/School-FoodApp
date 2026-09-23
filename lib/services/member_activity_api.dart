import 'package:flutter/material.dart';
import 'package:my_app/models/cart_item.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/models/purchase_record.dart';
import 'package:my_app/services/member_api.dart';

class OrderPage {
  const OrderPage(this.records, this.nextCursor);
  final List<PurchaseRecord> records;
  final String? nextCursor;
}

class EcoRanking {
  const EcoRanking({
    required this.name,
    required this.points,
    required this.rank,
    required this.isMe,
  });
  final String name;
  final int points;
  final int rank;
  final bool isMe;
}

class MemberActivityApi {
  MemberActivityApi({
    required this.api,
    required this.token,
    this.onUnauthorized,
  });
  final MemberApi api;
  final String token;
  final Future<void> Function()? onUnauthorized;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? key,
  }) =>
      api.request(method, path, body: body, token: token, idempotencyKey: key);

  Future<List<String>> favorites() async {
    final ids = <String>[];
    final cursors = <String>{};
    String? before;
    do {
      final data = await _request(
        'GET',
        before == null ? '/me/favorites' : '/me/favorites?before=$before',
      );
      ids.addAll(_items(data).map((item) => _id(item['foodId'])));
      before = _cursor(data);
      if (ids.length > 1000 ||
          (before != null && (!cursors.add(before) || cursors.length > 20))) {
        throw const MemberApiException('收藏數量或分頁回應超過處理範圍');
      }
    } while (before != null);
    return ids;
  }

  Future<List<String>> history() async => _items(
    await _request('GET', '/me/history'),
  ).map((item) => _id(item['foodId'])).toList();

  Future<void> favorite(String foodId, bool enabled) async {
    await _request(enabled ? 'PUT' : 'DELETE', '/me/favorites/${_id(foodId)}');
  }

  Future<void> view(String foodId) async {
    await _request('POST', '/me/history', body: {'foodId': _id(foodId)});
  }

  Future<void> clearHistory() async {
    await _request('DELETE', '/me/history');
  }

  Future<List<EcoRanking>> leaderboard() async {
    final items = _items(await _request('GET', '/me/leaderboard'));
    return items.map((item) {
      final name = item['name'];
      final points = item['points'];
      final rank = item['rank'];
      final isMe = item['isMe'];
      if (name is! String || points is! int || rank is! int || isMe is! bool) {
        throw const MemberApiException('排行榜資料格式不正確');
      }
      return EcoRanking(name: name, points: points, rank: rank, isMe: isMe);
    }).toList();
  }

  Future<OrderPage> orders({String? before}) async {
    final data = await _request(
      'GET',
      before == null ? '/me/orders' : '/me/orders?before=${_id(before)}',
    );
    final items = _items(data);
    if (items.length > 20) throw const MemberApiException('訂單分頁回應異常');
    final records = <PurchaseRecord>[];
    // Bound parallel requests when expanding a page into immutable order receipts.
    for (var offset = 0; offset < items.length; offset += 5) {
      records.addAll(
        await Future.wait(
          items
              .skip(offset)
              .take(5)
              .map(
                (item) async => decodeOrder(
                  await _request('GET', '/me/orders/${_id(item['id'])}'),
                ),
              ),
        ),
      );
    }
    return OrderPage(records, _cursor(data));
  }

  Future<PurchaseRecord> checkout(
    String key,
    List<Map<String, Object?>> items,
  ) async {
    final data = await _request(
      'POST',
      '/me/orders',
      key: key,
      body: {'items': items},
    );
    final order = data['order'];
    if (order is! Map<String, dynamic>) {
      throw const MemberApiException('訂單回應格式不正確，請用原訂單重試確認');
    }
    return decodeOrder(order);
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final list = data['items'];
    if (list is! List || list.any((item) => item is! Map<String, dynamic>)) {
      throw const MemberApiException('會員紀錄回應格式不正確');
    }
    return list.cast<Map<String, dynamic>>();
  }

  static String _id(Object? value) {
    if (value is! String || !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value)) {
      throw const MemberApiException('會員紀錄 ID 格式不正確');
    }
    return value;
  }

  static String? _cursor(Map<String, dynamic> data) {
    if (!data.containsKey('nextCursor')) {
      throw const MemberApiException('會員紀錄分頁格式不正確');
    }
    return data['nextCursor'] == null ? null : _id(data['nextCursor']);
  }

  static PurchaseRecord decodeOrder(Map<String, dynamic> json) {
    try {
      int number(Object? value) {
        if (value is! int || value < 0) throw const FormatException();
        return value;
      }

      final items = _items(json).map((item) {
        final snapshot = item['foodSnapshot'] as Map<String, dynamic>?;
        final quantity = number(item['quantity']);
        if (quantity == 0) throw const FormatException();
        final foodId = _id(item['foodId']);
        final food = FoodItem(
          id: foodId,
          name: snapshot?['name'] as String? ?? '餐點 #$foodId（無舊版快照）',
          storeId: '',
          storeName: snapshot?['storeName'] as String? ?? '',
          storeAddress: '',
          businessHours: '',
          businessWeekdays: const [],
          contactPhone: '',
          price: number(item['unitPrice']),
          originalPrice: item['originalUnitPrice'] == null
              ? null
              : number(item['originalUnitPrice']),
          category: snapshot?['category'] as String? ?? '',
          tags: const [],
          ingredients: const [],
          nutritionTags: const [],
          calories: number(snapshot?['calories'] ?? 0),
          weightGrams: number(snapshot?['weightGrams'] ?? 0),
          proteinGrams: number(snapshot?['proteinGrams'] ?? 0),
          fatGrams: number(snapshot?['fatGrams'] ?? 0),
          carbsGrams: number(snapshot?['carbsGrams'] ?? 0),
          distanceMeters: 1000001,
          hasDistance: false,
          stockCount: 0,
          ecoPriorityScore: 0,
          recommendationReason: '',
          imageUrl: snapshot?['imageUrl'] as String? ?? '',
          icon: Icons.receipt_long,
          isExpiringSoon: snapshot?['isExpiringSoon'] as bool? ?? false,
        );
        return CartItem(food: food, quantity: quantity);
      }).toList();
      final record = PurchaseRecord(
        id: _id(json['id']),
        purchasedAt: DateTime.parse(json['purchasedAt'] as String).toLocal(),
        items: List.unmodifiable(items),
        cloudEcoPoints: number(json['ecoPoints']),
        cloudSavedAmount: number(json['savedAmount']),
      );
      if (record.totalPrice != number(json['totalPrice']) ||
          record.totalQuantity != number(json['totalQuantity'])) {
        throw const FormatException();
      }
      return record;
    } on FormatException {
      throw const MemberApiException('訂單回應格式不正確，請重新確認');
    } on TypeError {
      throw const MemberApiException('訂單回應格式不正確，請重新確認');
    }
  }
}

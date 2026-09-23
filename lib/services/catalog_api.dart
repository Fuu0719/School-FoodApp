import 'package:flutter/material.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/services/member_api.dart';

class CatalogPage {
  const CatalogPage(this.items, this.nextCursor);
  final List<FoodItem> items;
  final String? nextCursor;
}

class CatalogApi {
  CatalogApi({MemberApi? api}) : _api = api ?? MemberApi();
  final MemberApi _api;

  Future<CatalogPage> page({String? after}) async {
    final path = Uri(
      path: '/foods',
      queryParameters: after == null ? null : {'after': after},
    );
    final json = await _api.request('GET', path.toString());
    try {
      final items = json['items'];
      final cursor = json['nextCursor'];
      if (items is! List || !json.containsKey('nextCursor')) {
        throw const FormatException();
      }
      if (cursor != null) _id(cursor);
      return CatalogPage(
        List.unmodifiable(
          items.map((item) => decodeFood(item as Map<String, dynamic>)),
        ),
        cursor as String?,
      );
    } on FormatException {
      throw const MemberApiException('商品資料格式不正確，請稍後再試');
    } on TypeError {
      throw const MemberApiException('商品資料格式不正確，請稍後再試');
    }
  }

  static String _id(Object? value) {
    if (value is! String || !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value)) {
      throw const FormatException();
    }
    return value;
  }

  static FoodItem decodeFood(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String) throw const FormatException();
      return value;
    }

    int number(String key) {
      final value = json[key];
      if (value is! int || value < 0) throw const FormatException();
      return value;
    }

    List<String> strings(String key) =>
        List<String>.unmodifiable(json[key] as List);
    final weekdays = List<int>.unmodifiable(json['businessWeekdays'] as List);
    if (weekdays.any((day) => day < 1 || day > 7)) {
      throw const FormatException();
    }
    final eco = (json['ecoPriorityScore'] as num).toDouble();
    if (!eco.isFinite || eco < 0) throw const FormatException();
    return FoodItem(
      id: _id(json['id']),
      name: text('name'),
      storeId: _id(json['storeId']),
      storeName: text('storeName'),
      merchantName: json['merchantName'] as String? ?? text('storeName'),
      storeBrand: json['storeBrand'] as String?,
      storeAddress: text('storeAddress'),
      businessHours: text('businessHours'),
      businessWeekdays: weekdays,
      contactPhone: text('contactPhone'),
      price: number('price'),
      originalPrice: json['originalPrice'] == null
          ? null
          : number('originalPrice'),
      discountLabel: json['discountLabel'] as String?,
      category: text('category'),
      tags: strings('tags'),
      ingredients: strings('ingredients'),
      nutritionTags: strings('nutritionTags'),
      calories: number('calories'),
      weightGrams: number('weightGrams'),
      proteinGrams: number('proteinGrams'),
      fatGrams: number('fatGrams'),
      carbsGrams: number('carbsGrams'),
      // Unknown distance must never be interpreted as a nearby zero-metre store.
      distanceMeters: json['distanceMeters'] == null
          ? 1000001
          : number('distanceMeters'),
      hasDistance: json['distanceMeters'] != null,
      stockCount: number('stockCount'),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(text('expiresAt')),
      isExpiringSoon: json['isExpiringSoon'] as bool,
      ecoPriorityScore: eco,
      recommendationReason: text('recommendationReason'),
      imageUrl: text('imageUrl'),
      specialLabel: json['specialLabel'] as String?,
      icon: Icons.restaurant,
    );
  }
}
